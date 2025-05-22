import Foundation

/// Mutable configuration wrapper that allows for dynamic updates to configuration values at runtime
public class MutableCFConfig {
    // Synchronization lock
    private let lock = NSLock()
    
    // Internal config instance
    private var _config: CFConfig
    
    /// Get the current immutable configuration
    public var config: CFConfig {
        lock.lock()
        defer { lock.unlock() }
        return _config
    }
    
    /// Listeners that will be notified when config values change
    private var configChangeListeners = [ConfigChangeListener]()
    
    // Delegate properties for common access
    
    /// Client API key
    public var clientKey: String {
        return config.clientKey
    }
    
    /// Dimension ID extracted from the client key
    public var dimensionId: String? {
        return config.dimensionId
    }
    
    /// Events queue size
    public var eventsQueueSize: Int {
        return config.eventsQueueSize
    }
    
    /// Events flush time in seconds
    public var eventsFlushTimeSeconds: Int {
        return config.eventsFlushTimeSeconds
    }
    
    /// Events flush interval in milliseconds
    public var eventsFlushIntervalMs: Int64 {
        return config.eventsFlushIntervalMs
    }
    
    /// Maximum retry attempts
    public var maxRetryAttempts: Int {
        return config.maxRetryAttempts
    }
    
    /// Initial retry delay in milliseconds
    public var retryInitialDelayMs: Int64 {
        return config.retryInitialDelayMs
    }
    
    /// Maximum retry delay in milliseconds
    public var retryMaxDelayMs: Int64 {
        return config.retryMaxDelayMs
    }
    
    /// Retry backoff multiplier
    public var retryBackoffMultiplier: Double {
        return config.retryBackoffMultiplier
    }
    
    /// Summaries queue size
    public var summariesQueueSize: Int {
        return config.summariesQueueSize
    }
    
    /// Summaries flush time in seconds
    public var summariesFlushTimeSeconds: Int {
        return config.summariesFlushTimeSeconds
    }
    
    /// Summaries flush interval in milliseconds
    public var summariesFlushIntervalMs: Int64 {
        return config.summariesFlushIntervalMs
    }
    
    /// SDK settings check interval in milliseconds
    public var sdkSettingsCheckIntervalMs: Int64 {
        return config.sdkSettingsCheckIntervalMs
    }
    
    /// Network connection timeout in milliseconds
    public var networkConnectionTimeoutMs: Int {
        return config.networkConnectionTimeoutMs
    }
    
    /// Network read timeout in milliseconds
    public var networkReadTimeoutMs: Int {
        return config.networkReadTimeoutMs
    }
    
    /// Logging enabled
    public var loggingEnabled: Bool {
        return config.loggingEnabled
    }
    
    /// Debug logging enabled
    public var debugLoggingEnabled: Bool {
        return config.debugLoggingEnabled
    }
    
    /// Log level
    public var logLevel: String {
        return config.logLevel
    }
    
    /// Offline mode - when true, no network requests will be made
    public var offlineMode: Bool {
        return config.offlineMode
    }
    
    /// Disable background polling
    public var disableBackgroundPolling: Bool {
        return config.disableBackgroundPolling
    }
    
    /// Background polling interval in milliseconds
    public var backgroundPollingIntervalMs: Int64 {
        return config.backgroundPollingIntervalMs
    }
    
    /// Use reduced polling when battery is low
    public var useReducedPollingWhenBatteryLow: Bool {
        return config.useReducedPollingWhenBatteryLow
    }
    
    /// Reduced polling interval in milliseconds
    public var reducedPollingIntervalMs: Int64 {
        return config.reducedPollingIntervalMs
    }
    
    /// Maximum stored events
    public var maxStoredEvents: Int {
        return config.maxStoredEvents
    }
    
    /// Auto environment attributes enabled
    public var autoEnvAttributesEnabled: Bool {
        return config.autoEnvAttributesEnabled
    }
    
    // MARK: - Initialization
    
    /// Initialize with initial configuration
    /// - Parameter initConfig: Initial configuration
    public init(initConfig: CFConfig) {
        self._config = initConfig
    }
    
    // MARK: - Configuration Update
    
    /// Update the configuration
    /// - Parameter newConfig: New configuration
    /// - Returns: True if the configuration was updated
    public func updateConfig(_ newConfig: CFConfig) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // Compare old and new configs to detect changes
        let oldConfig = _config
        _config = newConfig
        
        // Check which properties have changed and notify listeners
        if oldConfig.eventsQueueSize != newConfig.eventsQueueSize {
            notifyListeners(key: "eventsQueueSize")
        }
        
        if oldConfig.eventsFlushTimeSeconds != newConfig.eventsFlushTimeSeconds {
            notifyListeners(key: "eventsFlushTimeSeconds")
        }
        
        if oldConfig.eventsFlushIntervalMs != newConfig.eventsFlushIntervalMs {
            notifyListeners(key: "eventsFlushIntervalMs")
        }
        
        if oldConfig.maxRetryAttempts != newConfig.maxRetryAttempts {
            notifyListeners(key: "maxRetryAttempts")
        }
        
        if oldConfig.retryInitialDelayMs != newConfig.retryInitialDelayMs {
            notifyListeners(key: "retryInitialDelayMs")
        }
        
        if oldConfig.retryMaxDelayMs != newConfig.retryMaxDelayMs {
            notifyListeners(key: "retryMaxDelayMs")
        }
        
        if oldConfig.retryBackoffMultiplier != newConfig.retryBackoffMultiplier {
            notifyListeners(key: "retryBackoffMultiplier")
        }
        
        if oldConfig.summariesQueueSize != newConfig.summariesQueueSize {
            notifyListeners(key: "summariesQueueSize")
        }
        
        if oldConfig.summariesFlushTimeSeconds != newConfig.summariesFlushTimeSeconds {
            notifyListeners(key: "summariesFlushTimeSeconds")
        }
        
        if oldConfig.summariesFlushIntervalMs != newConfig.summariesFlushIntervalMs {
            notifyListeners(key: "summariesFlushIntervalMs")
        }
        
        if oldConfig.sdkSettingsCheckIntervalMs != newConfig.sdkSettingsCheckIntervalMs {
            notifyListeners(key: "sdkSettingsCheckIntervalMs")
        }
        
        if oldConfig.networkConnectionTimeoutMs != newConfig.networkConnectionTimeoutMs {
            notifyListeners(key: "networkConnectionTimeoutMs")
        }
        
        if oldConfig.networkReadTimeoutMs != newConfig.networkReadTimeoutMs {
            notifyListeners(key: "networkReadTimeoutMs")
        }
        
        if oldConfig.loggingEnabled != newConfig.loggingEnabled {
            notifyListeners(key: "loggingEnabled")
        }
        
        if oldConfig.debugLoggingEnabled != newConfig.debugLoggingEnabled {
            notifyListeners(key: "debugLoggingEnabled")
        }
        
        if oldConfig.logLevel != newConfig.logLevel {
            notifyListeners(key: "logLevel")
        }
        
        if oldConfig.offlineMode != newConfig.offlineMode {
            notifyListeners(key: "offlineMode")
        }
        
        if oldConfig.disableBackgroundPolling != newConfig.disableBackgroundPolling {
            notifyListeners(key: "disableBackgroundPolling")
        }
        
        if oldConfig.backgroundPollingIntervalMs != newConfig.backgroundPollingIntervalMs {
            notifyListeners(key: "backgroundPollingIntervalMs")
        }
        
        if oldConfig.useReducedPollingWhenBatteryLow != newConfig.useReducedPollingWhenBatteryLow {
            notifyListeners(key: "useReducedPollingWhenBatteryLow")
        }
        
        if oldConfig.reducedPollingIntervalMs != newConfig.reducedPollingIntervalMs {
            notifyListeners(key: "reducedPollingIntervalMs")
        }
        
        if oldConfig.maxStoredEvents != newConfig.maxStoredEvents {
            notifyListeners(key: "maxStoredEvents")
        }
        
        if oldConfig.autoEnvAttributesEnabled != newConfig.autoEnvAttributesEnabled {
            notifyListeners(key: "autoEnvAttributesEnabled")
        }
        
        return true
    }
    
    // MARK: - Listener Management
    
    /// Add a listener for configuration changes
    /// - Parameter listener: Listener to add
    public func addConfigChangeListener(_ listener: ConfigChangeListener) {
        lock.lock()
        defer { lock.unlock() }
        
        // Only add if not already present
        if !configChangeListeners.contains(where: { $0.id == listener.id }) {
            configChangeListeners.append(listener)
        }
    }
    
    /// Remove a listener for configuration changes
    /// - Parameter listener: Listener to remove
    public func removeConfigChangeListener(_ listener: ConfigChangeListener) {
        lock.lock()
        defer { lock.unlock() }
        
        configChangeListeners.removeAll { $0.id == listener.id }
    }
    
    /// Notify listeners of a configuration change
    /// - Parameter key: Configuration key that changed
    private func notifyListeners(key: String) {
        // Create a copy of the listeners to avoid concurrent modification issues
        let listeners = configChangeListeners
        
        // Notify each listener
        for listener in listeners {
            listener.onConfigChanged(key: key)
        }
    }
} 