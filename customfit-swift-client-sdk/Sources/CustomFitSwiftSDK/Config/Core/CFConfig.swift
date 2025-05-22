import Foundation

/// Configuration for the CustomFit SDK
public class CFConfig {
    /// Client API key
    public let clientKey: String
    
    // Event tracker configuration
    public let eventsQueueSize: Int
    public let eventsFlushTimeSeconds: Int
    public let eventsFlushIntervalMs: Int64
    
    // Retry configuration
    public let maxRetryAttempts: Int
    public let retryInitialDelayMs: Int64
    public let retryMaxDelayMs: Int64
    public let retryBackoffMultiplier: Double
    
    // Summary manager configuration
    public let summariesQueueSize: Int
    public let summariesFlushTimeSeconds: Int
    public let summariesFlushIntervalMs: Int64
    
    // SDK settings check configuration
    public let sdkSettingsCheckIntervalMs: Int64
    
    // Network configuration
    public let networkConnectionTimeoutMs: Int
    public let networkReadTimeoutMs: Int
    
    // Logging configuration
    public let loggingEnabled: Bool
    public let debugLoggingEnabled: Bool
    public let logLevel: String
    
    // Offline mode - when true, no network requests will be made
    public let offlineMode: Bool
    
    // Background operation settings
    public let disableBackgroundPolling: Bool
    public let backgroundPollingIntervalMs: Int64
    public let useReducedPollingWhenBatteryLow: Bool
    public let reducedPollingIntervalMs: Int64
    public let maxStoredEvents: Int
    
    // Auto environment attributes enabled - when true, automatically collect device and app info
    public let autoEnvAttributesEnabled: Bool
    
    /// Dimension ID extracted from the client key
    public var dimensionId: String? {
        return extractDimensionIdFromToken(clientKey)
    }
    
    /// Initialize with all configuration parameters
    /// - Parameters:
    ///   - clientKey: Client API key
    ///   - eventsQueueSize: Events queue size
    ///   - eventsFlushTimeSeconds: Events flush time in seconds
    ///   - eventsFlushIntervalMs: Events flush interval in milliseconds
    ///   - maxRetryAttempts: Maximum retry attempts
    ///   - retryInitialDelayMs: Initial retry delay in milliseconds
    ///   - retryMaxDelayMs: Maximum retry delay in milliseconds
    ///   - retryBackoffMultiplier: Retry backoff multiplier
    ///   - summariesQueueSize: Summaries queue size
    ///   - summariesFlushTimeSeconds: Summaries flush time in seconds
    ///   - summariesFlushIntervalMs: Summaries flush interval in milliseconds
    ///   - sdkSettingsCheckIntervalMs: SDK settings check interval in milliseconds
    ///   - networkConnectionTimeoutMs: Network connection timeout in milliseconds
    ///   - networkReadTimeoutMs: Network read timeout in milliseconds
    ///   - loggingEnabled: Logging enabled
    ///   - debugLoggingEnabled: Debug logging enabled
    ///   - logLevel: Log level
    ///   - offlineMode: Offline mode
    ///   - disableBackgroundPolling: Disable background polling
    ///   - backgroundPollingIntervalMs: Background polling interval in milliseconds
    ///   - useReducedPollingWhenBatteryLow: Use reduced polling when battery is low
    ///   - reducedPollingIntervalMs: Reduced polling interval in milliseconds
    ///   - maxStoredEvents: Maximum stored events
    ///   - autoEnvAttributesEnabled: Auto environment attributes enabled
    public init(
        clientKey: String,
        eventsQueueSize: Int = CFConstants.EventDefaults.QUEUE_SIZE,
        eventsFlushTimeSeconds: Int = CFConstants.EventDefaults.FLUSH_TIME_SECONDS,
        eventsFlushIntervalMs: Int64 = CFConstants.EventDefaults.FLUSH_INTERVAL_MS,
        maxRetryAttempts: Int = CFConstants.RetryConfig.MAX_RETRY_ATTEMPTS,
        retryInitialDelayMs: Int64 = CFConstants.RetryConfig.INITIAL_DELAY_MS,
        retryMaxDelayMs: Int64 = CFConstants.RetryConfig.MAX_DELAY_MS,
        retryBackoffMultiplier: Double = CFConstants.RetryConfig.BACKOFF_MULTIPLIER,
        summariesQueueSize: Int = CFConstants.SummaryDefaults.QUEUE_SIZE,
        summariesFlushTimeSeconds: Int = CFConstants.SummaryDefaults.FLUSH_TIME_SECONDS,
        summariesFlushIntervalMs: Int64 = CFConstants.SummaryDefaults.FLUSH_INTERVAL_MS,
        sdkSettingsCheckIntervalMs: Int64 = CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS,
        networkConnectionTimeoutMs: Int = CFConstants.Network.CONNECTION_TIMEOUT_MS,
        networkReadTimeoutMs: Int = CFConstants.Network.READ_TIMEOUT_MS,
        loggingEnabled: Bool = true,
        debugLoggingEnabled: Bool = false,
        logLevel: String = CFConstants.Logging.DEFAULT_LOG_LEVEL,
        offlineMode: Bool = false,
        disableBackgroundPolling: Bool = false,
        backgroundPollingIntervalMs: Int64 = CFConstants.BackgroundPolling.BACKGROUND_POLLING_INTERVAL_MS,
        useReducedPollingWhenBatteryLow: Bool = true,
        reducedPollingIntervalMs: Int64 = CFConstants.BackgroundPolling.REDUCED_POLLING_INTERVAL_MS,
        maxStoredEvents: Int = CFConstants.EventDefaults.MAX_STORED_EVENTS,
        autoEnvAttributesEnabled: Bool = false
    ) {
        self.clientKey = clientKey
        self.eventsQueueSize = eventsQueueSize
        self.eventsFlushTimeSeconds = eventsFlushTimeSeconds
        self.eventsFlushIntervalMs = eventsFlushIntervalMs
        self.maxRetryAttempts = maxRetryAttempts
        self.retryInitialDelayMs = retryInitialDelayMs
        self.retryMaxDelayMs = retryMaxDelayMs
        self.retryBackoffMultiplier = retryBackoffMultiplier
        self.summariesQueueSize = summariesQueueSize
        self.summariesFlushTimeSeconds = summariesFlushTimeSeconds
        self.summariesFlushIntervalMs = summariesFlushIntervalMs
        self.sdkSettingsCheckIntervalMs = sdkSettingsCheckIntervalMs
        self.networkConnectionTimeoutMs = networkConnectionTimeoutMs
        self.networkReadTimeoutMs = networkReadTimeoutMs
        self.loggingEnabled = loggingEnabled
        self.debugLoggingEnabled = debugLoggingEnabled
        self.logLevel = logLevel
        self.offlineMode = offlineMode
        self.disableBackgroundPolling = disableBackgroundPolling
        self.backgroundPollingIntervalMs = backgroundPollingIntervalMs
        self.useReducedPollingWhenBatteryLow = useReducedPollingWhenBatteryLow
        self.reducedPollingIntervalMs = reducedPollingIntervalMs
        self.maxStoredEvents = maxStoredEvents
        self.autoEnvAttributesEnabled = autoEnvAttributesEnabled
    }
    
    // MARK: - Factory Methods
    
    /// Create a minimal configuration with just a client key
    /// - Parameter clientKey: Client API key
    /// - Returns: A new CFConfig instance
    public static func fromClientKey(_ clientKey: String) -> CFConfig {
        return CFConfig(clientKey: clientKey)
    }
    
    /// Create a configuration with basic settings
    /// - Parameters:
    ///   - clientKey: Client API key
    ///   - eventsQueueSize: Events queue size
    ///   - eventsFlushTimeSeconds: Events flush time in seconds
    ///   - eventsFlushIntervalMs: Events flush interval in milliseconds
    ///   - summariesQueueSize: Summaries queue size
    ///   - summariesFlushTimeSeconds: Summaries flush time in seconds
    ///   - summariesFlushIntervalMs: Summaries flush interval in milliseconds
    /// - Returns: A new CFConfig instance
    public static func fromClientKey(
        _ clientKey: String,
        eventsQueueSize: Int = CFConstants.EventDefaults.QUEUE_SIZE,
        eventsFlushTimeSeconds: Int = CFConstants.EventDefaults.FLUSH_TIME_SECONDS,
        eventsFlushIntervalMs: Int64 = CFConstants.EventDefaults.FLUSH_INTERVAL_MS,
        summariesQueueSize: Int = CFConstants.SummaryDefaults.QUEUE_SIZE,
        summariesFlushTimeSeconds: Int = CFConstants.SummaryDefaults.FLUSH_TIME_SECONDS,
        summariesFlushIntervalMs: Int64 = CFConstants.SummaryDefaults.FLUSH_INTERVAL_MS
    ) -> CFConfig {
        return CFConfig(
            clientKey: clientKey,
            eventsQueueSize: eventsQueueSize,
            eventsFlushTimeSeconds: eventsFlushTimeSeconds,
            eventsFlushIntervalMs: eventsFlushIntervalMs,
            summariesQueueSize: summariesQueueSize,
            summariesFlushTimeSeconds: summariesFlushTimeSeconds,
            summariesFlushIntervalMs: summariesFlushIntervalMs
        )
    }
    
    /// Extract dimension ID from the client key token
    /// - Parameter token: Client key token
    /// - Returns: Extracted dimension ID or nil
    private func extractDimensionIdFromToken(_ token: String) -> String? {
        guard !token.isEmpty else { 
            Logger.debug("JWT: Token is empty")
            return nil 
        }
        
        do {
            // Split the token by periods
            let parts = token.components(separatedBy: ".")
            Logger.debug("JWT: Token parts count: \(parts.count)")
            guard parts.count >= 2 else { 
                Logger.debug("JWT: Token doesn't have enough parts")
                return nil 
            }
            
            // Base64 decode the payload part
            let payload = parts[1]
            Logger.debug("JWT: Payload part: \(payload.prefix(50))...")
            let paddedPayload = padBase64String(payload)
            Logger.debug("JWT: Padded payload: \(paddedPayload.prefix(50))...")
            
            guard let data = Data(base64Encoded: paddedPayload) else { 
                Logger.debug("JWT: Failed to base64 decode payload")
                return nil 
            }
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { 
                Logger.debug("JWT: Failed to parse JSON from payload")
                return nil 
            }
            
            Logger.debug("JWT: Parsed JSON keys: \(jsonObject.keys)")
            let dimensionId = jsonObject["dimension_id"] as? String
            Logger.debug("JWT: Extracted dimension_id: \(dimensionId ?? "nil")")
            return dimensionId
        } catch {
            Logger.debug("JWT: Error extracting dimension ID: \(error)")
            return nil
        }
    }
    
    /// Pad a base64 string to ensure it's a valid length
    /// - Parameter base64: Base64 string to pad
    /// - Returns: Padded base64 string
    private func padBase64String(_ base64: String) -> String {
        var padded = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = padded.count % 4
        if remainder > 0 {
            padded = padded.padding(toLength: padded.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        return padded
    }
    
    // MARK: - Builder
    
    /// Builder for creating a CFConfig instance
    public class Builder {
        private let clientKey: String
        private var eventsQueueSize: Int = CFConstants.EventDefaults.QUEUE_SIZE
        private var eventsFlushTimeSeconds: Int = CFConstants.EventDefaults.FLUSH_TIME_SECONDS
        private var eventsFlushIntervalMs: Int64 = CFConstants.EventDefaults.FLUSH_INTERVAL_MS
        private var maxRetryAttempts: Int = CFConstants.RetryConfig.MAX_RETRY_ATTEMPTS
        private var retryInitialDelayMs: Int64 = CFConstants.RetryConfig.INITIAL_DELAY_MS
        private var retryMaxDelayMs: Int64 = CFConstants.RetryConfig.MAX_DELAY_MS
        private var retryBackoffMultiplier: Double = CFConstants.RetryConfig.BACKOFF_MULTIPLIER
        private var summariesQueueSize: Int = CFConstants.SummaryDefaults.QUEUE_SIZE
        private var summariesFlushTimeSeconds: Int = CFConstants.SummaryDefaults.FLUSH_TIME_SECONDS
        private var summariesFlushIntervalMs: Int64 = CFConstants.SummaryDefaults.FLUSH_INTERVAL_MS
        private var sdkSettingsCheckIntervalMs: Int64 = CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS
        private var networkConnectionTimeoutMs: Int = CFConstants.Network.CONNECTION_TIMEOUT_MS
        private var networkReadTimeoutMs: Int = CFConstants.Network.READ_TIMEOUT_MS
        private var loggingEnabled: Bool = true
        private var debugLoggingEnabled: Bool = false
        private var logLevel: String = CFConstants.Logging.DEFAULT_LOG_LEVEL
        private var offlineMode: Bool = false
        private var disableBackgroundPolling: Bool = false
        private var backgroundPollingIntervalMs: Int64 = CFConstants.BackgroundPolling.BACKGROUND_POLLING_INTERVAL_MS
        private var useReducedPollingWhenBatteryLow: Bool = true
        private var reducedPollingIntervalMs: Int64 = CFConstants.BackgroundPolling.REDUCED_POLLING_INTERVAL_MS
        private var maxStoredEvents: Int = CFConstants.EventDefaults.MAX_STORED_EVENTS
        private var autoEnvAttributesEnabled: Bool = false
        
        /// Initialize a new builder with a client key
        /// - Parameter clientKey: Client API key
        public init(_ clientKey: String) {
            self.clientKey = clientKey
        }
        
        /// Set events queue size
        /// - Parameter size: Events queue size
        /// - Returns: Builder instance
        public func eventsQueueSize(_ size: Int) -> Builder {
            self.eventsQueueSize = size
            return self
        }
        
        /// Set events flush time in seconds
        /// - Parameter seconds: Events flush time in seconds
        /// - Returns: Builder instance
        public func eventsFlushTimeSeconds(_ seconds: Int) -> Builder {
            self.eventsFlushTimeSeconds = seconds
            return self
        }
        
        /// Set events flush interval in milliseconds
        /// - Parameter ms: Events flush interval in milliseconds
        /// - Returns: Builder instance
        public func eventsFlushIntervalMs(_ ms: Int64) -> Builder {
            self.eventsFlushIntervalMs = ms
            return self
        }
        
        /// Set maximum retry attempts
        /// - Parameter attempts: Maximum retry attempts
        /// - Returns: Builder instance
        public func maxRetryAttempts(_ attempts: Int) -> Builder {
            precondition(attempts >= 0, "Max retry attempts must be non-negative")
            self.maxRetryAttempts = attempts
            return self
        }
        
        /// Set initial retry delay in milliseconds
        /// - Parameter ms: Initial retry delay in milliseconds
        /// - Returns: Builder instance
        public func retryInitialDelayMs(_ ms: Int64) -> Builder {
            precondition(ms > 0, "Initial delay must be positive")
            self.retryInitialDelayMs = ms
            return self
        }
        
        /// Set maximum retry delay in milliseconds
        /// - Parameter ms: Maximum retry delay in milliseconds
        /// - Returns: Builder instance
        public func retryMaxDelayMs(_ ms: Int64) -> Builder {
            precondition(ms > 0, "Max delay must be positive")
            self.retryMaxDelayMs = ms
            return self
        }
        
        /// Set retry backoff multiplier
        /// - Parameter multiplier: Retry backoff multiplier
        /// - Returns: Builder instance
        public func retryBackoffMultiplier(_ multiplier: Double) -> Builder {
            precondition(multiplier > 1.0, "Backoff multiplier must be greater than 1.0")
            self.retryBackoffMultiplier = multiplier
            return self
        }
        
        /// Set summaries queue size
        /// - Parameter size: Summaries queue size
        /// - Returns: Builder instance
        public func summariesQueueSize(_ size: Int) -> Builder {
            self.summariesQueueSize = size
            return self
        }
        
        /// Set summaries flush time in seconds
        /// - Parameter seconds: Summaries flush time in seconds
        /// - Returns: Builder instance
        public func summariesFlushTimeSeconds(_ seconds: Int) -> Builder {
            self.summariesFlushTimeSeconds = seconds
            return self
        }
        
        /// Set summaries flush interval in milliseconds
        /// - Parameter ms: Summaries flush interval in milliseconds
        /// - Returns: Builder instance
        public func summariesFlushIntervalMs(_ ms: Int64) -> Builder {
            self.summariesFlushIntervalMs = ms
            return self
        }
        
        /// Set SDK settings check interval in milliseconds
        /// - Parameter ms: SDK settings check interval in milliseconds
        /// - Returns: Builder instance
        public func sdkSettingsCheckIntervalMs(_ ms: Int64) -> Builder {
            self.sdkSettingsCheckIntervalMs = ms
            return self
        }
        
        /// Set network connection timeout in milliseconds
        /// - Parameter ms: Network connection timeout in milliseconds
        /// - Returns: Builder instance
        public func networkConnectionTimeoutMs(_ ms: Int) -> Builder {
            self.networkConnectionTimeoutMs = ms
            return self
        }
        
        /// Set network read timeout in milliseconds
        /// - Parameter ms: Network read timeout in milliseconds
        /// - Returns: Builder instance
        public func networkReadTimeoutMs(_ ms: Int) -> Builder {
            self.networkReadTimeoutMs = ms
            return self
        }
        
        /// Set logging enabled
        /// - Parameter enabled: Logging enabled
        /// - Returns: Builder instance
        public func loggingEnabled(_ enabled: Bool) -> Builder {
            self.loggingEnabled = enabled
            return self
        }
        
        /// Set debug logging enabled
        /// - Parameter enabled: Debug logging enabled
        /// - Returns: Builder instance
        public func debugLoggingEnabled(_ enabled: Bool) -> Builder {
            self.debugLoggingEnabled = enabled
            return self
        }
        
        /// Set log level
        /// - Parameter level: Log level
        /// - Returns: Builder instance
        public func logLevel(_ level: String) -> Builder {
            precondition(CFConstants.Logging.VALID_LOG_LEVELS.contains(level), 
                      "Log level must be one of: \(CFConstants.Logging.VALID_LOG_LEVELS.joined(separator: ", "))")
            self.logLevel = level
            return self
        }
        
        /// Set offline mode
        /// - Parameter offline: Offline mode
        /// - Returns: Builder instance
        public func offlineMode(_ offline: Bool) -> Builder {
            self.offlineMode = offline
            return self
        }
        
        /// Set disable background polling
        /// - Parameter disable: Disable background polling
        /// - Returns: Builder instance
        public func disableBackgroundPolling(_ disable: Bool) -> Builder {
            self.disableBackgroundPolling = disable
            return self
        }
        
        /// Set background polling interval in milliseconds
        /// - Parameter ms: Background polling interval in milliseconds
        /// - Returns: Builder instance
        public func backgroundPollingIntervalMs(_ ms: Int64) -> Builder {
            precondition(ms > 0, "Interval must be greater than 0")
            self.backgroundPollingIntervalMs = ms
            return self
        }
        
        /// Set use reduced polling when battery is low
        /// - Parameter use: Use reduced polling when battery is low
        /// - Returns: Builder instance
        public func useReducedPollingWhenBatteryLow(_ use: Bool) -> Builder {
            self.useReducedPollingWhenBatteryLow = use
            return self
        }
        
        /// Set reduced polling interval in milliseconds
        /// - Parameter ms: Reduced polling interval in milliseconds
        /// - Returns: Builder instance
        public func reducedPollingIntervalMs(_ ms: Int64) -> Builder {
            precondition(ms > 0, "Interval must be greater than 0")
            self.reducedPollingIntervalMs = ms
            return self
        }
        
        /// Set maximum stored events
        /// - Parameter max: Maximum stored events
        /// - Returns: Builder instance
        public func maxStoredEvents(_ max: Int) -> Builder {
            precondition(max > 0, "Max stored events must be greater than 0")
            self.maxStoredEvents = max
            return self
        }
        
        /// Set auto environment attributes enabled
        /// - Parameter enabled: Auto environment attributes enabled
        /// - Returns: Builder instance
        public func autoEnvAttributesEnabled(_ enabled: Bool) -> Builder {
            self.autoEnvAttributesEnabled = enabled
            return self
        }
        
        /// Build a CFConfig instance
        /// - Returns: CFConfig instance
        public func build() -> CFConfig {
            return CFConfig(
                clientKey: clientKey,
                eventsQueueSize: eventsQueueSize,
                eventsFlushTimeSeconds: eventsFlushTimeSeconds,
                eventsFlushIntervalMs: eventsFlushIntervalMs,
                maxRetryAttempts: maxRetryAttempts,
                retryInitialDelayMs: retryInitialDelayMs,
                retryMaxDelayMs: retryMaxDelayMs,
                retryBackoffMultiplier: retryBackoffMultiplier,
                summariesQueueSize: summariesQueueSize,
                summariesFlushTimeSeconds: summariesFlushTimeSeconds,
                summariesFlushIntervalMs: summariesFlushIntervalMs,
                sdkSettingsCheckIntervalMs: sdkSettingsCheckIntervalMs,
                networkConnectionTimeoutMs: networkConnectionTimeoutMs,
                networkReadTimeoutMs: networkReadTimeoutMs,
                loggingEnabled: loggingEnabled,
                debugLoggingEnabled: debugLoggingEnabled,
                logLevel: logLevel,
                offlineMode: offlineMode,
                disableBackgroundPolling: disableBackgroundPolling,
                backgroundPollingIntervalMs: backgroundPollingIntervalMs,
                useReducedPollingWhenBatteryLow: useReducedPollingWhenBatteryLow,
                reducedPollingIntervalMs: reducedPollingIntervalMs,
                maxStoredEvents: maxStoredEvents,
                autoEnvAttributesEnabled: autoEnvAttributesEnabled
            )
        }
    }
}

/// Log levels for the SDK
public enum LogLevel: Int, Codable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case none = 5
} 