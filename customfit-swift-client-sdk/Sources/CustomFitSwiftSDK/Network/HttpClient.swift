import Foundation

/// HTTP client implementation with robust error handling
public class HttpClient {
    
    // MARK: - Properties
    
    private var session: URLSession
    private let config: CFConfig
    
    /// Default source identification for error handling
    private static let SOURCE = "HttpClient"
    
    /// Connection timeout in milliseconds (mutable via atomic operations)
    private var connectionTimeoutMs: Int {
        willSet {
            connectionTimeoutQueue.sync {
                connectionTimeoutMsValue = newValue
            }
        }
    }
    
    /// Read timeout in milliseconds (mutable via atomic operations)
    private var readTimeoutMs: Int {
        willSet {
            readTimeoutQueue.sync {
                readTimeoutMsValue = newValue
            }
        }
    }
    
    /// Private backing fields for atomic updates
    private var connectionTimeoutMsValue: Int
    private var readTimeoutMsValue: Int
    
    /// Synchronization queues for atomic-like updates
    private let connectionTimeoutQueue = DispatchQueue(label: "ai.customfit.connectionTimeout")
    private let readTimeoutQueue = DispatchQueue(label: "ai.customfit.readTimeout")
    
    /// Performance metrics
    private let performanceMetrics = NSMutableDictionary()
    private let metricsLock = NSLock()
    
    // MARK: - Initialization
    
    public init(config: CFConfig) {
        self.config = config
        
        // Initialize timeout values
        self.connectionTimeoutMsValue = config.networkConnectionTimeoutMs
        self.readTimeoutMsValue = config.networkReadTimeoutMs
        self.connectionTimeoutMs = config.networkConnectionTimeoutMs
        self.readTimeoutMs = config.networkReadTimeoutMs
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(config.networkReadTimeoutMs) / 1000.0
        configuration.timeoutIntervalForResource = TimeInterval(config.networkConnectionTimeoutMs) / 1000.0
        
        // Set additional properties
        configuration.httpAdditionalHeaders = ["User-Agent": "CustomFit-SDK/1.0 Swift"]
        
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Timeout Management
    
    /// Updates the connection timeout setting
    /// - Parameter timeout: new timeout in milliseconds
    public func updateConnectionTimeout(timeout: Int) {
        guard timeout > 0 else {
            Logger.error("Timeout must be greater than 0")
            return
        }
        
        connectionTimeoutMs = timeout
        recreateSession()
        Logger.debug("Updated connection timeout to \(timeout) ms")
    }
    
    /// Updates the read timeout setting
    /// - Parameter timeout: new timeout in milliseconds
    public func updateReadTimeout(timeout: Int) {
        guard timeout > 0 else {
            Logger.error("Timeout must be greater than 0")
            return
        }
        
        readTimeoutMs = timeout
        recreateSession()
        Logger.debug("Updated read timeout to \(timeout) ms")
    }
    
    /// Recreates the URLSession with updated timeout values
    private func recreateSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(readTimeoutMs) / 1000.0
        configuration.timeoutIntervalForResource = TimeInterval(connectionTimeoutMs) / 1000.0
        
        // Additional configuration options
        configuration.httpAdditionalHeaders = ["User-Agent": "CustomFit-SDK/1.0 Swift"]
        
        let newSession = URLSession(configuration: configuration)
        self.session = newSession
    }
    
    // MARK: - Performance Metrics
    
    /// Records performance metrics for a request
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - duration: Request duration in milliseconds
    ///   - success: Whether the request was successful
    private func recordMetrics(endpoint: String, duration: Int64, success: Bool) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        // Create endpoint metrics if not exists
        let key = "metrics.\(endpoint)"
        var metrics = performanceMetrics[key] as? [String: Any] ?? [:]
        
        // Update metrics
        let requestCount = (metrics["count"] as? Int ?? 0) + 1
        let successCount = (metrics["successCount"] as? Int ?? 0) + (success ? 1 : 0)
        let failureCount = (metrics["failureCount"] as? Int ?? 0) + (success ? 0 : 1)
        
        // Calculate average duration
        let totalDuration = (metrics["totalDuration"] as? Int64 ?? 0) + duration
        let avgDuration = totalDuration / Int64(requestCount)
        
        // Update min and max durations
        var minDuration = metrics["minDuration"] as? Int64 ?? Int64.max
        var maxDuration = metrics["maxDuration"] as? Int64 ?? 0
        
        if duration < minDuration {
            minDuration = duration
        }
        
        if duration > maxDuration {
            maxDuration = duration
        }
        
        // Store updated metrics
        metrics["count"] = requestCount
        metrics["successCount"] = successCount
        metrics["failureCount"] = failureCount
        metrics["totalDuration"] = totalDuration
        metrics["avgDuration"] = avgDuration
        metrics["minDuration"] = minDuration
        metrics["maxDuration"] = maxDuration
        metrics["lastRequestTime"] = Date().timeIntervalSince1970 * 1000
        
        performanceMetrics[key] = metrics
        
        // Log periodically (every 10 requests)
        if requestCount % 10 == 0 {
            Logger.info("📊 API METRICS: \(endpoint) - Requests: \(requestCount), Success: \(successCount), Failures: \(failureCount), Avg: \(avgDuration)ms")
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetch JSON data from a URL with error handling
    /// - Parameters:
    ///   - url: URL to fetch JSON from
    ///   - completion: Completion handler called with CFResult
    public func fetchJson(url: URL, completion: @escaping (CFResult<[String: Any]>) -> Void) {
        Logger.debug("API CALL: GET request to \(url.absoluteString)")
        
        // Extract endpoint from URL for metrics
        let endpoint = url.lastPathComponent
        let startTime = Date().timeIntervalSince1970 * 1000
        
        // Use circuit breaker pattern
        let circuitBreaker = CircuitBreaker.getOrCreate(name: "fetch-json-\(endpoint)")
        
        if circuitBreaker.state == .open {
            Logger.warning("Circuit breaker open, not attempting fetch JSON")
            completion(CFResult<[String: Any]>.createError(message: "Circuit breaker open", category: .network))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addHeaders(to: &request, headers: nil)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Calculate request duration
            let endTime = Date().timeIntervalSince1970 * 1000
            let duration = Int64(endTime - startTime)
            
            if let error = error {
                Logger.error("API ERROR: \(error.localizedDescription)")
                ErrorHandler.handleError(
                    message: "Error making GET request to \(url.absoluteString): \(error.localizedDescription)",
                    source: HttpClient.SOURCE,
                    category: .network,
                    severity: .high
                )
                
                circuitBreaker.recordFailure()
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<[String: Any]>.createError(message: "Network error fetching JSON", error: error, category: .network))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("API ERROR: Invalid response")
                
                circuitBreaker.recordFailure()
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<[String: Any]>.createError(message: "Invalid response", category: .network))
                return
            }
            
            if httpResponse.statusCode == 200 {
                guard let data = data else {
                    Logger.error("API ERROR: Empty response data")
                    
                    circuitBreaker.recordFailure()
                    self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                    
                    completion(CFResult<[String: Any]>.createError(message: "Empty response data", category: .serialization))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        Logger.debug("GET JSON SUCCESSFUL")
                        
                        circuitBreaker.recordSuccess()
                        self.recordMetrics(endpoint: endpoint, duration: duration, success: true)
                        
                        completion(CFResult.createSuccess(value: json))
                    } else {
                        let message = "Parsed JSON from \(url.absoluteString) is not an object"
                        Logger.warning("GET JSON FAILED: \(message)")
                        ErrorHandler.handleError(
                            message: message,
                            source: HttpClient.SOURCE,
                            category: .serialization
                        )
                        
                        circuitBreaker.recordFailure()
                        self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                        
                        completion(CFResult<[String: Any]>.createError(message: message, category: .serialization))
                    }
                } catch {
                    Logger.error("GET JSON FAILED: \(error.localizedDescription)")
                    ErrorHandler.handleException(
                        error: error,
                        message: "Error parsing JSON response from \(url.absoluteString)",
                        source: HttpClient.SOURCE,
                        severity: .high
                    )
                    
                    circuitBreaker.recordFailure()
                    self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                    
                    completion(CFResult<[String: Any]>.createError(message: "Error parsing JSON response", error: error, category: .serialization))
                }
            } else {
                let message = "Failed to fetch JSON from \(url.absoluteString): \(httpResponse.statusCode)"
                Logger.warning("GET JSON FAILED: \(message)")
                ErrorHandler.handleError(
                    message: message,
                    source: HttpClient.SOURCE,
                    category: .network
                )
                
                circuitBreaker.recordFailure()
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<[String: Any]>.createError(message: message, code: httpResponse.statusCode, category: .network))
            }
        }
        
        task.resume()
    }
    
    /// Post JSON data to a URL with error handling and circuit breaker
    /// - Parameters:
    ///   - url: URL to post JSON to
    ///   - payload: JSON payload as Data
    ///   - completion: Completion handler called with CFResult
    public func postJson(url: URL, payload: Data, completion: @escaping (CFResult<Bool>) -> Void) {
        Logger.debug("API CALL: POST request to \(url.absoluteString)")
        
        // Extract endpoint from URL for metrics
        let endpoint = url.lastPathComponent
        let startTime = Date().timeIntervalSince1970 * 1000
        
        // Use circuit breaker pattern
        let circuitBreaker = CircuitBreaker.getOrCreate(name: "post-json-\(endpoint)")
        
        if circuitBreaker.state == .open {
            Logger.warning("Circuit breaker open, not attempting POST JSON")
            completion(CFResult<Bool>.createError(message: "Circuit breaker open", category: .network))
            return
        }
        
        // Log the request details based on endpoint type
        if url.absoluteString.contains("summary") {
            Logger.info("📊 SUMMARY HTTP: POST request")
        } else if url.absoluteString.contains("cfe") {
            Logger.info("🔔 🔔 TRACK HTTP: POST request to event API")
            Logger.info("🔔 🔔 TRACK HTTP: Request body size: \(payload.count) bytes")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        
        var headers = [String: String]()
        headers[CFConstants.Http.HEADER_CONTENT_TYPE] = CFConstants.Http.CONTENT_TYPE_JSON
        
        addHeaders(to: &request, headers: headers)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Calculate request duration
            let endTime = Date().timeIntervalSince1970 * 1000
            let duration = Int64(endTime - startTime)
            
            if let error = error {
                // Log the error details based on endpoint type
                if url.absoluteString.contains("summary") {
                    Logger.error("📊 SUMMARY HTTP: Exception: \(error.localizedDescription)")
                } else if url.absoluteString.contains("cfe") {
                    Logger.error("🔔 TRACK HTTP: Exception: \(error.localizedDescription)")
                }
                
                Logger.error("POST JSON FAILED: \(error.localizedDescription)")
                ErrorHandler.handleException(
                    error: error,
                    message: "Failed to post JSON to \(url.absoluteString)",
                    source: HttpClient.SOURCE,
                    severity: .high
                )
                
                circuitBreaker.recordFailure()
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<Bool>.createError(message: "Network error posting JSON", error: error, category: .network))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("API ERROR: Invalid response")
                
                circuitBreaker.recordFailure()
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<Bool>.createError(message: "Invalid response", category: .network))
                return
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 202 {
                // Log the response details based on endpoint type
                if url.absoluteString.contains("summary") {
                    Logger.info("📊 SUMMARY HTTP: Response code: \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                } else if url.absoluteString.contains("cfe") {
                    Logger.info("🔔 🔔 TRACK HTTP: Response code: \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                    Logger.info("🔔 🔔 TRACK HTTP: Events successfully sent to server")
                }
                
                Logger.debug("POST JSON SUCCESSFUL")
                
                circuitBreaker.recordSuccess()
                self.recordMetrics(endpoint: endpoint, duration: duration, success: true)
                
                completion(CFResult<Bool>.createSuccess(value: true))
            } else {
                let errorMessage = data != nil ? String(data: data!, encoding: .utf8) ?? "No error body" : "No error body"
                
                // Log the error details based on endpoint type
                if url.absoluteString.contains("summary") {
                    Logger.warning("📊 SUMMARY HTTP: Error code: \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                    Logger.warning("📊 SUMMARY HTTP: Error body: \(errorMessage)")
                } else if url.absoluteString.contains("cfe") {
                    Logger.warning("🔔 TRACK HTTP: Error code: \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                    Logger.warning("🔔 TRACK HTTP: Error body: \(errorMessage)")
                }
                
                let message = "API error response: \(httpResponse.statusCode)"
                Logger.warning("POST JSON FAILED: \(message) - \(errorMessage)")
                ErrorHandler.handleError(
                    message: "\(message) - \(errorMessage)",
                    source: HttpClient.SOURCE,
                    category: .network,
                    severity: .high
                )
                
                Logger.error("Error: \(errorMessage)")
                
                circuitBreaker.recordFailure()
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<Bool>.createError(message: message, code: httpResponse.statusCode, category: .network))
            }
        }
        
        task.resume()
    }
    
    /// Fetches metadata from a URL with improved error handling
    /// - Parameters:
    ///   - url: URL to fetch metadata from
    ///   - completion: Completion handler called with CFResult
    public func fetchMetadata(url: URL, completion: @escaping (CFResult<[String: String]>) -> Void) {
        Logger.debug("API CALL: GET metadata request to \(url.absoluteString)")
        
        // Extract endpoint from URL for metrics
        let endpoint = "metadata-\(url.lastPathComponent)"
        let startTime = Date().timeIntervalSince1970 * 1000
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addHeaders(to: &request, headers: nil)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Calculate request duration
            let endTime = Date().timeIntervalSince1970 * 1000
            let duration = Int64(endTime - startTime)
            
            if let error = error {
                Logger.error("API ERROR: \(error.localizedDescription)")
                ErrorHandler.handleError(
                    message: "Error making GET metadata request to \(url.absoluteString)",
                    source: HttpClient.SOURCE,
                    category: .network
                )
                
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<[String: String]>.createError(message: "Network error fetching metadata", error: error, category: .network))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("API ERROR: Invalid response")
                
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<[String: String]>.createError(message: "Invalid response", category: .network))
                return
            }
            
            if httpResponse.statusCode == 200 {
                var metadata: [String: String] = [:]
                
                if let lastModified = httpResponse.allHeaderFields[CFConstants.Http.HEADER_LAST_MODIFIED] as? String {
                    metadata[CFConstants.Http.HEADER_LAST_MODIFIED] = lastModified
                }
                
                if let etag = httpResponse.allHeaderFields[CFConstants.Http.HEADER_ETAG] as? String {
                    metadata[CFConstants.Http.HEADER_ETAG] = etag
                }
                
                Logger.debug("GET METADATA SUCCESSFUL: \(metadata)")
                
                self.recordMetrics(endpoint: endpoint, duration: duration, success: true)
                
                completion(CFResult<[String: String]>.createSuccess(value: metadata))
            } else {
                let message = "Failed to fetch metadata from \(url.absoluteString): \(httpResponse.statusCode)"
                Logger.warning("GET METADATA FAILED: \(message)")
                ErrorHandler.handleError(
                    message: message,
                    source: HttpClient.SOURCE,
                    category: .network
                )
                
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<[String: String]>.createError(message: message, code: httpResponse.statusCode, category: .network))
            }
        }
        
        task.resume()
    }
    
    /// Makes a HEAD request to check for metadata changes
    /// - Parameters:
    ///   - url: URL to make HEAD request to
    ///   - completion: Completion handler called with CFResult
    public func makeHeadRequest(url: URL, completion: @escaping (CFResult<[String: String]>) -> Void) {
        Logger.info("API POLL: HEAD request to \(url.absoluteString)")
        
        // Extract endpoint from URL for metrics
        let endpoint = "head-\(url.lastPathComponent)"
        let startTime = Date().timeIntervalSince1970 * 1000
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        addHeaders(to: &request, headers: nil)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Calculate request duration
            let endTime = Date().timeIntervalSince1970 * 1000
            let duration = Int64(endTime - startTime)
            
            if let error = error {
                Logger.error("API POLL: HEAD request exception: \(error.localizedDescription)")
                
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<[String: String]>.createError(
                    message: "HEAD request failed with exception: \(error.localizedDescription)",
                    error: error,
                    category: .network
                ))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("API ERROR: Invalid response")
                
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<[String: String]>.createError(message: "Invalid response", category: .network))
                return
            }
            
            if httpResponse.statusCode == 200 {
                var headers: [String: String] = [:]
                
                // Get Last-Modified header which is crucial for caching
                if let lastModified = httpResponse.allHeaderFields[CFConstants.Http.HEADER_LAST_MODIFIED] as? String {
                    headers[CFConstants.Http.HEADER_LAST_MODIFIED] = lastModified
                }
                
                // Get ETag header for additional caching support
                if let etag = httpResponse.allHeaderFields[CFConstants.Http.HEADER_ETAG] as? String {
                    headers[CFConstants.Http.HEADER_ETAG] = etag
                }
                
                Logger.info("API POLL: HEAD request successful - Last-Modified: \(headers[CFConstants.Http.HEADER_LAST_MODIFIED] ?? "none"), ETag: \(headers[CFConstants.Http.HEADER_ETAG] ?? "none")")
                
                self.recordMetrics(endpoint: endpoint, duration: duration, success: true)
                
                completion(CFResult<[String: String]>.createSuccess(value: headers))
            } else {
                Logger.warning("API POLL: HEAD request failed with code: \(httpResponse.statusCode)")
                
                self.recordMetrics(endpoint: endpoint, duration: duration, success: false)
                
                completion(CFResult<[String: String]>.createError(
                    message: "HEAD request failed with code: \(httpResponse.statusCode)",
                    code: httpResponse.statusCode,
                    category: .network
                ))
            }
        }
        
        task.resume()
    }
    
    /// Integration with RetryUtil for robust HTTP operations
    /// - Parameters:
    ///   - url: URL to make request to
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - body: Optional request body
    ///   - headers: Optional headers
    ///   - completion: Completion handler with result
    public func performRequestWithRetry(
        url: URL,
        method: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        // Try synchronously to simplify code
        do {
            // Execute with retry
            let result = try RetryUtil.withRetry(
                maxAttempts: 3,
                delay: 200,
                maxDelay: 5000,
                factor: 2.0,
                jitter: 0.2,
                operation: {
                    // Create semaphore for synchronous operation
                    let semaphore = DispatchSemaphore(value: 0)
                    var resultData: Data?
                    var resultResponse: HTTPURLResponse?
                    var resultError: Error?
                    
                    // Perform actual request
                    self.performRequest(url: url, method: method, body: body, headers: headers) { data, response, error in
                        resultData = data
                        resultResponse = response
                        resultError = error
                        semaphore.signal()
                    }
                    
                    // Wait for completion
                    _ = semaphore.wait(timeout: .distantFuture)
                    return (resultData, resultResponse, resultError)
                }
            )
            
            // Return the result
            completion(result.0, result.1, result.2)
        } catch {
            // All retry attempts failed
            completion(nil, nil, error)
        }
    }
    
    /// Post JSON with advanced processing for nested experience_behaviour_response
    /// - Parameters:
    ///   - url: The URL to post to
    ///   - body: The JSON body
    ///   - completion: Completion handler with CFResult
    public func postJSON(url: URL, body: Data, completion: @escaping (CFResult<[String: Any]>) -> Void) {
        performRequestWithRetry(url: url, method: "POST", body: body, headers: [CFConstants.Http.HEADER_CONTENT_TYPE: CFConstants.Http.CONTENT_TYPE_JSON]) { data, response, error in
            if let error = error {
                completion(CFResult<[String: Any]>.createError(message: "Network error", error: error, category: .network))
                return
            }
            
            guard let httpResponse = response else {
                completion(CFResult<[String: Any]>.createError(message: "Invalid response", category: .network))
                return
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 202 {
                guard let data = data else {
                    completion(CFResult<[String: Any]>.createError(message: "Empty response data", category: .network))
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(CFResult<[String: Any]>.createError(message: "Invalid JSON response", category: .serialization))
                        return
                    }
                    
                    // Process nested response structure
                    var processedJson = json
                    
                    // Handle nested experience_behaviour_response if present
                    if let configs = json["configs"] as? [String: Any] {
                        var processedConfigs = [String: Any]()
                        
                        for (key, value) in configs {
                            if let configObj = value as? [String: Any] {
                                var flattenedConfig = configObj
                                
                                if let experienceObj = configObj["experience_behaviour_response"] as? [String: Any] {
                                    // Remove nested object and merge its fields
                                    flattenedConfig.removeValue(forKey: "experience_behaviour_response")
                                    
                                    for (expKey, expValue) in experienceObj {
                                        flattenedConfig[expKey] = expValue
                                    }
                                }
                                
                                processedConfigs[key] = flattenedConfig
                            } else {
                                processedConfigs[key] = value
                            }
                        }
                        
                        processedJson["configs"] = processedConfigs
                    }
                    
                    completion(CFResult<[String: Any]>.createSuccess(value: processedJson))
                } catch {
                    completion(CFResult<[String: Any]>.createError(message: "Error parsing JSON response", error: error, category: .serialization))
                }
            } else {
                let errorMessage = data != nil ? String(data: data!, encoding: .utf8) ?? "No error body" : "No error body"
                completion(CFResult<[String: Any]>.createError(message: "API error: \(httpResponse.statusCode) - \(errorMessage)", code: httpResponse.statusCode, category: .network))
            }
        }
    }
    
    /// Perform a GET request
    /// - Parameters:
    ///   - url: URL to make GET request to
    ///   - headers: Optional headers to include
    ///   - completion: Completion handler with raw response data
    public func get(
        url: URL,
        headers: [String: String]? = nil,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        performRequest(url: url, method: "GET", body: nil, headers: headers, completion: completion)
    }
    
    /// Perform a POST request
    /// - Parameters:
    ///   - url: URL to make POST request to
    ///   - body: Request body data
    ///   - headers: Optional headers to include
    ///   - completion: Completion handler with raw response data
    public func post(
        url: URL,
        body: Data,
        headers: [String: String]? = nil,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        performRequest(url: url, method: "POST", body: body, headers: headers, completion: completion)
    }
    
    /// Base method to perform HTTP requests
    /// - Parameters:
    ///   - url: URL to make request to
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - body: Optional request body
    ///   - headers: Optional headers
    ///   - completion: Completion handler with result
    private func performRequest(
        url: URL,
        method: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        Logger.debug("API CALL: \(method) request to \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let body = body {
            request.httpBody = body
        }
        
        addHeaders(to: &request, headers: headers)
        
        let task = session.dataTask(with: request) { data, response, error in
            completion(data, response as? HTTPURLResponse, error)
        }
        
        task.resume()
    }
    
    // MARK: - Private Methods
    
    private func addHeaders(to request: inout URLRequest, headers: [String: String]?) {
        // Add API key header
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        
        // Add content type if not present
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // Add User-Agent
        request.setValue("CustomFit-SDK/1.0 Swift", forHTTPHeaderField: "User-Agent")
        
        // Add custom headers
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
    }
} 