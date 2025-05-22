import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Main client class for the CustomFit SDK
public class CFClient: AppStateListener, BatteryStateListener {
    
    // MARK: - Constants
    
    /// SDK version
    public static let SDK_VERSION = "1.0.0"
    
    // MARK: - Singleton
    
    /// Shared instance of the SDK client
    private static var instance: CFClient?
    
    /// Get or create the SDK client instance
    /// - Parameter config: SDK configuration
    /// - Returns: Singleton instance
    public static func getInstance(config: CFConfig) -> CFClient {
        if let instance = instance {
            return instance
        }
        
        let newInstance = CFClient(config: config)
        instance = newInstance
        return newInstance
    }
    
    /// Create a new instance of the SDK client with a user
    /// - Parameters:
    ///   - config: SDK configuration
    ///   - user: User
    /// - Returns: New client instance
    public static func `init`(config: CFConfig, user: CFUser) -> CFClient {
        let newInstance = CFClient(config: config, user: user)
        instance = newInstance
        return newInstance
    }
    
    // MARK: - Properties
    
    /// SDK configuration
    private let mutableConfig: MutableCFConfig
    
    /// Config manager
    private let configManager: ConfigManager
    
    /// Connection manager
    private let connectionManager: ConnectionManagerInterface
    
    /// Listener manager
    private let listenerManager: ListenerManager
    
    /// User manager
    private let userManager: UserManager
    
    /// Event tracker
    private let eventTracker: EventTracker
    
    /// Summary manager
    private let summaryManager: SummaryManager
    
    /// ConfigFetcher instance
    private let configFetcher: ConfigFetcher
    
    /// Background state monitor
    private let backgroundStateMonitor: BackgroundStateMonitor
    
    /// HTTP client
    private let httpClient: HttpClient
    
    /// Whether the SDK is initialized
    private var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    private init(config: CFConfig) {
        self.mutableConfig = MutableCFConfig(initConfig: config)
        
        // Setup logger
        Logger.configure(
            loggingEnabled: self.mutableConfig.loggingEnabled,
            debugLoggingEnabled: self.mutableConfig.debugLoggingEnabled,
            logLevelStr: self.mutableConfig.logLevel
        )
        
        // Create HTTP client
        let httpClient = HttpClient(config: self.mutableConfig.config)
        self.httpClient = httpClient
        
        // Create user manager
        let userManager = UserManager(user: CFUser())
        self.userManager = userManager
        
        // Create background state monitor
        let backgroundStateMonitor = DefaultBackgroundStateMonitor()
        self.backgroundStateMonitor = backgroundStateMonitor
        
        // Initialize EnvironmentAttributesCollector based on config
        if self.mutableConfig.autoEnvAttributesEnabled {
            EnvironmentAttributesCollector.initializeShared(backgroundStateMonitor: backgroundStateMonitor)
        } else {
            Logger.info("Auto environment attributes collection disabled by config.")
        }

        // Create connection manager - ensure it's DefaultConnectionManager for the interface
        let connManager = DefaultConnectionManager(httpClient: httpClient, config: self.mutableConfig.config)
        self.connectionManager = connManager // Store as ConnectionManagerInterface
        
        // Create listener manager
        let listenerManager = DefaultListenerManager()
        self.listenerManager = listenerManager
        
        // Create summary manager
        let summaryManager = SummaryManager(
            httpClient: httpClient,
            user: userManager,
            config: self.mutableConfig.config
        )
        self.summaryManager = summaryManager
        
        // Create and store config fetcher
        let fetcher = ConfigFetcher(
            httpClient: httpClient,
            config: self.mutableConfig.config,
            user: userManager.getUser()
        )
        self.configFetcher = fetcher // Store the instance
        
        // Create config manager with correct parameters
        let confManager = ConfigManagerImpl(
            configFetcher: self.configFetcher, // Pass the stored fetcher
            clientQueue: DispatchQueue(label: "ai.customfit.ConfigManager", qos: .utility),
            listenerManager: listenerManager,
            config: self.mutableConfig.config,
            summaryManager: summaryManager
        )
        self.configManager = confManager
        
        // Create event tracker with session ID
        let sessionId = UUID().uuidString
        let eventTracker = EventTracker(
            config: self.mutableConfig.config,
            user: userManager,
            sessionId: sessionId,
            httpClient: httpClient,
            summaryManager: summaryManager
        )
        self.eventTracker = eventTracker
        
        // Initial offline mode setup from config
        if self.mutableConfig.offlineMode {
            self.configFetcher.setOffline(true)
            self.connectionManager.setOfflineMode(offlineMode: true)
            Logger.info("CFClient initialized in offline mode based on config.")
        }

        setupListeners()
        self.mutableConfig.addConfigChangeListener(self)
    }
    
    // This must be public to be accessible from Demo project
    public init(config: CFConfig, user: CFUser) {
        self.mutableConfig = MutableCFConfig(initConfig: config)
        
        // Setup logger
        Logger.configure(
            loggingEnabled: self.mutableConfig.loggingEnabled,
            debugLoggingEnabled: self.mutableConfig.debugLoggingEnabled,
            logLevelStr: self.mutableConfig.logLevel
        )
        
        // Create HTTP client
        let httpClient = HttpClient(config: self.mutableConfig.config)
        self.httpClient = httpClient
        
        // Create user manager with provided user
        let userManager = UserManager(user: user)
        self.userManager = userManager
        
        // Create background state monitor
        let backgroundStateMonitor = DefaultBackgroundStateMonitor()
        self.backgroundStateMonitor = backgroundStateMonitor
        
        // Initialize EnvironmentAttributesCollector based on config
        if self.mutableConfig.autoEnvAttributesEnabled {
            EnvironmentAttributesCollector.initializeShared(backgroundStateMonitor: backgroundStateMonitor)
        } else {
            Logger.info("Auto environment attributes collection disabled by config.")
        }
        
        // Create connection manager - ensure it's DefaultConnectionManager for the interface
        let connManager = DefaultConnectionManager(httpClient: httpClient, config: self.mutableConfig.config)
        self.connectionManager = connManager // Store as ConnectionManagerInterface
        
        // Create listener manager
        let listenerManager = DefaultListenerManager()
        self.listenerManager = listenerManager
        
        // Create summary manager
        let summaryManager = SummaryManager(
            httpClient: httpClient,
            user: userManager,
            config: self.mutableConfig.config
        )
        self.summaryManager = summaryManager
        
        // Create and store config fetcher
        let fetcher = ConfigFetcher(
            httpClient: httpClient,
            config: self.mutableConfig.config,
            user: user // Use the provided user
        )
        self.configFetcher = fetcher // Store the instance
        
        // Create config manager with correct parameters
        let confManager = ConfigManagerImpl(
            configFetcher: self.configFetcher, // Pass the stored fetcher
            clientQueue: DispatchQueue(label: "ai.customfit.ConfigManager", qos: .utility),
            listenerManager: listenerManager,
            config: self.mutableConfig.config,
            summaryManager: summaryManager
        )
        self.configManager = confManager
        
        // Create event tracker with session ID
        let sessionId = UUID().uuidString
        let eventTracker = EventTracker(
            config: self.mutableConfig.config,
            user: userManager,
            sessionId: sessionId,
            httpClient: httpClient,
            summaryManager: summaryManager
        )
        self.eventTracker = eventTracker

        // Initial offline mode setup from config
        if self.mutableConfig.offlineMode {
            self.configFetcher.setOffline(true)
            self.connectionManager.setOfflineMode(offlineMode: true)
            Logger.info("CFClient initialized in offline mode based on config.")
        }
        
        setupListeners()
        self.mutableConfig.addConfigChangeListener(self)
    }
    
    private func setupListeners() {
        // Register for notifications
        backgroundStateMonitor.addAppStateListener(listener: self)
        backgroundStateMonitor.addBatteryStateListener(listener: self)
        
        // Start monitoring background state
        backgroundStateMonitor.startMonitoring()
        
        // Start periodic SDK settings check with the configured interval
        configManager.startPeriodicSdkSettingsCheck(interval: mutableConfig.sdkSettingsCheckIntervalMs, initialCheck: true)
        
        // Initialization complete
        isInitialized = true
        
        Logger.info("🚀 CustomFit SDK initialized with configuration: \(mutableConfig.config)")
    }
    
    deinit {
        shutdown()
    }
    
    // MARK: - Lifecycle
    
    /// Shutdown the SDK and cleanup resources
    public func shutdown() {
        Logger.info("🚀 CustomFit SDK shutting down")
        
        // Stop background monitoring
        backgroundStateMonitor.stopMonitoring()
        
        // Remove listeners
        backgroundStateMonitor.removeAppStateListener(listener: self)
        backgroundStateMonitor.removeBatteryStateListener(listener: self)
        
        // Stop polling and timers
        configManager.shutdown()
        
        Logger.info("🚀 CustomFit SDK shutdown complete")
        isInitialized = false
    }
    
    // MARK: - AppStateListener Implementation
    
    public func onAppStateChange(state: AppState) {
        Logger.info("App state changed: \(state == .background ? "background" : "foreground")")
    }
    
    // MARK: - BatteryStateListener Implementation
    
    public func onBatteryStateChange(state: CFBatteryState) {
        Logger.debug("CFClient: Battery state changed - Level: \(state.level), Low: \(state.isLow), Charging: \(state.isCharging)")
        // Handle battery state changes, e.g., adjust polling intervals
        if mutableConfig.useReducedPollingWhenBatteryLow && state.isLow && !state.isCharging {
            Logger.info("Battery low, using reduced polling interval: \(mutableConfig.reducedPollingIntervalMs) ms")
            do {
                try configManager.restartPeriodicSdkSettingsCheck(interval: mutableConfig.reducedPollingIntervalMs, initialCheck: false)
            } catch {
                Logger.error("Failed to adjust polling for low battery: \(error.localizedDescription)")
            }
        } else {
            // Revert to normal background polling interval or foreground interval if app is in foreground
            let currentAppState = backgroundStateMonitor.getCurrentAppState()
            if currentAppState == .foreground {
                 // If foreground, sdkSettingsCheckIntervalMs is typically used by resumePolling logic
                 // For now, explicitly restart with sdkSettingsCheckIntervalMs if not low battery.
                do {
                    try configManager.restartPeriodicSdkSettingsCheck(interval: mutableConfig.sdkSettingsCheckIntervalMs, initialCheck: false)
                } catch {
                    Logger.error("Failed to adjust polling for foreground: \(error.localizedDescription)")
                }
            } else {
                do {
                    try configManager.restartPeriodicSdkSettingsCheck(interval: mutableConfig.backgroundPollingIntervalMs, initialCheck: false)
                } catch {
                    Logger.error("Failed to adjust polling for background: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - User Management
    
    /// Set the user ID
    /// - Parameter userId: User ID
    public func setUserId(userId: String) {
        Logger.info("Setting user ID: \(userId)")
        userManager.updateUser(userManager.getUser().withUserId(userId))
    }
    
    /// Set user attributes
    /// - Parameter attributes: User attributes
    public func setUserAttributes(attributes: [String: Any]) {
        Logger.info("Setting user attributes: \(attributes)")
        userManager.updateUser(userManager.getUser().withProperties(attributes))
    }
    
    /// Set a single user attribute
    /// - Parameters:
    ///   - key: Attribute key
    ///   - value: Attribute value
    public func setUserAttribute(key: String, value: Any) {
        Logger.info("Setting user attribute: \(key)=\(value)")
        userManager.updateUser(userManager.getUser().withAttribute(key: key, value: value))
    }
    
    /// Set the device ID
    /// - Parameter deviceId: Device ID
    public func setDeviceId(deviceId: String) {
        Logger.info("Setting device ID: \(deviceId)")
        userManager.updateUser(userManager.getUser().withDeviceId(deviceId))
    }
    
    /// Set the anonymous ID
    /// - Parameter anonymousId: Anonymous ID
    public func setAnonymousId(anonymousId: String) {
        Logger.info("Setting anonymous ID: \(anonymousId)")
        userManager.updateUser(userManager.getUser().withAnonymousId(anonymousId))
    }
    
    // MARK: - Feature Management
    
    /// Get a feature flag
    /// - Parameters:
    ///   - key: Feature key
    ///   - defaultValue: Default value if flag not found
    /// - Returns: Feature value or default
    public func getFeatureFlag(key: String, defaultValue: Bool = false) -> Bool {
        return configManager.getFeatureFlag(key: key, defaultValue: defaultValue)
    }
    
    /// Get a feature value
    /// - Parameters:
    ///   - key: Feature key
    ///   - defaultValue: Default value if feature not found
    /// - Returns: Feature value or default
    public func getFeatureValue<T>(key: String, defaultValue: T) -> T {
        return configManager.getFeatureValue(key: key, defaultValue: defaultValue)
    }
    
    /// Get all features
    /// - Returns: All features
    public func getAllFeatures() -> [String: Any] {
        return configManager.getAllFeatures()
    }
    
    /// Refresh features from server
    /// - Parameter completion: Completion handler
    public func refreshFeatures(completion: ((CFResult<Bool>) -> Void)? = nil) {
        configManager.refreshFeatures(completion: completion)
    }
    
    // MARK: - Event Tracking
    
    /// Track an event
    /// - Parameters:
    ///   - name: Event name
    ///   - properties: Event properties
    public func trackEvent(name: String, properties: [String: Any]? = nil) {
        eventTracker.trackEvent(eventName: name, properties: properties)
    }
    
    /// Track a screen view
    /// - Parameter screenName: Screen name
    public func trackScreenView(screenName: String) {
        eventTracker.trackScreenView(screenName: screenName)
    }
    
    /// Track feature usage
    /// - Parameter featureId: Feature ID
    public func trackFeatureUsage(featureId: String) {
        // Create properties with feature ID
        let properties = ["feature_id": featureId]
        
        // Track feature usage event
        trackEvent(name: "feature_usage", properties: properties)
    }
    
    /// Track config request
    /// - Parameters:
    ///   - config: Config data
    ///   - customerUserId: Customer user ID
    ///   - sessionId: Session ID
    /// - Returns: Result of tracking
    public func trackConfigRequest(
        config: [String: Any],
        customerUserId: String,
        sessionId: String
    ) -> CFResult<Bool> {
        return summaryManager.trackConfigRequest(
            config: config,
            customerUserId: customerUserId,
            sessionId: sessionId
        )
    }
    
    // MARK: - Listeners
    
    /// Add feature flag listener
    /// - Parameters:
    ///   - key: Feature key
    ///   - listener: Listener
    public func addFeatureFlagListener(key: String, listener: @escaping (Bool) -> Void) {
        listenerManager.registerFeatureFlagListener(flagKey: key, listener: ClosureFeatureFlagChangeListener { _, _, newValue in
            listener(newValue as? Bool ?? false)
        })
    }
    
    /// Add feature value listener
    /// - Parameters:
    ///   - key: Feature key
    ///   - listener: Listener
    public func addFeatureValueListener<T>(key: String, listener: @escaping (T) -> Void) {
        listenerManager.registerFeatureFlagListener(flagKey: key, listener: ClosureFeatureFlagChangeListener { _, _, newValue in
            if let value = newValue as? T {
                listener(value)
            }
        })
    }
    
    /// Add listener for all feature flags
    /// - Parameter listener: Listener
    public func addFeatureFlagsListener(listener: @escaping ([String: Any]) -> Void) {
        listenerManager.registerAllFlagsListener(listener: ClosureAllFlagsListener { keys in
            let allFeatures = self.getAllFeatures()
            listener(allFeatures)
        })
    }
    
    // MARK: - Connection Status
    
    /// Add connection status listener
    /// - Parameter listener: Listener
    public func addConnectionStatusListener(listener: @escaping (ConnectionStatus, ConnectionInformation) -> Void) {
        listenerManager.addConnectionStatusListener(listener: ClosureConnectionStatusListener { status, info in
            listener(status, info)
        })
    }
    
    // MARK: - Removing Listeners
    
    /// Remove feature flag listener
    /// - Parameter key: Feature key
    public func removeFeatureFlagListener(key: String) {
        // Note: This is a simplification - proper implementation would need to track closures
        // For now we'll clear all listeners for this key
    }
    
    /// Remove feature value listener
    /// - Parameter key: Feature key
    public func removeFeatureValueListener(key: String) {
        // Note: This is a simplification - proper implementation would need to track closures
        // For now we'll clear all listeners for this key
    }
    
    /// Remove all flags listener
    public func removeFeatureFlagsListener() {
        // Note: This is a simplification - proper implementation would need to track closures
        // For now we'll clear all listeners
    }
    
    /// Remove connection status listener
    public func removeConnectionStatusListener() {
        // Note: This is a simplification - proper implementation would need to track closures
        // For now we'll clear all listeners
    }
    
    // MARK: - Log Level
    
    /// Set SDK logging level
    /// - Parameter level: Log level
    public func setLogLevel(level: Logger.LogLevel) {
        Logger.setLogLevel(level: level)
        Logger.info("Log level set to \(level)")
    }
    
    /// Get current SDK logging level
    /// - Returns: Current log level
    public func getLogLevel() -> Logger.LogLevel {
        return Logger.getLogLevel()
    }
    
    /// Waits for SDK settings to be initialized
    /// This is a Swift equivalent to Kotlin's suspend function
    /// - Parameter completion: Completion handler called when SDK settings have been initialized
    public func awaitSdkSettingsCheck(completion: @escaping (Error?) -> Void) {
        DispatchQueue.global().async {
            // For now, we'll simulate the SDK settings check with a delay
            // In a real implementation, this would wait for a completion signal from the config manager
            Thread.sleep(forTimeInterval: 2.0)
            completion(nil)
        }
    }
    
    /// Force a refresh of the configuration regardless of Last-Modified header
    /// - Parameter completion: Optional completion handler
    public func forceRefresh(completion: ((Error?) -> Void)? = nil) {
        Logger.info("Force refreshing configurations")
        
        // For iOS 13+, use async/await
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            Task {
                do {
                    try await configManager.forceRefresh()
                    completion?(nil)
                } catch {
                    Logger.error("Force refresh failed: \(error.localizedDescription)")
                    completion?(error)
                }
            }
        } else {
            // For older iOS versions, use sync method
            do {
                try configManager.forceRefreshSync()
                completion?(nil)
            } catch {
                Logger.error("Force refresh failed: \(error.localizedDescription)")
                completion?(error)
            }
        }
    }
}

// MARK: - Helper Closures for Listeners

/// Closure-based feature flag change listener
private class ClosureFeatureFlagChangeListener: FeatureFlagChangeListener {
    private let callback: (String, Any?, Any?) -> Void
    
    init(_ callback: @escaping (String, Any?, Any?) -> Void) {
        self.callback = callback
    }
    
    func onFeatureFlagChange(key: String, oldValue: Any?, newValue: Any?) {
        callback(key, oldValue, newValue)
    }
}

/// Closure-based all flags listener
private class ClosureAllFlagsListener: AllFlagsListener {
    private let callback: ([String]) -> Void
    
    init(_ callback: @escaping ([String]) -> Void) {
        self.callback = callback
    }
    
    func onFlagsChange(changedKeys: [String]) {
        callback(changedKeys)
    }
}

/// Closure-based connection status listener
private class ClosureConnectionStatusListener: ConnectionStatusListener {
    private let callback: (ConnectionStatus, ConnectionInformation) -> Void
    
    init(_ callback: @escaping (ConnectionStatus, ConnectionInformation) -> Void) {
        self.callback = callback
    }
    
    func onConnectionStatusChanged(newStatus: ConnectionStatus, info: ConnectionInformation) {
        callback(newStatus, info)
    }
}

// MARK: - ConfigChangeListener
extension CFClient: ConfigChangeListener {
    public var id: String {
        return "CFClient_ConfigChangeListener"
    }

    public func onConfigChanged(key: String) {
        Logger.debug("CFClient: Detected configuration change for key - \(key)")
        let newConfig = mutableConfig.config // Get the latest immutable config

        // Mirroring Kotlin's CFClient.handleConfigChange behavior
        switch key {
        case "offlineMode":
            self.configFetcher.setOffline(newConfig.offlineMode) // No cast needed
            self.connectionManager.setOfflineMode(offlineMode: newConfig.offlineMode) // No cast needed
            Logger.info("CFClient: Updated offline mode to: \(newConfig.offlineMode)")
        case "sdkSettingsCheckIntervalMs", "backgroundPollingIntervalMs", "reducedPollingIntervalMs":
            // Polling interval changes are handled by onBatteryStateChange and onAppStateChange
            // or by directly calling restartPeriodicSdkSettingsCheck if needed.
            // Here, we ensure the ConfigManager is using the primary interval if not otherwise adjusted.
            // This logic might need refinement based on how ConfigManager prioritizes intervals.
             Logger.info("CFClient: SDK settings check interval changed. ConfigManager will pick up new interval: \(newConfig.sdkSettingsCheckIntervalMs)")
             do {
                 try configManager.restartPeriodicSdkSettingsCheck(interval: newConfig.sdkSettingsCheckIntervalMs, initialCheck: true) // Or choose based on current state.
             } catch {
                 Logger.error("Failed to restart periodic SDK settings check: \(error.localizedDescription)")
             }
        case "networkConnectionTimeoutMs":
            httpClient.updateConnectionTimeout(timeout: newConfig.networkConnectionTimeoutMs)
            Logger.info("CFClient: Updated network connection timeout to \(newConfig.networkConnectionTimeoutMs) ms")
        case "networkReadTimeoutMs":
            httpClient.updateReadTimeout(timeout: newConfig.networkReadTimeoutMs)
            Logger.info("CFClient: Updated network read timeout to \(newConfig.networkReadTimeoutMs) ms")
        case "loggingEnabled", "debugLoggingEnabled", "logLevel":
            Logger.configure(
                loggingEnabled: newConfig.loggingEnabled,
                debugLoggingEnabled: newConfig.debugLoggingEnabled,
                logLevelStr: newConfig.logLevel
            )
            Logger.info("CFClient: Updated logging configuration.")
        // Add other cases as needed for properties in CFConfig that sub-modules should react to.
        default:
            Logger.debug("CFClient: Configuration key \(key) changed, but no specific action defined in CFClient.")
        }
    }
}

// MARK: - Public API
extension CFClient {
    public func updateConfig(newConfig: CFConfig) {
        let oldConfig = self.mutableConfig.config
        if self.mutableConfig.updateConfig(newConfig) {
             Logger.info("CFConfig updated. Old: \(oldConfig), New: \(newConfig)")
             // The onConfigChanged(key:) will be called for each changed property by MutableCFConfig
        }
    }
} 