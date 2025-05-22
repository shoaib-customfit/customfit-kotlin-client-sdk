import Foundation

/// Configuration management interface
public protocol ConfigManager {
    /// Get all feature flags with their current values
    func getAllFlags() -> [String: Any]
    
    /// Get a specific config value
    func getConfigValue<T>(key: String, fallbackValue: T, typeCheck: (Any) -> Bool) -> T
    
    /// Check and update SDK settings
    func checkSdkSettings() throws
    
    /// Start periodic SDK settings check
    func startPeriodicSdkSettingsCheck(interval: Int64, initialCheck: Bool)
    
    /// Restart periodic SDK settings check
    func restartPeriodicSdkSettingsCheck(interval: Int64, initialCheck: Bool) throws
    
    /// Pause polling
    func pausePolling()
    
    /// Resume polling
    func resumePolling()
    
    /// Update a config value and notify listeners
    func updateConfigMap(_ configs: [String: Any])
    
    /// Notify listeners when a config value changes
    func notifyListeners(key: String, variation: Any)
    
    /// Shutdown and clean up resources
    func shutdown()
    
    /// Force config refresh regardless of last-modified header
    func forceRefresh() throws
    
    /// Get current SDK configuration
    func getConfig() -> CFConfig
    
    /// Update configuration
    func updateConfig(_ config: CFConfig)
    
    /// Get boolean feature flag
    func getBooleanFlag(key: String, defaultValue: Bool) -> Bool
    
    /// Get string feature flag
    func getStringFlag(key: String, defaultValue: String) -> String
    
    /// Get integer feature flag
    func getIntFlag(key: String, defaultValue: Int) -> Int
    
    /// Get double feature flag
    func getDoubleFlag(key: String, defaultValue: Double) -> Double
    
    /// Get JSON feature flag
    func getJSONFlag(key: String, defaultValue: [String: Any]) -> [String: Any]
    
    /// Track configuration summary
    func trackConfigSummary(_ config: [String: Any]) -> CFResult<Bool>
    
    /// Flush all pending summaries
    func flushSummaries() -> CFResult<Int>
} 