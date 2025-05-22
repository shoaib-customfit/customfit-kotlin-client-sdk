import Foundation

/// Manages tracking and sending of analytics events
public class EventTracker {
    
    // MARK: - Constants
    
    /// Source identifier for logging
    public static let SOURCE = "EventTracker"
    
    /// Default flush interval in ms (30 seconds)
    static let DEFAULT_FLUSH_INTERVAL_MS: Int64 = 30000
    
    /// Default flush time threshold in seconds (60 seconds)
    static let DEFAULT_FLUSH_TIME_SECONDS = 60
    
    // MARK: - Properties
    
    /// Event queue
    private let eventQueue = EventQueue()
    
    /// Config reference
    private let config: CFConfig
    
    /// User for events
    private let user: CFUserProvider
    
    /// HTTP client for sending events
    private let httpClient: HttpClient
    
    /// Session ID for grouping events
    private let sessionId: String
    
    /// Storage manager for persisting events
    private let eventStorageManager: EventStorageManager
    
    /// Summary manager reference
    private let summaryManager: SummaryManager
    
    /// Background work queue
    private let workQueue = DispatchQueue(label: "ai.customfit.EventTracker", qos: .utility)
    
    /// Lock for synchronized access
    private let lock = NSLock()
    
    /// Lock for event flush timer
    private let timerLock = NSLock()
    
    /// Lock for persisted events operations
    private let persistedEventsMutex = NSLock()
    
    /// Metrics lock for thread safety
    private let metricsLock = NSLock()
    
    /// Timer for periodic event flushing
    private var flushTimer: Timer?
    
    /// Last time events were flushed
    private var lastFlushTime: Date = Date()
    
    /// Flush interval in milliseconds
    private var flushIntervalMs: Int64 = DEFAULT_FLUSH_INTERVAL_MS
    
    /// Flush time threshold in seconds
    private var flushTimeSeconds: Int = DEFAULT_FLUSH_TIME_SECONDS
    
    /// Events flush interval in milliseconds
    private var eventsFlushIntervalMs: Int64 {
        get {
            lock.lock()
            defer { lock.unlock() }
            return flushIntervalMs
        }
    }
    
    /// Events flush time threshold in seconds
    private var eventsFlushTimeSeconds: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            return flushTimeSeconds
        }
    }
    
    // MARK: - Metrics
    
    /// Total events tracked
    private var _totalEventsTracked: Int = 0
    
    /// Total events flushed
    private var _totalEventsFlushed: Int = 0
    
    /// Total events dropped
    private var _totalEventsDropped: Int = 0
    
    /// Total flush attempts
    private var _totalFlushes: Int = 0
    
    /// Failed flush attempts
    private var _failedFlushes: Int = 0
    
    /// Get total events tracked
    public var totalEventsTracked: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalEventsTracked
    }
    
    /// Get total events flushed
    public var totalEventsFlushed: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalEventsFlushed
    }
    
    /// Get total events dropped
    public var totalEventsDropped: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalEventsDropped
    }
    
    /// Get total flush attempts
    public var totalFlushes: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalFlushes
    }
    
    /// Get failed flush attempts
    public var failedFlushes: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _failedFlushes
    }
    
    // MARK: - Initialization
    
    /// Initialize with required dependencies
    /// - Parameters:
    ///   - config: Configuration for the SDK
    ///   - user: User provider for user context
    ///   - sessionId: Session ID for grouping events
    ///   - httpClient: HTTP client for API requests
    ///   - summaryManager: Summary manager for event summaries
    public init(
        config: CFConfig,
        user: CFUserProvider,
        sessionId: String,
        httpClient: HttpClient,
        summaryManager: SummaryManager
    ) {
        self.config = config
        self.user = user
        self.sessionId = sessionId
        self.httpClient = httpClient
        self.summaryManager = summaryManager
        self.eventStorageManager = EventStorageManager(config: config)
        
        // Set default values for flush settings
        self.flushIntervalMs = EventTracker.DEFAULT_FLUSH_INTERVAL_MS
        self.flushTimeSeconds = EventTracker.DEFAULT_FLUSH_TIME_SECONDS
        
        // Initialize event queue
        let queueSize = max(config.eventsQueueSize, 10)
        eventQueue.setMaxSize(queueSize)
        
        // Start periodic flush
        startPeriodicFlush()
        
        // Load persisted events
        loadPersistedEvents()
        
        Logger.info("EventTracker initialized with queue size \(queueSize), flush interval \(EventTracker.DEFAULT_FLUSH_INTERVAL_MS)ms")
    }
    
    deinit {
        stopPeriodicFlush()
    }
    
    // MARK: - Configuration
    
    /// Update the flush interval in milliseconds
    /// - Parameter intervalMs: New flush interval in milliseconds
    /// - Returns: Result containing the updated interval or error details
    public func updateFlushIntervalMs(intervalMs: Int64) -> CFResult<Int64> {
        if intervalMs <= 0 {
            let message = "Interval must be greater than 0"
            Logger.error("🔔 TRACK: \(message)")
            return CFResult.createError(message: message, category: .validation)
        }
        
        lock.lock()
        flushIntervalMs = intervalMs
        lock.unlock()
        
        Logger.info("🔔 TRACK: Updated events flush interval to \(intervalMs) ms")
        return CFResult.createSuccess(value: intervalMs)
    }
    
    // MARK: - Public Tracking Methods
    
    /// Track an event with improved error handling and storage limit enforcement
    /// Always flushes summaries before tracking a new event
    public func trackEvent(eventName: String, properties: [String: Any]? = nil) -> CFResult<EventData> {
        // Using Logger for consistent logging
        Logger.info("🔔 🔔 TRACK: Tracking event: \(eventName) with properties: \(properties ?? [:])")
        
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
            return CFResult.createError(message: message, category: .validation)
        }
        
        // Create event with validation
        let event = EventData(
            eventId: UUID().uuidString,
            name: eventName,
            eventType: .track,
            timestamp: Date(),
            sessionId: sessionId,
            userId: user.getUser().getUserId(),
            isAnonymous: user.getUser().getUserId() == nil,
            deviceContext: user.getUser().getDeviceContext(),
            applicationInfo: user.getUser().getApplicationInfo(),
            properties: properties ?? [:]
        )
        
        // Check if queue is full
        if eventQueue.isFull {
            Logger.warning("🔔 TRACK: Event queue is full (capacity = \(config.eventsQueueSize)), dropping oldest event")
            ErrorHandler.handleError(
                message: "Event queue is full (capacity = \(config.eventsQueueSize)), dropping oldest event",
                source: EventTracker.SOURCE,
                category: .state,
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
            Logger.warning("🔔 TRACK: Event queue full, forcing flush for event: \(event.name)")
            ErrorHandler.handleError(
                message: "Event queue full, forcing flush for event: \(event.name)",
                source: EventTracker.SOURCE,
                category: .state,
                severity: .medium
            )
            
            // Flush events to make room
            flushEvents()
            
            // Try again
            if !eventQueue.enqueue(event) {
                let message = "Failed to queue event after flush"
                Logger.error("🔔 TRACK: \(message): \(event.name)")
                ErrorHandler.handleError(
                    message: "\(message): \(event.name)",
                    source: EventTracker.SOURCE,
                    category: .state,
                    severity: .high
                )
                
                // Update metrics
                metricsLock.lock()
                _totalEventsDropped += 1
                metricsLock.unlock()
                
                return CFResult.createError(message: message, category: .state)
            }
        }
        
        // Update metrics
        metricsLock.lock()
        _totalEventsTracked += 1
        metricsLock.unlock()
        
        Logger.info("🔔 TRACK: Event added to queue: \(event.name), queue size=\(eventQueue.count)")
        
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
        
        return CFResult.createSuccess(value: event)
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
        lock.lock()
        defer { lock.unlock() }
        
        // Check if queue is empty
        if eventQueue.isEmpty {
            Logger.debug("🔔 TRACK: No events to flush")
            return CFResult.createSuccess(value: 0)
        }
        
        // Update last flush time
        lastFlushTime = Date()
        
        // Drain the queue
        var eventsToFlush = [EventData]()
        eventQueue.drainTo(&eventsToFlush)
        
        if eventsToFlush.isEmpty {
            Logger.debug("🔔 TRACK: No events to flush after drain")
            return CFResult.createSuccess(value: 0)
        }
        
        // Log detailed info about events
        eventsToFlush.enumerated().forEach { index, event in
            Logger.debug("🔔 TRACK: Event #\(index+1): \(event.name)")
        }
        
        Logger.info("🔔 TRACK: Flushing \(eventsToFlush.count) events")
        
        // Make sure summaries are flushed first if any
        let summaryResult = summaryManager.flushSummaries()
        
        switch summaryResult {
        case .success:
            // Summary flush successful, proceed with events
            break
            
        case .error(let message, let error, _, let category):
            // Log summary flush error but continue with event flush
            Logger.warning("🔔 TRACK: Failed to flush summaries before events: \(message)")
            ErrorHandler.handleError(
                message: "Failed to flush summaries before flushing events: \(message)",
                source: EventTracker.SOURCE,
                category: category.toErrorHandlerCategory,
                severity: .medium
            )
        }
        
        // Update metrics
        metricsLock.lock()
        _totalFlushes += 1
        metricsLock.unlock()
        
        // Send events to server
        let result = sendEvents(events: eventsToFlush)
        
        switch result {
        case .success:
            // Update metrics
            metricsLock.lock()
            _totalEventsFlushed += eventsToFlush.count
            metricsLock.unlock()
            
            Logger.info("🔔 TRACK: Successfully flushed \(eventsToFlush.count) events")
            
            return CFResult.createSuccess(value: eventsToFlush.count)
            
        case .error(let message, let error, _, let category):
            // Update metrics
            metricsLock.lock()
            _failedFlushes += 1
            metricsLock.unlock()
            
            Logger.warning("🔔 TRACK: Failed to flush events: \(message)")
            
            // Add back to queue if possible, with priority given to newer events
            let originalCount = eventsToFlush.count
            
            // Try re-adding events in reverse order (newest first)
            var readdedCount = 0
            for event in eventsToFlush.reversed() {
                if !eventQueue.isFull {
                    if eventQueue.enqueue(event) {
                        readdedCount += 1
                    }
                } else {
                    break
                }
            }
            
            if readdedCount < originalCount {
                let droppedCount = originalCount - readdedCount
                Logger.warning("🔔 TRACK: Re-queued \(readdedCount) of \(originalCount) events, dropped \(droppedCount)")
                
                // Update metrics
                metricsLock.lock()
                _totalEventsDropped += droppedCount
                metricsLock.unlock()
            } else {
                Logger.info("🔔 TRACK: Re-queued all \(originalCount) events after failed flush")
            }
            
            if let error = error {
                return CFResult.createError(message: "Failed to flush events: \(message)", error: error, category: category)
            } else {
                return CFResult.createError(message: "Failed to flush events: \(message)", category: category)
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
            return CFResult.createSuccess(value: 0)
        }
        
        Logger.info("Persisting \(eventsToStore.count) events to storage")
        try eventStorageManager.storeEvents(events: eventsToStore)
        
        return CFResult.createSuccess(value: eventsToStore.count)
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
    
    /// Send events to the server
    /// - Parameter events: Events to send
    /// - Returns: Result indicating success or failure
    private func sendEvents(events: [EventData]) -> CFResult<Bool> {
        do {
            // Build payload
            let eventRequestData = buildEventApiPayload(events: events)
            
            // Serialize to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: eventRequestData, options: [])
            
            // Create URL
            let eventsUrl = "\(CFConstants.Api.BASE_API_URL)\(CFConstants.Api.EVENTS_PATH)?cfenc=\(config.clientKey)"
            guard let url = URL(string: eventsUrl) else {
                return CFResult.createError(message: "Invalid events URL: \(eventsUrl)", category: .validation)
            }
            
            // Create circuit breaker
            let circuitBreaker = CircuitBreaker.getOrCreate(name: "events-api")
            
            // Create semaphore for synchronous execution
            let semaphore = DispatchSemaphore(value: 0)
            var resultValue: CFResult<Bool> = CFResult.createError(message: "Unknown error", category: .unknown)
            
            // Use circuit breaker to prevent cascading failures
            do {
                try circuitBreaker.execute(operation: {
                    // Use HttpClient to post the events
                    self.httpClient.postJson(url: url, payload: jsonData) { result in
                        // Handle response
                        resultValue = result
                        semaphore.signal()
                    }
                })
            } catch {
                return CFResult.createError(message: "Circuit breaker prevented event send", error: error, category: .network)
            }
            
            // Wait for response (with timeout)
            if semaphore.wait(timeout: .now() + 30.0) == .timedOut {
                circuitBreaker.recordFailure()
                return CFResult.createError(message: "Timeout waiting for events API response", category: .network)
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
            return CFResult.createError(message: "Error serializing events", error: error, category: .serialization)
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

/// Queue for managing event data with thread safety and configurable size
private class EventQueue {
    /// Internal storage array
    private var queue = [EventData]()
    
    /// Maximum queue size
    private var maxSize = 100
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Whether the queue is empty
    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return queue.isEmpty
    }
    
    /// Number of items in the queue
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return queue.count
    }
    
    /// Whether the queue is full
    var isFull: Bool {
        lock.lock()
        defer { lock.unlock() }
        return queue.count >= maxSize
    }
    
    /// Set maximum queue size
    /// - Parameter size: New maximum size
    func setMaxSize(_ size: Int) {
        lock.lock()
        maxSize = size
        lock.unlock()
    }
    
    /// Add an item to the queue
    /// - Parameter item: Item to add
    /// - Returns: Whether the item was added
    func enqueue(_ item: EventData) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        if queue.count >= maxSize {
            return false
        }
        
        queue.append(item)
        return true
    }
    
    /// Remove an item from the queue
    /// - Returns: The removed item or nil if queue is empty
    func dequeue() -> EventData? {
        lock.lock()
        defer { lock.unlock() }
        
        if queue.isEmpty {
            return nil
        }
        
        return queue.removeFirst()
    }
    
    /// Get the first item without removing it
    /// - Returns: The first item or nil if queue is empty
    func peek() -> EventData? {
        lock.lock()
        defer { lock.unlock() }
        
        if queue.isEmpty {
            return nil
        }
        
        return queue.first
    }
    
    /// Clear the queue
    func clear() {
        lock.lock()
        queue.removeAll()
        lock.unlock()
    }
    
    /// Get a copy of all items in the queue
    /// - Returns: Copy of all items
    func snapshot() -> [EventData] {
        lock.lock()
        defer { lock.unlock() }
        return queue
    }
    
    /// Drain the queue to the provided array
    /// - Parameter array: Array to drain to
    func drainTo(_ array: inout [EventData]) {
        lock.lock()
        array.append(contentsOf: queue)
        queue.removeAll()
        lock.unlock()
    }
} 