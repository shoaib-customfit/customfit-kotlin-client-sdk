import Foundation

/// Enhanced event tracking implementation matching Kotlin SDK functionality
public class EventTracker {
    
    // MARK: - Constants
    
    private static let SOURCE = "EventTracker"
    
    // MARK: - Properties
    
    private let sessionId: String
    private let httpClient: HttpClient
    private let user: UserManager
    private let summaryManager: SummaryManager
    private let config: CFConfig
    
    // Thread-safe atomic properties
    private let eventsFlushTimeSecondsLock = NSLock()
    private var _eventsFlushTimeSeconds: Int
    
    private let eventsFlushIntervalMsLock = NSLock()
    private var _eventsFlushIntervalMs: Int64
    
    // Queue and storage
    private let eventQueue: ThreadSafeQueue<EventData>
    private let eventStorageManager: EventStorageManager
    
    // Timer management
    private var flushTimer: Timer?
    private let timerLock = NSLock()
    
    // Metrics tracking (thread-safe counters)
    private let metricsLock = NSLock()
    private var _totalEventsTracked: Int = 0
    private var _totalEventsDropped: Int = 0
    private var _totalEventsFlushed: Int = 0
    private var _totalFlushes: Int = 0
    private var _failedFlushes: Int = 0
    
    // Persistent event storage mutex
    private let persistedEventsMutex = NSLock()
    
    // Main Queue for operations to ensure thread safety
    private let workQueue: DispatchQueue
    
    // MARK: - Computed Properties
    
    /// Current flush time threshold in seconds
    public var eventsFlushTimeSeconds: Int {
        get {
            eventsFlushTimeSecondsLock.lock()
            defer { eventsFlushTimeSecondsLock.unlock() }
            return _eventsFlushTimeSeconds
        }
        set {
            eventsFlushTimeSecondsLock.lock()
            _eventsFlushTimeSeconds = newValue
            eventsFlushTimeSecondsLock.unlock()
        }
    }
    
    /// Current flush interval in milliseconds
    public var eventsFlushIntervalMs: Int64 {
        get {
            eventsFlushIntervalMsLock.lock()
            defer { eventsFlushIntervalMsLock.unlock() }
            return _eventsFlushIntervalMs
        }
        set {
            eventsFlushIntervalMsLock.lock()
            _eventsFlushIntervalMs = newValue
            eventsFlushIntervalMsLock.unlock()
        }
    }
    
    /// Total events tracked (thread-safe)
    public var totalEventsTracked: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalEventsTracked
    }
    
    /// Total events dropped due to queue overflow (thread-safe)
    public var totalEventsDropped: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalEventsDropped
    }
    
    /// Total events successfully flushed (thread-safe)
    public var totalEventsFlushed: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalEventsFlushed
    }
    
    // MARK: - Initialization
    
    public init(
        sessionId: String,
        httpClient: HttpClient,
        user: UserManager,
        summaryManager: SummaryManager,
        config: CFConfig
    ) {
        self.sessionId = sessionId
        self.httpClient = httpClient
        self.user = user
        self.summaryManager = summaryManager
        self.config = config
        
        // Initialize atomic properties
        self._eventsFlushTimeSeconds = config.eventsFlushTimeSeconds
        self._eventsFlushIntervalMs = config.eventsFlushIntervalMs
        
        // Initialize queue with config capacity
        self.eventQueue = ThreadSafeQueue<EventData>(capacity: config.eventsQueueSize)
        self.eventStorageManager = EventStorageManager(config: config)
        
        // Create background work queue
        self.workQueue = DispatchQueue(label: "ai.customfit.EventTracker", qos: .utility)
        
        Logger.info("🔔 TRACK: EventTracker initialized with eventsQueueSize=\(config.eventsQueueSize), maxStoredEvents=\(config.maxStoredEvents), eventsFlushTimeSeconds=\(config.eventsFlushTimeSeconds), eventsFlushIntervalMs=\(config.eventsFlushIntervalMs)")
        
        // Load persisted events on initialization
        loadPersistedEvents()
        startPeriodicFlush()
    }
    
    deinit {
        stopPeriodicFlush()
        
        // Try to persist any remaining events
        do {
            try persistEvents()
        } catch {
            Logger.error("Failed to persist events during deinit: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Configuration Update Methods
    
    /// Updates the flush interval and restarts the timer
    /// - Parameter intervalMs: new interval in milliseconds
    /// - Returns: Result containing the updated interval or error details
    public func updateFlushInterval(intervalMs: Int64) -> CFResult<Int64> {
        guard intervalMs > 0 else {
            let message = "Interval must be greater than 0"
            Logger.error("🔔 TRACK: \(message)")
            return CFResult.error(message: message, category: .validation)
        }
        
        // Update interval
        eventsFlushIntervalMs = intervalMs
        
        // Restart timer
        restartPeriodicFlush()
        
        Logger.info("🔔 TRACK: Updated events flush interval to \(intervalMs) ms")
        return CFResult.success(value: intervalMs)
    }
    
    /// Updates the flush time threshold
    /// - Parameter seconds: new threshold in seconds
    /// - Returns: Result containing the updated threshold or error details
    public func updateFlushTimeSeconds(seconds: Int) -> CFResult<Int> {
        guard seconds > 0 else {
            let message = "Seconds must be greater than 0"
            Logger.error("🔔 TRACK: \(message)")
            return CFResult.error(message: message, category: .validation)
        }
        
        // Update threshold
        eventsFlushTimeSeconds = seconds
        
        Logger.info("🔔 TRACK: Updated events flush time threshold to \(seconds) seconds")
        return CFResult.success(value: seconds)
    }
    
    // MARK: - Public Tracking Methods
    
    /// Track an event with improved error handling and storage limit enforcement
    /// Always flushes summaries before tracking a new event
    public func trackEvent(eventName: String, properties: [String: Any] = [:]) -> CFResult<EventData> {
        // Using Logger for consistent logging
        Logger.info("🔔 🔔 TRACK: Tracking event: \(eventName) with properties: \(properties)")
        
        // Always flush summaries first before tracking a new event
        workQueue.async {
            Logger.info("🔔 🔔 TRACK: Flushing summaries before tracking event: \(eventName)")
            let result = self.summaryManager.flushSummaries()
            
            if case .error(let message, _, _, _) = result {
                Logger.warning("🔔 🔔 TRACK: Failed to flush summaries before tracking event: \(message)")
            }
        }
        
        // Validate event name
        if eventName.isEmpty {
            let message = "Event name cannot be blank"
            Logger.warning("🔔 TRACK: Invalid event - \(message)")
            ErrorHandler.handleError(
                message: message,
                source: EventTracker.SOURCE,
                category: .validation,
                severity: .medium
            )
            return CFResult.error(message: message, category: .validation)
        }
        
        // Create event with validation
        let event = EventData(
            eventId: UUID().uuidString,
            eventCustomerId: eventName,
            eventType: .track,
            timestamp: Date(),
            sessionId: sessionId,
            userId: user.getUser().customerId,
            deviceContext: user.getUser().deviceContext,
            applicationInfo: user.getUser().applicationInfo,
            properties: properties
        )
        
        // Check if queue is full
        if eventQueue.isFull {
            Logger.warning("🔔 TRACK: Event queue is full (capacity = \(config.eventsQueueSize)), dropping oldest event")
            ErrorHandler.handleError(
                message: "Event queue is full (capacity = \(config.eventsQueueSize)), dropping oldest event",
                source: EventTracker.SOURCE,
                category: .internal,
                severity: .medium
            )
            
            // Remove oldest event
            _ = eventQueue.dequeue()
            
            // Update metrics
            metricsLock.lock()
            _totalEventsDropped += 1
            metricsLock.unlock()
        }
        
        // Try to enqueue the event
        if !eventQueue.enqueue(event) {
            Logger.warning("🔔 TRACK: Event queue full, forcing flush for event: \(event.eventCustomerId)")
            ErrorHandler.handleError(
                message: "Event queue full, forcing flush for event: \(event.eventCustomerId)",
                source: EventTracker.SOURCE,
                category: .internal,
                severity: .medium
            )
            
            // Flush events to make room
            flushEvents()
            
            // Try again
            if !eventQueue.enqueue(event) {
                let message = "Failed to queue event after flush"
                Logger.error("🔔 TRACK: \(message): \(event.eventCustomerId)")
                ErrorHandler.handleError(
                    message: "\(message): \(event.eventCustomerId)",
                    source: EventTracker.SOURCE,
                    category: .internal,
                    severity: .high
                )
                
                // Update metrics
                metricsLock.lock()
                _totalEventsDropped += 1
                metricsLock.unlock()
                
                return CFResult.error(message: message, category: .internal)
            }
        }
        
        // Update metrics
        metricsLock.lock()
        _totalEventsTracked += 1
        metricsLock.unlock()
        
        Logger.info("🔔 TRACK: Event added to queue: \(event.eventCustomerId), queue size=\(eventQueue.count)")
        
        // If approaching capacity, persist to storage as backup
        if eventQueue.count > Int(Double(config.eventsQueueSize) * 0.7) {
            workQueue.async {
                do {
                    try self.persistEvents()
                } catch {
                    Logger.error("Failed to persist events: \(error.localizedDescription)")
                }
            }
        }
        
        // If queue is full, trigger flush
        if eventQueue.isFull {
            Logger.info("🔔 TRACK: Queue size threshold reached (\(eventQueue.count)/\(config.eventsQueueSize)), triggering flush")
            workQueue.async {
                self.flushEvents()
            }
        }
        
        return CFResult.success(value: event)
    }
    
    /// Track a screen view event
    /// - Parameters:
    ///   - screenName: Name of the screen
    ///   - screenClass: Optional class name of the screen
    ///   - properties: Additional properties
    /// - Returns: Result containing the event data or error details
    public func trackScreenView(screenName: String, screenClass: String? = nil, properties: [String: Any] = [:]) -> CFResult<EventData> {
        var eventProps = properties
        eventProps["screen_name"] = screenName
        if let screenClass = screenClass {
            eventProps["screen_class"] = screenClass
        }
        
        return trackEvent(eventName: CFConstants.EventTypes.SCREEN_VIEW, properties: eventProps)
    }
    
    /// Track a custom event
    /// - Parameters:
    ///   - name: Event name
    ///   - properties: Event properties
    /// - Returns: Result containing the event data or error details
    public func trackCustomEvent(name: String, properties: [String: Any] = [:]) -> CFResult<EventData> {
        var eventProps = properties
        eventProps["event_name"] = name
        
        return trackEvent(eventName: name, properties: eventProps)
    }
    
    /// Flushes events to the server with improved error handling
    /// - Returns: Result containing the number of events flushed or error details
    @discardableResult
    public func flushEvents() -> CFResult<Int> {
        // Always ensure summaries are flushed first
        Logger.info("🔔 🔔 TRACK: Beginning event flush process")
        
        let summaryResult = summaryManager.flushSummaries()
        if case .error(let message, _, _, let category) = summaryResult {
            Logger.warning("🔔 🔔 TRACK: Failed to flush summaries before flushing events: \(message)")
            ErrorHandler.handleError(
                message: "Failed to flush summaries before flushing events: \(message)",
                source: EventTracker.SOURCE,
                category: category,
                severity: .medium
            )
        }
        
        // Check if queue is empty
        if eventQueue.isEmpty {
            Logger.debug("🔔 TRACK: No events to flush")
            return CFResult.success(value: 0)
        }
        
        // Drain the queue
        var eventsToFlush = [EventData]()
        eventQueue.drainTo(&eventsToFlush)
        
        if eventsToFlush.isEmpty {
            Logger.debug("🔔 TRACK: No events to flush after drain")
            return CFResult.success(value: 0)
        }
        
        Logger.info("🔔 TRACK: Flushing \(eventsToFlush.count) events to server")
        
        // Log detailed info about events
        eventsToFlush.enumerated().forEach { index, event in
            Logger.debug("🔔 TRACK: Event #\(index+1): \(event.eventCustomerId)")
        }
        
        // Update metrics
        metricsLock.lock()
        _totalFlushes += 1
        metricsLock.unlock()
        
        // Send events to server
        let result = sendTrackEvents(events: eventsToFlush)
        
        switch result {
        case .success:
            // Update metrics
            metricsLock.lock()
            _totalEventsFlushed += eventsToFlush.count
            metricsLock.unlock()
            
            Logger.info("🔔 TRACK: Successfully flushed \(eventsToFlush.count) events")
            
            // Clear persisted events on successful flush
            workQueue.async {
                do {
                    try self.eventStorageManager.clearEvents()
                    Logger.debug("🔔 TRACK: Cleared persisted events after successful flush")
                } catch {
                    Logger.error("Failed to clear persisted events: \(error.localizedDescription)")
                }
            }
            
            return CFResult.success(value: eventsToFlush.count)
            
        case .error(let message, let error, _, let category):
            // Update metrics
            metricsLock.lock()
            _failedFlushes += 1
            metricsLock.unlock()
            
            Logger.warning("🔔 TRACK: Failed to flush events: \(message)")
            
            // Persist undelivered events for retry later
            workQueue.async {
                do {
                    Logger.info("🔔 TRACK: Persisting \(eventsToFlush.count) undelivered events for retry later")
                    self.persistedEventsMutex.lock()
                    try self.eventStorageManager.storeEvents(events: eventsToFlush)
                    self.persistedEventsMutex.unlock()
                } catch {
                    Logger.error("Failed to persist undelivered events: \(error.localizedDescription)")
                }
            }
            
            if let error = error {
                return CFResult.error(message: "Failed to flush events: \(message)", error: error, category: category)
            } else {
                return CFResult.error(message: "Failed to flush events: \(message)", category: category)
            }
        }
    }
    
    /// Persist current events to storage for later retrieval
    /// - Returns: Result containing the number of events persisted or error details
    @discardableResult
    public func persistEvents() throws -> CFResult<Int> {
        persistedEventsMutex.lock()
        defer { persistedEventsMutex.unlock() }
        
        // Get a snapshot of all events in the queue
        let events = eventQueue.snapshot()
        
        // Enforce maxStoredEvents limit
        let eventsToStore: [EventData]
        if events.count > config.maxStoredEvents {
            Logger.warning("Attempting to store \(events.count) events, but maxStoredEvents is \(config.maxStoredEvents). Truncating.")
            eventsToStore = Array(events.suffix(config.maxStoredEvents))
        } else {
            eventsToStore = events
        }
        
        if eventsToStore.isEmpty {
            Logger.debug("No events to persist")
            return CFResult.success(value: 0)
        }
        
        Logger.info("Persisting \(eventsToStore.count) events to storage")
        try eventStorageManager.storeEvents(events: eventsToStore)
        
        return CFResult.success(value: eventsToStore.count)
    }
    
    // MARK: - Private Methods
    
    /// Load persisted events from storage while respecting queue size limits
    private func loadPersistedEvents() {
        workQueue.async {
            do {
                Logger.info("Loading persisted events from storage...")
                let events = try self.eventStorageManager.loadEvents()
                
                // Check if we need to enforce the maxStoredEvents limit
                let eventsToLoad: [EventData]
                if events.count > self.config.maxStoredEvents {
                    Logger.warning("Loaded \(events.count) events, but maxStoredEvents is \(self.config.maxStoredEvents). Truncating.")
                    eventsToLoad = Array(events.suffix(self.config.maxStoredEvents))
                } else {
                    eventsToLoad = events
                }
                
                if eventsToLoad.isEmpty {
                    Logger.info("No persisted events found")
                    return
                }
                
                var addedCount = 0
                var droppedCount = 0
                
                // Add events to the queue, respecting queue size limits
                for event in eventsToLoad {
                    if !self.eventQueue.isFull {
                        if self.eventQueue.enqueue(event) {
                            addedCount += 1
                            
                            // Update metrics
                            self.metricsLock.lock()
                            self._totalEventsTracked += 1
                            self.metricsLock.unlock()
                        }
                    } else {
                        droppedCount += 1
                        
                        // Update metrics
                        self.metricsLock.lock()
                        self._totalEventsDropped += 1
                        self.metricsLock.unlock()
                    }
                }
                
                if addedCount > 0 {
                    Logger.info("Loaded \(addedCount) persisted events from storage")
                }
                
                if droppedCount > 0 {
                    Logger.warning("Dropped \(droppedCount) persisted events due to queue size limit")
                    ErrorHandler.handleError(
                        message: "Dropped \(droppedCount) persisted events due to queue size limit",
                        source: EventTracker.SOURCE,
                        category: .internal,
                        severity: .medium
                    )
                }
            } catch {
                Logger.error("Failed to load persisted events: \(error.localizedDescription)")
                ErrorHandler.handleException(
                    error: error,
                    message: "Failed to load persisted events",
                    source: EventTracker.SOURCE,
                    severity: .medium
                )
            }
        }
    }
    
    /// Starts the periodic flush timer
    private func startPeriodicFlush() {
        workQueue.async {
            self.timerLock.lock()
            defer { self.timerLock.unlock() }
            
            // Cancel existing timer
            self.flushTimer?.invalidate()
            self.flushTimer = nil
            
            // Get current flush interval
            let interval = TimeInterval(self.eventsFlushIntervalMs) / 1000.0
            
            // Create new timer on main thread
            DispatchQueue.main.async {
                self.flushTimer = Timer.scheduledTimer(
                    withTimeInterval: interval,
                    repeats: true
                ) { [weak self] _ in
                    guard let self = self else { return }
                    
                    self.workQueue.async {
                        // Check for events that are older than flush time threshold
                        if let firstEvent = self.eventQueue.peek(),
                           Date().timeIntervalSince(firstEvent.timestamp) >= TimeInterval(self.eventsFlushTimeSeconds) {
                            Logger.debug("🔔 TRACK: Event age threshold reached, triggering flush")
                            self.flushEvents()
                        }
                    }
                }
                
                // Add to common run loop modes to ensure timer fires during scrolling, etc.
                if let timer = self.flushTimer {
                    RunLoop.current.add(timer, forMode: .common)
                }
            }
            
            Logger.debug("Started periodic event flush timer with interval \(interval) seconds")
        }
    }
    
    /// Stops the periodic flush timer
    private func stopPeriodicFlush() {
        timerLock.lock()
        defer { timerLock.unlock() }
        
        flushTimer?.invalidate()
        flushTimer = nil
        
        Logger.debug("Stopped periodic event flush timer")
    }
    
    /// Restarts the periodic flush timer with updated interval
    private func restartPeriodicFlush() {
        stopPeriodicFlush()
        startPeriodicFlush()
        
        Logger.debug("Restarted periodic event flush timer")
    }
    
    /// Builds the event API payload
    /// - Parameter events: Events to send
    /// - Returns: Dictionary containing the API payload
    private func buildEventApiPayload(events: [EventData]) -> [String: Any] {
        var payload: [String: Any] = [:]
        
        // Add user data
        payload["user"] = user.getUser().toDictionary()
        
        // Add events
        var eventsArray: [[String: Any]] = []
        for event in events {
            eventsArray.append(event.toDictionary())
        }
        payload["events"] = eventsArray
        
        // Add SDK version
        payload["cf_client_sdk_version"] = "1.0.0" 
        
        return payload
    }
    
    /// Sends events to the tracking API
    /// - Parameter events: Events to send
    /// - Returns: Result indicating success or failure
    private func sendTrackEvents(events: [EventData]) -> CFResult<Bool> {
        do {
            // Build payload
            let eventRequestData = buildEventApiPayload(events: events)
            
            // Serialize to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: eventRequestData, options: [])
            
            // Create URL
            let eventsUrl = "\(config.apiBaseUrl)\(CFConstants.Api.EVENTS_PATH)?cfenc=\(config.clientKey)"
            guard let url = URL(string: eventsUrl) else {
                return CFResult.error(message: "Invalid events URL: \(eventsUrl)", category: .validation)
            }
            
            // Create circuit breaker
            let circuitBreaker = CircuitBreaker.getOrCreate(name: "events-api")
            
            // Create semaphore for synchronous execution
            let semaphore = DispatchSemaphore(value: 0)
            var resultValue: CFResult<Bool> = CFResult.error(message: "Unknown error", category: .unknown)
            
            // Use circuit breaker to prevent cascading failures
            do {
                try circuitBreaker.execute(operation: {
                    // Use our HttpClient to post the events
                    httpClient.postJson(url: url, payload: jsonData) { result in
                        // Handle response
                        resultValue = result
                        semaphore.signal()
                    }
                })
            } catch {
                return CFResult.error(message: "Circuit breaker prevented event send", error: error, category: .network)
            }
            
            // Wait for response (with timeout)
            if semaphore.wait(timeout: .now() + 30.0) == .timedOut {
                circuitBreaker.recordFailure()
                return CFResult.error(message: "Timeout waiting for events API response", category: .network)
            }
            
            // Process the result
            if case .success = resultValue {
                circuitBreaker.recordSuccess()
            } else {
                circuitBreaker.recordFailure()
            }
            
            return resultValue
        } catch {
            // Handle serialization errors
            Logger.error("Error serializing event data: \(error.localizedDescription)")
            ErrorHandler.handleException(
                error: error,
                message: "Error serializing event data",
                source: EventTracker.SOURCE,
                severity: .high
            )
            return CFResult.error(message: "Error serializing events", error: error, category: .serialization)
        }
    }
    
    /// Get metrics as a dictionary
    /// - Returns: Dictionary of metrics
    public func getMetrics() -> [String: Any] {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        return [
            "totalEventsTracked": _totalEventsTracked,
            "totalEventsDropped": _totalEventsDropped,
            "totalEventsFlushed": _totalEventsFlushed,
            "totalFlushes": _totalFlushes,
            "failedFlushes": _failedFlushes,
            "currentQueueSize": eventQueue.count,
            "queueCapacity": config.eventsQueueSize,
            "flushIntervalMs": eventsFlushIntervalMs,
            "flushTimeSeconds": eventsFlushTimeSeconds
        ]
    }
}

/// Event Storage Manager for persisting events
class EventStorageManager {
    private let config: CFConfig
    private let fileManager = FileManager.default
    private let persistenceFileName = "customfit_events.json"
    
    init(config: CFConfig) {
        self.config = config
    }
    
    /// Store events to disk
    func storeEvents(events: [EventData]) throws {
        let eventsData = try JSONEncoder().encode(events)
        
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(persistenceFileName)
        
        try eventsData.write(to: fileURL, options: .atomic)
    }
    
    /// Load events from disk
    func loadEvents() throws -> [EventData] {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(persistenceFileName)
        
        if !fileManager.fileExists(atPath: fileURL.path) {
            return []
        }
        
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([EventData].self, from: data)
    }
    
    /// Clear stored events
    func clearEvents() throws {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(persistenceFileName)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
} 