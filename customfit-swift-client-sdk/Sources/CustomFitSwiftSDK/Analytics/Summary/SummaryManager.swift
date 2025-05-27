import Foundation

/// Manager for summarizing session data and sending to server
public class SummaryManager {
    
    // MARK: - Constants
    
    private static let SOURCE = "SummaryManager"
    
    // MARK: - Properties
    
    private let httpClient: HttpClient
    private let user: UserManager
    private let config: CFConfig
    
    /// Thread-safe queue for pending summaries
    private let summaryQueue: ThreadSafeQueue<SummaryData>
    
    /// Dictionary to track which experience_ids have already been tracked to prevent duplicates
    private var summaryTrackMap: [String: Bool] = [:]
    private let trackMapLock = NSLock()
    
    /// Lock for thread-safe operations
    private let lock = NSLock()
    
    /// Timer for periodic flushing
    private var flushTimer: Timer?
    private let timerLock = NSLock()
    
    /// Last flush time
    private var lastFlushTime: Date = Date()
    
    /// Work queue for background operations
    private let workQueue: DispatchQueue
    
    /// Summary flush interval in milliseconds
    private let summariesFlushIntervalMs: Int64
    
    /// Summary flush time in seconds
    private let summariesFlushTimeSeconds: Int
    
    /// Metrics tracking
    private let metricsLock = NSLock()
    private var _totalSummariesTracked: Int = 0
    private var _totalSummariesFlushed: Int = 0
    private var _totalSummariesDropped: Int = 0
    private var _totalFlushes: Int = 0
    private var _failedFlushes: Int = 0
    
    // MARK: - Computed Properties
    
    /// Total tracked summaries
    public var totalSummariesTracked: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalSummariesTracked
    }
    
    /// Total flushed summaries
    public var totalSummariesFlushed: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalSummariesFlushed
    }
    
    /// Total dropped summaries
    public var totalSummariesDropped: Int {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _totalSummariesDropped
    }
    
    // MARK: - Initialization
    
    /// Initialize a new summary manager
    /// - Parameters:
    ///   - httpClient: HTTP client for network operations
    ///   - user: User manager
    ///   - config: SDK configuration
    public init(httpClient: HttpClient, user: UserManager, config: CFConfig) {
        self.httpClient = httpClient
        self.user = user
        self.config = config
        
        // Create queue with capacity from config
        self.summaryQueue = ThreadSafeQueue<SummaryData>(capacity: config.summariesQueueSize)
        
        // Create background queue
        self.workQueue = DispatchQueue(label: "ai.customfit.SummaryManager", qos: .utility)
        
        // Initialize timer
        self.summariesFlushIntervalMs = config.summariesFlushIntervalMs
        self.summariesFlushTimeSeconds = config.summariesFlushTimeSeconds
        
        Logger.info("📊 SUMMARY: SummaryManager initialized with summaryQueueSize=\(config.summariesQueueSize), summariesFlushTimeSeconds=\(config.summariesFlushTimeSeconds), flushIntervalMs=\(config.summariesFlushIntervalMs)")
        
        // Start periodic flushing
        startPeriodicFlush()
        Logger.info("📊 SUMMARY: Started periodic summary flush with interval \(summariesFlushIntervalMs) ms")
    }
    
    // MARK: - Public Methods
    
    /// Track a summary with the specified data
    /// - Parameter summary: Summary data to track
    /// - Returns: Result containing the summary data or error details
    public func trackSummary(summary: SummaryData) -> CFResult<SummaryData> {
        // Validate summary
        if summary.name.isEmpty {
            let message = "Summary name cannot be empty"
            Logger.warning("📊 SUMMARY: \(message)")
            return CFResult.createError(message: message, category: .validation)
        }
        
        // Check if queue is full
        if summaryQueue.isFull {
            let message = "Summary queue is full (capacity = \(config.summariesQueueSize)), dropping oldest summary"
            Logger.warning("📊 SUMMARY: \(message)")
            ErrorHandler.handleError(
                message: message,
                source: SummaryManager.SOURCE,
                category: .state,
                severity: .medium
            )
            
            // Drop oldest summary
            _ = summaryQueue.dequeue()
            
            // Update metrics
            metricsLock.lock()
            _totalSummariesDropped += 1
            metricsLock.unlock()
        }
        
        // Try to enqueue summary
        if !summaryQueue.enqueue(summary) {
            Logger.warning("📊 SUMMARY: Summary queue is full, flushing summaries")
            
            // Try flushing
            flushSummaries()
            
            // Try again
            if !summaryQueue.enqueue(summary) {
                let message = "Failed to enqueue summary after flush"
                Logger.error("📊 SUMMARY: \(message)")
                ErrorHandler.handleError(
                    message: message,
                    source: SummaryManager.SOURCE,
                    category: .state,
                    severity: .high
                )
                
                // Update metrics
                metricsLock.lock()
                _totalSummariesDropped += 1
                metricsLock.unlock()
                
                return CFResult.createError(message: message, category: .state)
            }
        }
        
        // Update metrics
        metricsLock.lock()
        _totalSummariesTracked += 1
        metricsLock.unlock()
        
        Logger.info("📊 SUMMARY: Tracked summary: \(summary.name), queue size=\(summaryQueue.count)")
        
        // If queue is full or near capacity, trigger flush
        if summaryQueue.count > Int(Double(config.summariesQueueSize) * 0.7) {
            workQueue.async {
                self.flushSummaries()
            }
        }
        
        return CFResult.createSuccess(value: summary)
    }
    
    /// Track a feature usage summary
    /// - Parameters:
    ///   - featureId: Feature ID
    ///   - count: Number of times the feature was used (default 1)
    /// - Returns: Result containing the summary data or error details
    public func trackFeatureUsage(featureId: String, count: Int = 1) -> CFResult<SummaryData> {
        let summary = SummaryData(
            name: "feature_usage",
            count: count,
            properties: ["feature_id": featureId]
        )
        
        return trackSummary(summary: summary)
    }
    
    /// Track a feature view summary
    /// - Parameters:
    ///   - featureId: Feature ID
    ///   - count: Number of views (default 1)
    /// - Returns: Result containing the summary data or error details
    public func trackFeatureView(featureId: String, count: Int = 1) -> CFResult<SummaryData> {
        let summary = SummaryData(
            name: "feature_view",
            count: count,
            properties: ["feature_id": featureId]
        )
        
        return trackSummary(summary: summary)
    }
    
    /// Track a config request summary
    /// - Parameters:
    ///   - config: Config data
    ///   - customerUserId: Customer user ID
    ///   - sessionId: Session ID
    /// - Returns: Result indicating success or failure
    public func trackConfigRequest(
        config: [String: Any],
        customerUserId: String,
        sessionId: String
    ) -> CFResult<Bool> {
        let summary = SummaryData(
            name: "config_request",
            count: 1,
            properties: [
                "config": config,
                "customer_user_id": customerUserId,
                "session_id": sessionId
            ]
        )
        
        let result = trackSummary(summary: summary)
        return result.isSuccess ? CFResult.createSuccess(value: true) : CFResult.createError(message: "Failed to track config request", category: .state)
    }
    
    /// Track a config summary
    /// - Parameter config: Configuration data
    /// - Returns: Result indicating success or failure
    public func trackConfigSummary(_ config: [String: Any]) -> CFResult<Bool> {
        let summary = SummaryData(
            name: "config_summary",
            count: 1,
            properties: ["config": config]
        )
        
        let result = trackSummary(summary: summary)
        return result.isSuccess ? CFResult.createSuccess(value: true) : CFResult.createError(message: "Failed to track config summary", category: .state)
    }
    
    /// Flush summaries to the server
    /// - Returns: Result containing the number of summaries flushed or error details
    @discardableResult
    public func flushSummaries() -> CFResult<Int> {
        lock.lock()
        defer { lock.unlock() }
        
        // Check if queue is empty
        if summaryQueue.isEmpty {
            Logger.debug("📊 SUMMARY: No summaries to flush")
            return CFResult.createSuccess(value: 0)
        }
        
        // Update last flush time
        lastFlushTime = Date()
        
        // Drain the queue
        var summariesToFlush = [SummaryData]()
        summaryQueue.drainTo(&summariesToFlush)
        
        if summariesToFlush.isEmpty {
            Logger.debug("📊 SUMMARY: No summaries to flush after drain")
            return CFResult.createSuccess(value: 0)
        }
        
        // Merge similar summaries to optimize payload size
        let mergedSummaries = mergeSummaries(summariesToFlush)
        
        Logger.info("📊 SUMMARY: Flushing \(mergedSummaries.count) summaries (from \(summariesToFlush.count) original items)")
        
        // Update metrics
        metricsLock.lock()
        _totalFlushes += 1
        metricsLock.unlock()
        
        // Send summaries to server
        let result = sendSummaries(summaries: mergedSummaries)
        
        switch result {
        case .success:
            // Update metrics
            metricsLock.lock()
            _totalSummariesFlushed += summariesToFlush.count
            metricsLock.unlock()
            
            Logger.info("📊 SUMMARY: Successfully flushed \(mergedSummaries.count) summaries")
            return CFResult.createSuccess(value: summariesToFlush.count)
            
        case .error(let message, let error, _, let category):
            // Update metrics
            metricsLock.lock()
            _failedFlushes += 1
            metricsLock.unlock()
            
            Logger.warning("📊 SUMMARY: Failed to flush summaries: \(message)")
            
            // Add back to queue if possible, with priority given to newer summaries
            let originalCount = summariesToFlush.count
            
            // Try re-adding summaries in reverse order (newest first)
            var readdedCount = 0
            for summary in summariesToFlush.reversed() {
                if !summaryQueue.isFull {
                    if summaryQueue.enqueue(summary) {
                        readdedCount += 1
                    }
                } else {
                    break
                }
            }
            
            if readdedCount < originalCount {
                let droppedCount = originalCount - readdedCount
                Logger.warning("📊 SUMMARY: Re-queued \(readdedCount) of \(originalCount) summaries, dropped \(droppedCount)")
                
                // Update metrics
                metricsLock.lock()
                _totalSummariesDropped += droppedCount
                metricsLock.unlock()
            } else {
                Logger.info("📊 SUMMARY: Re-queued all \(originalCount) summaries after failed flush")
            }
            
            if let error = error {
                return CFResult.createError(message: "Failed to flush summaries: \(message)", error: error, category: category)
            } else {
                return CFResult.createError(message: "Failed to flush summaries: \(message)", category: category)
            }
        }
    }
    
    /// Push a configuration summary (matches Kotlin behavior)
    /// - Parameter config: Configuration data
    /// - Returns: Result indicating success or failure
    public func pushSummary(config: [String: Any]) -> CFResult<Bool> {
        // Log the config being processed
        Logger.info("📊 SUMMARY: Processing summary for config: \(config["key"] ?? "unknown")")
        
        // Validate required fields are present
        guard let experienceId = config["experience_id"] as? String else {
            let message = "Missing mandatory 'experience_id' in config"
            Logger.warning("📊 SUMMARY: Missing mandatory field 'experience_id', summary not tracked")
            ErrorHandler.handleError(
                message: message,
                source: SummaryManager.SOURCE,
                category: .validation,
                severity: .medium
            )
            return CFResult.createError(message: message, category: .validation)
        }
        
        // Check if this experience_id has already been tracked
        trackMapLock.lock()
        let shouldProcess: Bool
        if summaryTrackMap.contains(where: { $0.key == experienceId }) {
            Logger.debug("📊 SUMMARY: Experience already processed: \(experienceId)")
            shouldProcess = false
        } else {
            summaryTrackMap[experienceId] = true
            Logger.info("📊 SUMMARY: Summary tracked for key: \(config["key"] ?? "unknown")")
            shouldProcess = true
        }
        trackMapLock.unlock()
        
        if !shouldProcess {
            Logger.debug("📊 SUMMARY: Skipping duplicate summary for experience: \(experienceId)")
            return CFResult.createSuccess(value: true) // Return success but don't track duplicate
        }
        
        // Validate other mandatory fields before creating the summary
        let configId = config["config_id"] as? String
        let variationId = config["variation_id"] as? String
        let versionString = config["version"] != nil ? String(describing: config["version"]!) : nil
        
        var missingFields: [String] = []
        if configId == nil { missingFields.append("config_id") }
        if variationId == nil { missingFields.append("variation_id") }
        if versionString == nil { missingFields.append("version") }
        
        if !missingFields.isEmpty {
            let message = "Missing mandatory fields for summary: \(missingFields.joined(separator: ", "))"
            Logger.warning("📊 SUMMARY: Missing mandatory fields: \(missingFields.joined(separator: ", ")), summary not tracked")
            ErrorHandler.handleError(
                message: message,
                source: SummaryManager.SOURCE,
                category: .validation,
                severity: .medium
            )
            return CFResult.createError(message: message, category: .validation)
        }
        
        // Create CFConfigRequestSummary to match Kotlin structure
        let configSummary = CFConfigRequestSummary(
            configId: configId,
            version: versionString,
            userId: config["user_id"] as? String,
            requestedTime: CFConfigRequestSummary.timestampFormatter.string(from: Date()),
            variationId: variationId,
            userCustomerId: user.getUser().getUserId() ?? "",
            sessionId: UUID().uuidString, // TODO: Get actual session ID from session manager
            behaviourId: config["behaviour_id"] as? String,
            experienceId: experienceId,
            ruleId: config["rule_id"] as? String
        )
        
        Logger.info("📊 SUMMARY: Created summary for experience: \(experienceId), config: \(configId ?? "nil")")
        
        // For now, track it as a generic summary until we fully migrate the queue
        let summaryData = SummaryData(
            name: "config_request_summary",
            count: 1,
            properties: configSummary.toDictionary()
        )
        
        let result = trackSummary(summary: summaryData)
        return result.isSuccess ? CFResult.createSuccess(value: true) : CFResult.createError(message: "Failed to track config summary", category: .state)
    }
    
    /**
     * Returns all tracked summaries for other components
     * 
     * @return Dictionary of experience IDs to tracking status
     */
    public func getTrackedSummaries() -> [String: Bool] {
        trackMapLock.lock()
        defer { trackMapLock.unlock() }
        return summaryTrackMap
    }
    
    /**
     * Clear all tracked summaries (useful for session rotation)
     */
    public func clearTrackedSummaries() {
        trackMapLock.lock()
        defer { trackMapLock.unlock() }
        summaryTrackMap.removeAll()
        Logger.info("📊 SUMMARY: Cleared all tracked summaries")
    }
    
    // MARK: - Private Methods
    
    /// Merge similar summaries to optimize the payload
    /// - Parameter summaries: Summaries to merge
    /// - Returns: Array of merged summaries
    private func mergeSummaries(_ summaries: [SummaryData]) -> [SummaryData] {
        var mergedDict: [String: SummaryData] = [:]
        
        for summary in summaries {
            // Create a key from the name and properties
            let propertiesData = try? JSONSerialization.data(withJSONObject: summary.properties, options: [.sortedKeys])
            let propertiesString = propertiesData != nil ? String(data: propertiesData!, encoding: .utf8) ?? "" : ""
            let key = "\(summary.name):\(propertiesString)"
            
            if let existing = mergedDict[key] {
                // Merge by adding counts
                let merged = SummaryData(
                    name: existing.name,
                    count: existing.count + summary.count,
                    properties: existing.properties
                )
                mergedDict[key] = merged
            } else {
                mergedDict[key] = summary
            }
        }
        
        return Array(mergedDict.values)
    }
    
    /// Send summaries to the server
    /// - Parameter summaries: Summaries to send
    /// - Returns: Result indicating success or failure
    private func sendSummaries(summaries: [SummaryData]) -> CFResult<Bool> {
        do {
            // Build payload
            let summaryRequestData = buildSummaryApiPayload(summaries: summaries)
            
            // Serialize to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: summaryRequestData, options: [])
            
            // Create URL
            let summariesUrl = "\(CFConstants.Api.BASE_API_URL)\(CFConstants.Api.SUMMARIES_PATH)?cfenc=\(config.clientKey)"
            guard let url = URL(string: summariesUrl) else {
                return CFResult.createError(message: "Invalid summaries URL: \(summariesUrl)", category: .validation)
            }
            
            // Create circuit breaker
            let circuitBreaker = CircuitBreaker.getOrCreate(name: "summaries-api")
            
            // Create semaphore for synchronous execution
            let semaphore = DispatchSemaphore(value: 0)
            var resultValue: CFResult<Bool> = CFResult.createError(message: "Unknown error", category: .unknown)
            
            // Use circuit breaker to prevent cascading failures
            do {
                try circuitBreaker.execute(operation: {
                    // Use HttpClient to post the summaries
                    self.httpClient.postJson(url: url, payload: jsonData) { result in
                        // Handle response
                        resultValue = result
                        semaphore.signal()
                    }
                })
            } catch {
                return CFResult.createError(message: "Circuit breaker prevented summary send", error: error, category: .network)
            }
            
            // Wait for response (with timeout)
            if semaphore.wait(timeout: .now() + 30.0) == .timedOut {
                circuitBreaker.recordFailure()
                return CFResult.createError(message: "Timeout waiting for summaries API response", category: .network)
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
            Logger.error("Error serializing summary data: \(error.localizedDescription)")
            ErrorHandler.handleException(
                error: error,
                message: "Error serializing summary data",
                source: SummaryManager.SOURCE,
                severity: .high
            )
            return CFResult.createError(message: "Error serializing summaries", error: error, category: .serialization)
        }
    }
    
    /// Build the summary API payload (Kotlin-compatible format)
    /// - Parameter summaries: Summaries to send
    /// - Returns: Dictionary containing the API payload
    private func buildSummaryApiPayload(summaries: [SummaryData]) -> [String: Any] {
        var payload: [String: Any] = [:]
        
        // Add user data (match Kotlin format)
        var userMap: [String: Any] = [:]
        for (key, value) in user.getUser().toUserMap() {
            userMap[key] = value
        }
        payload["user"] = userMap
        
        // Add summaries - for config summaries, extract the CFConfigRequestSummary data
        var summariesArray: [[String: Any]] = []
        for summary in summaries {
            if summary.name == "config_request_summary" {
                // This is a config summary - extract the CFConfigRequestSummary data from properties
                summariesArray.append(summary.properties)
            } else {
                // This is a generic summary - convert to dictionary
                summariesArray.append(summary.toDictionary())
            }
        }
        payload["summaries"] = summariesArray
        
        // Add SDK version (match Kotlin)
        payload["cf_client_sdk_version"] = "1.1.1"
        
        return payload
    }
    
    /// Get metrics as a dictionary
    /// - Returns: Dictionary of metrics
    public func getMetrics() -> [String: Any] {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        return [
            "totalSummariesTracked": _totalSummariesTracked,
            "totalSummariesFlushed": _totalSummariesFlushed,
            "totalSummariesDropped": _totalSummariesDropped,
            "totalFlushes": _totalFlushes,
            "failedFlushes": _failedFlushes,
            "currentQueueSize": summaryQueue.count,
            "queueCapacity": config.summariesQueueSize
        ]
    }
    
    // MARK: - Periodic Flush Timer Management
    
    /// Timer for periodic flushing using DispatchSourceTimer for CLI compatibility
    private var dispatchTimer: DispatchSourceTimer?
    
    /// Starts the periodic flush timer
    private func startPeriodicFlush() {
        workQueue.async {
            self.timerLock.lock()
            defer { self.timerLock.unlock() }
            
            // Cancel existing timer
            self.dispatchTimer?.cancel()
            self.dispatchTimer = nil
            
            // Get current flush interval
            let interval = TimeInterval(self.summariesFlushIntervalMs) / 1000.0
            
            // Create dispatch timer for better CLI compatibility
            self.dispatchTimer = DispatchSource.makeTimerSource(
                flags: [],
                queue: self.workQueue
            )
            
            // Configure timer
            self.dispatchTimer?.schedule(
                deadline: .now() + interval,
                repeating: interval,
                leeway: .milliseconds(100)
            )
            
            // Set timer event handler
            self.dispatchTimer?.setEventHandler { [weak self] in
                guard let self = self else { return }
                
                // Only trigger flush if there are summaries to flush
                if !self.summaryQueue.isEmpty {
                    Logger.debug("📊 SUMMARY: Periodic flush triggered for summaries")
                    self.flushSummaries()
                } else {
                    Logger.debug("📊 SUMMARY: Periodic flush skipped - no summaries to flush")
                }
            }
            
            // Start the timer
            self.dispatchTimer?.resume()
            
            Logger.debug("📊 SUMMARY: Started periodic summary flush timer")
        }
    }
    
    /// Stops the periodic flush timer
    private func stopPeriodicFlush() {
        timerLock.lock()
        defer { timerLock.unlock() }
        
        dispatchTimer?.cancel()
        dispatchTimer = nil
        
        // Also clean up the old Timer if it exists
        flushTimer?.invalidate()
        flushTimer = nil
        
        Logger.debug("📊 SUMMARY: Stopped periodic summary flush timer")
    }
    
    /// Restarts the periodic flush timer with updated interval
    private func restartPeriodicFlush() {
        stopPeriodicFlush()
        startPeriodicFlush()
        
        Logger.debug("📊 SUMMARY: Restarted periodic summary flush timer")
    }
} 