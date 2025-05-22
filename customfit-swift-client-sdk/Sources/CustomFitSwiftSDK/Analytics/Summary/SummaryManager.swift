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
    
    /// Lock for thread-safe operations
    private let lock = NSLock()
    
    /// Last flush time
    private var lastFlushTime: Date = Date()
    
    /// Work queue for background operations
    private let workQueue: DispatchQueue
    
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
        self.summaryQueue = ThreadSafeQueue<SummaryData>(capacity: config.summaryQueueSize)
        
        // Create background queue
        self.workQueue = DispatchQueue(label: "ai.customfit.SummaryManager", qos: .utility)
        
        Logger.info("📊 SUMMARY: SummaryManager initialized with summaryQueueSize=\(config.summaryQueueSize)")
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
            return CFResult.error(message: message, category: .validation)
        }
        
        // Check if queue is full
        if summaryQueue.isFull {
            let message = "Summary queue is full (capacity = \(config.summaryQueueSize)), dropping oldest summary"
            Logger.warning("📊 SUMMARY: \(message)")
            ErrorHandler.handleError(
                message: message,
                source: SummaryManager.SOURCE,
                category: .internal,
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
                    category: .internal,
                    severity: .high
                )
                
                // Update metrics
                metricsLock.lock()
                _totalSummariesDropped += 1
                metricsLock.unlock()
                
                return CFResult.error(message: message, category: .internal)
            }
        }
        
        // Update metrics
        metricsLock.lock()
        _totalSummariesTracked += 1
        metricsLock.unlock()
        
        Logger.info("📊 SUMMARY: Tracked summary: \(summary.name), queue size=\(summaryQueue.count)")
        
        // If queue is full or near capacity, trigger flush
        if summaryQueue.count > Int(Double(config.summaryQueueSize) * 0.7) {
            workQueue.async {
                self.flushSummaries()
            }
        }
        
        return CFResult.success(value: summary)
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
    
    /// Flush summaries to the server
    /// - Returns: Result containing the number of summaries flushed or error details
    @discardableResult
    public func flushSummaries() -> CFResult<Int> {
        lock.lock()
        defer { lock.unlock() }
        
        // Check if queue is empty
        if summaryQueue.isEmpty {
            Logger.debug("📊 SUMMARY: No summaries to flush")
            return CFResult.success(value: 0)
        }
        
        // Update last flush time
        lastFlushTime = Date()
        
        // Drain the queue
        var summariesToFlush = [SummaryData]()
        summaryQueue.drainTo(&summariesToFlush)
        
        if summariesToFlush.isEmpty {
            Logger.debug("📊 SUMMARY: No summaries to flush after drain")
            return CFResult.success(value: 0)
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
            return CFResult.success(value: summariesToFlush.count)
            
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
                return CFResult.error(message: "Failed to flush summaries: \(message)", error: error, category: category)
            } else {
                return CFResult.error(message: "Failed to flush summaries: \(message)", category: category)
            }
        }
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
            let summariesUrl = "\(config.apiBaseUrl)\(CFConstants.Api.SUMMARIES_PATH)?cfenc=\(config.clientKey)"
            guard let url = URL(string: summariesUrl) else {
                return CFResult.error(message: "Invalid summaries URL: \(summariesUrl)", category: .validation)
            }
            
            // Create circuit breaker
            let circuitBreaker = CircuitBreaker.getOrCreate(name: "summaries-api")
            
            // Create semaphore for synchronous execution
            let semaphore = DispatchSemaphore(value: 0)
            var resultValue: CFResult<Bool> = CFResult.error(message: "Unknown error", category: .unknown)
            
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
                return CFResult.error(message: "Circuit breaker prevented summary send", error: error, category: .network)
            }
            
            // Wait for response (with timeout)
            if semaphore.wait(timeout: .now() + 30.0) == .timedOut {
                circuitBreaker.recordFailure()
                return CFResult.error(message: "Timeout waiting for summaries API response", category: .network)
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
            return CFResult.error(message: "Error serializing summaries", error: error, category: .serialization)
        }
    }
    
    /// Build the summary API payload
    /// - Parameter summaries: Summaries to send
    /// - Returns: Dictionary containing the API payload
    private func buildSummaryApiPayload(summaries: [SummaryData]) -> [String: Any] {
        var payload: [String: Any] = [:]
        
        // Add user data
        payload["user"] = user.getUser().toDictionary()
        
        // Add summaries
        var summariesArray: [[String: Any]] = []
        for summary in summaries {
            summariesArray.append(summary.toDictionary())
        }
        payload["summaries"] = summariesArray
        
        // Add SDK version
        payload["cf_client_sdk_version"] = "1.0.0"
        
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
            "queueCapacity": config.summaryQueueSize
        ]
    }
} 