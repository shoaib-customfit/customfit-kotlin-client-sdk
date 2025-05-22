import Foundation

/// Handles fetching configuration from the CustomFit API with support for offline mode
public class ConfigFetcher {
    
    // MARK: - Constants
    
    private static let SOURCE = "ConfigFetcher"
    
    // MARK: - Properties
    
    private let httpClient: HttpClient
    private let config: CFConfig
    private let user: CFUser
    
    /// Thread-safe offline mode flag
    private let offlineMode = NSLock()
    private var _isOffline = false
    
    /// Mutex for thread-safe fetch operations
    private let fetchMutex = NSLock()
    
    /// Last fetched config map for change detection
    private var lastConfigMap: [String: Any]?
    private let configMapLock = NSLock()
    
    /// Last fetch timestamp
    private var lastFetchTime: Int64 = 0
    
    // MARK: - Initialization
    
    /// Initialize with required dependencies
    /// - Parameters:
    ///   - httpClient: HTTP client for network requests
    ///   - config: SDK configuration
    ///   - user: Current user information
    public init(httpClient: HttpClient, config: CFConfig, user: CFUser) {
        self.httpClient = httpClient
        self.config = config
        self.user = user
    }
    
    // MARK: - Offline Mode
    
    /// Returns whether the client is in offline mode
    public func isOffline() -> Bool {
        offlineMode.lock()
        defer { offlineMode.unlock() }
        return _isOffline
    }
    
    /// Sets the offline mode status
    /// - Parameter offline: true to enable offline mode, false to disable
    public func setOffline(_ offline: Bool) {
        offlineMode.lock()
        defer { offlineMode.unlock() }
        _isOffline = offline
        Logger.info("ConfigFetcher offline mode set to: \(offline)")
    }
    
    // MARK: - Configuration Fetching
    
    /// Fetches configuration from the API with improved error handling
    /// - Parameters:
    ///   - lastModified: Optional last-modified header value for conditional requests
    ///   - etag: Optional ETag header value for conditional requests
    /// - Returns: CFResult containing configuration map or error details
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func fetchConfig(lastModified: String? = nil, etag: String? = nil) async -> CFResult<[String: Any]> {
        // Don't fetch if in offline mode
        if isOffline() {
            Logger.debug("Not fetching config because client is in offline mode")
            return CFResult.createError(
                message: "Client is in offline mode",
                category: .network
            )
        }
        
        // Use circuit breaker pattern to prevent cascading failures
        let circuitBreaker = CircuitBreaker.getOrCreate(name: "config-fetcher")
        
        if circuitBreaker.state == .open {
            Logger.warning("Circuit breaker open, not attempting config fetch")
            return CFResult.createError(
                message: "Circuit breaker open, not attempting config fetch",
                category: .network
            )
        }
        
        // Acquire mutex to ensure only one fetch at a time
        fetchMutex.lock()
        defer { fetchMutex.unlock() }
        
        do {
            // Build the URL
            guard let url = URL(string: "\(CFConstants.Api.BASE_API_URL)\(CFConstants.Api.USER_CONFIGS_PATH)?cfenc=\(config.clientKey)") else {
                return CFResult.createError(
                    message: "Invalid URL configuration",
                    category: .state
                )
            }
            
            // Build payload
            var userMap: [String: Any] = [:]
            for (key, value) in user.toUserMap() {
                userMap[key] = value
            }
            
            let payload: [String: Any] = [
                "user": userMap,
                "include_only_features_flags": true
            ]
            
            Logger.info("📡 API POLL: Fetching config from URL: \(url)")
            
            // Serialize payload to JSON data
            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
                return CFResult.createError(
                    message: "Failed to serialize payload",
                    category: .serialization
                )
            }
            
            Logger.debug("Config fetch payload: \(String(data: jsonData, encoding: .utf8) ?? "")")
            
            // Create headers
            var headers = [String: String]()
            headers[CFConstants.Http.HEADER_CONTENT_TYPE] = CFConstants.Http.CONTENT_TYPE_JSON
            
            // Add conditional request headers if available
            if let lastModified = lastModified {
                headers[CFConstants.Http.HEADER_IF_MODIFIED_SINCE] = lastModified
                Logger.info("📡 API POLL: Using If-Modified-Since: \(lastModified)")
            }
            
            if let etag = etag {
                headers[CFConstants.Http.HEADER_IF_NONE_MATCH] = etag
                Logger.info("📡 API POLL: Using If-None-Match: \(etag)")
            }
            
            // Convert CFResult to Swift's Result for retry operation
            return try await withCheckedThrowingContinuation { continuation in
                httpClient.post(url: url, body: jsonData, headers: headers) { data, response, error in
                    if let error = error {
                        circuitBreaker.recordFailure()
                        continuation.resume(returning: CFResult.createError(
                            message: error.localizedDescription,
                            error: error,
                            category: .network
                        ))
                        return
                    }
                    
                    guard let httpResponse = response else {
                        circuitBreaker.recordFailure()
                        continuation.resume(returning: CFResult.createError(
                            message: "Invalid response",
                            category: .network
                        ))
                        return
                    }
                    
                    // Handle not modified response (304)
                    if httpResponse.statusCode == 304 {
                        Logger.info("API POLL: Config not modified (304 response)")
                        
                        // Return the last config if available
                        self.configMapLock.lock()
                        let lastConfig = self.lastConfigMap
                        self.configMapLock.unlock()
                        
                        if let lastConfig = lastConfig {
                            circuitBreaker.recordSuccess()
                            continuation.resume(returning: CFResult.createSuccess(value: lastConfig))
                        } else {
                            // This should not happen, but handle it gracefully
                            Logger.warning("Received 304 but no cached config available")
                            circuitBreaker.recordFailure()
                            continuation.resume(returning: CFResult.createError(
                                message: "Received 304 but no cached config available",
                                category: .state
                            ))
                        }
                        return
                    }
                    
                    // Handle successful response
                    if httpResponse.statusCode == 200 {
                        guard let data = data else {
                            circuitBreaker.recordFailure()
                            continuation.resume(returning: CFResult.createError(
                                message: "Empty response data",
                                category: .network
                            ))
                            return
                        }
                        
                        Logger.info("API POLL: Successfully fetched config, response size: \(data.count) bytes")
                        
                        // Process the response
                        do {
                            let result = self.processConfigResponse(jsonResponse: data)
                            
                            // Record success or failure in the circuit breaker
                            if result.isSuccess {
                                circuitBreaker.recordSuccess()
                            } else {
                                circuitBreaker.recordFailure()
                            }
                            
                            continuation.resume(returning: result)
                        } catch {
                            circuitBreaker.recordFailure()
                            ErrorHandler.handleException(
                                error: error,
                                message: "Error processing config response",
                                source: ConfigFetcher.SOURCE,
                                severity: .high
                            )
                            continuation.resume(returning: CFResult.createError(
                                message: "Error processing config response: \(error.localizedDescription)",
                                error: error,
                                category: .serialization
                            ))
                        }
                    } else {
                        // Handle error response
                        let message = "Failed to fetch config: \(httpResponse.statusCode)"
                        Logger.warning("API POLL: \(message)")
                        
                        // DEBUG: Print complete error response details for manual debugging
                        Logger.error("❌ API ERROR RESPONSE DETAILS:")
                        Logger.error("❌ Status Code: \(httpResponse.statusCode)")
                        Logger.error("❌ Status Text: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                        Logger.error("❌ Response Headers:")
                        for (key, value) in httpResponse.allHeaderFields {
                            Logger.error("❌   \(key): \(value)")
                        }
                        
                        Logger.error("❌ Response Body:")
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            Logger.error(responseBody)
                        } else {
                            Logger.error("❌ No response body or unable to decode")
                        }
                        Logger.error("❌ END ERROR RESPONSE DETAILS")
                        
                        circuitBreaker.recordFailure()
                        continuation.resume(returning: CFResult.createError(
                            message: message,
                            code: httpResponse.statusCode,
                            category: .network
                        ))
                    }
                }
            }
        } catch {
            ErrorHandler.handleException(
                error: error,
                message: "Error fetching configuration",
                source: ConfigFetcher.SOURCE,
                severity: .high
            )
            
            circuitBreaker.recordFailure()
            
            let category = error is DecodingError ? CFErrorCategory.serialization : .state
            return CFResult.createError(
                message: "Error fetching configuration: \(error.localizedDescription)",
                error: error,
                category: category
            )
        }
    }
    
    /// Process the configuration response
    /// - Parameter jsonResponse: The JSON response data from the API
    /// - Returns: CFResult containing the processed config map or error details
    private func processConfigResponse(jsonResponse: Data) -> CFResult<[String: Any]> {
        let finalConfigMap = NSMutableDictionary()
        
        do {
            // Parse the entire response
            guard let responseJson = try JSONSerialization.jsonObject(with: jsonResponse) as? [String: Any] else {
                let message = "Response is not a JSON object"
                ErrorHandler.handleError(
                    message: message,
                    source: ConfigFetcher.SOURCE,
                    category: .serialization,
                    severity: .high
                )
                return CFResult.createError(
                    message: message,
                    category: .serialization
                )
            }
            
            guard let configsJson = responseJson["configs"] as? [String: Any] else {
                let message = "No 'configs' object found in the response"
                ErrorHandler.handleError(
                    message: message,
                    source: ConfigFetcher.SOURCE,
                    category: .validation,
                    severity: .medium
                )
                return CFResult.createSuccess(value: [:])
            }
            
            // Iterate through each config entry
            for (key, configValue) in configsJson {
                guard let configObject = configValue as? [String: Any] else {
                    ErrorHandler.handleError(
                        message: "Config entry for '\(key)' is not a JSON object",
                        source: ConfigFetcher.SOURCE,
                        category: .serialization,
                        severity: .medium
                    )
                    continue
                }
                
                // Create a mutable copy of the config object
                let flattenedMap = NSMutableDictionary(dictionary: configObject)
                
                // Check for nested experience object
                if let experienceObject = configObject["experience_behaviour_response"] as? [String: Any] {
                    // Remove the nested object itself (it will be merged)
                    flattenedMap.removeObject(forKey: "experience_behaviour_response")
                    
                    // Merge fields from the nested experience object
                    for (expKey, expValue) in experienceObject {
                        flattenedMap[expKey] = expValue
                    }
                }
                
                // Store the flattened map
                finalConfigMap[key] = flattenedMap
            }
            
            // Notify observers of config changes (thread-safe)
            configMapLock.lock()
            if !NSDictionary(dictionary: finalConfigMap).isEqual(to: lastConfigMap ?? [:]) {
                CFConfigChangeManager.shared.notifyObservers(
                    newConfigs: finalConfigMap as! [String: Any],
                    oldConfigs: lastConfigMap
                )
                lastConfigMap = finalConfigMap as! [String: Any]
                lastFetchTime = Int64(Date().timeIntervalSince1970 * 1000)
            }
            configMapLock.unlock()
            
            // Log config details
            Logger.debug("Config keys: \(finalConfigMap.allKeys)")
            
            // Print each config key and its variation value only
            for (key, value) in finalConfigMap {
                if let configMap = value as? [String: Any],
                   let variation = configMap["variation"] {
                    Logger.debug("\(key): \(variation)")
                } else {
                    Logger.debug("\(key): \(value)")
                }
            }
            
            return CFResult.createSuccess(value: finalConfigMap as! [String: Any])
        } catch {
            ErrorHandler.handleException(
                error: error,
                message: "Error parsing configuration response",
                source: ConfigFetcher.SOURCE,
                severity: .high
            )
            
            return CFResult.createError(
                message: "Error parsing configuration response: \(error.localizedDescription)",
                error: error,
                category: .serialization
            )
        }
    }
    
    // MARK: - Metadata Fetching
    
    /// Fetches metadata from a URL with improved error handling
    /// Optimized to use HEAD requests first to minimize bandwidth usage
    /// - Parameter url: The URL to fetch metadata from
    /// - Returns: CFResult containing metadata headers or error details
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func fetchMetadata(url: URL) async -> CFResult<[String: String]> {
        if isOffline() {
            Logger.debug("Not fetching metadata because client is in offline mode")
            return CFResult.createError(
                message: "Client is in offline mode",
                category: .network
            )
        }
        
        do {
            // First try a lightweight HEAD request
            Logger.info("API POLL: Fetch metadata strategy - First trying HEAD request: \(url.absoluteString)")
            
            return try await withCheckedThrowingContinuation { continuation in
                self.httpClient.makeHeadRequest(url: url) { result in
                    switch result {
                    case .success(let value):
                        Logger.info("API POLL: HEAD request successful")
                        continuation.resume(returning: CFResult.createSuccess(value: value))
                    case .error(let message, let error, let code, let category):
                        // If HEAD fails, fall back to the original GET method
                        Logger.info("API POLL: HEAD request failed (\(message)), falling back to GET")
                        
                        self.httpClient.fetchMetadata(url: url) { getResult in
                            switch getResult {
                            case .success(let value):
                                Logger.info("API POLL: Fallback GET successful")
                                continuation.resume(returning: CFResult.createSuccess(value: value))
                            case .error(let getMsg, let getError, let getCode, let getCategory):
                                Logger.warning("API POLL: Both HEAD and GET failed: \(getMsg)")
                                continuation.resume(returning: CFResult.createError(
                                    message: getMsg,
                                    error: getError,
                                    code: getCode,
                                    category: getCategory
                                ))
                            }
                        }
                    }
                }
            }
        } catch {
            Logger.warning("API POLL: Exception during metadata fetch: \(error.localizedDescription)")
            return CFResult.createError(
                message: "Error fetching metadata: \(error.localizedDescription)",
                error: error,
                category: .network
            )
        }
    }
    
    // MARK: - SDK Settings
    
    /// Fetches complete SDK settings from a URL, including both metadata headers and the full settings object
    /// This is preferred over fetchMetadata when you need to process the actual settings content
    /// - Parameter url: The URL to fetch SDK settings from
    /// - Returns: CFResult containing both headers and parsed SdkSettings object, or error details
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func fetchSdkSettingsWithMetadata(url: URL) async -> CFResult<(headers: [String: String], settings: SdkSettings?)> {
        if isOffline() {
            Logger.debug("Not fetching SDK settings because client is in offline mode")
            return CFResult.createError(
                message: "Client is in offline mode",
                category: .network
            )
        }
        
        do {
            // Always use GET for this method since we need the full response body
            Logger.info("API POLL: Fetching full SDK settings with GET: \(url.absoluteString)")
            
            return try await withCheckedThrowingContinuation { continuation in
                self.httpClient.get(url: url) { data, response, error in
                    if let error = error {
                        Logger.error("API POLL: Exception during SDK settings fetch: \(error.localizedDescription)")
                        continuation.resume(returning: CFResult.createError(
                            message: "Error fetching SDK settings: \(error.localizedDescription)",
                            error: error,
                            category: .network
                        ))
                        return
                    }
                    
                    guard let httpResponse = response else {
                        continuation.resume(returning: CFResult.createError(
                            message: "Invalid response",
                            category: .network
                        ))
                        return
                    }
                    
                    if httpResponse.statusCode == 200 {
                        // Extract headers
                        var headers: [String: String] = [:]
                        
                        if let lastModified = httpResponse.allHeaderFields[CFConstants.Http.HEADER_LAST_MODIFIED] as? String {
                            headers[CFConstants.Http.HEADER_LAST_MODIFIED] = lastModified
                        }
                        
                        if let etag = httpResponse.allHeaderFields[CFConstants.Http.HEADER_ETAG] as? String {
                            headers[CFConstants.Http.HEADER_ETAG] = etag
                        }
                        
                        // Read the response body
                        guard let data = data else {
                            continuation.resume(returning: CFResult.createError(
                                message: "Empty response body",
                                category: .network
                            ))
                            return
                        }
                        
                        Logger.info("API POLL: SDK settings response received, size: \(data.count) bytes")
                        
                        // Parse the settings
                        let sdkSettings = self.parseSdkSettings(jsonData: data)
                        
                        if let sdkSettings = sdkSettings {
                            Logger.info("API POLL: SDK settings parsed successfully, account enabled: \(sdkSettings.cf_account_enabled)")
                        } else {
                            Logger.warning("API POLL: Failed to parse SDK settings response")
                        }
                        
                        continuation.resume(returning: CFResult.createSuccess(value: (headers: headers, settings: sdkSettings)))
                    } else {
                        Logger.warning("API POLL: Failed to fetch SDK settings from \(url.absoluteString): \(httpResponse.statusCode)")
                        continuation.resume(returning: CFResult.createError(
                            message: "Failed to fetch SDK settings",
                            code: httpResponse.statusCode,
                            category: .network
                        ))
                    }
                }
            }
        } catch {
            Logger.error("API POLL: Exception during SDK settings fetch: \(error.localizedDescription)")
            ErrorHandler.handleException(
                error: error,
                message: "Error fetching SDK settings from \(url.absoluteString)",
                source: ConfigFetcher.SOURCE,
                severity: .high
            )
            
            return CFResult.createError(
                message: "Error fetching SDK settings: \(error.localizedDescription)",
                error: error,
                category: .network
            )
        }
    }
    
    /// Parse SDK settings JSON into a simplified SdkSettings object
    /// Only extracts the essential fields needed for core functionality
    /// - Parameter jsonData: The JSON data to parse
    /// - Returns: SdkSettings object if successful, nil otherwise
    private func parseSdkSettings(jsonData: Data) -> SdkSettings? {
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }
            
            // Extract only the essential boolean values we need with fallbacks
            let cfAccountEnabled = json["cf_account_enabled"] as? Bool ?? true
            let cfSkipSdk = json["cf_skip_sdk"] as? Bool ?? false
            
            // Log that we're using a simplified version
            Logger.debug("Parsing SDK settings with simplified model (only essential fields)")
            
            // Create and return simplified SdkSettings object with just the fields we need
            return SdkSettings(
                cf_account_enabled: cfAccountEnabled,
                cf_skip_sdk: cfSkipSdk
            )
        } catch {
            Logger.error("Failed to parse SDK settings: \(error.localizedDescription)")
            return nil
        }
    }
} 