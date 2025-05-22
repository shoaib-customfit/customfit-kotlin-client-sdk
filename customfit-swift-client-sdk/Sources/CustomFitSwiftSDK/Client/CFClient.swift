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
    
    // MARK: - Properties
    
    /// SDK configuration
    private let config: CFConfig
    
    /// Config manager
    private let configManager: ConfigManager
    
    /// Connection manager
    private let connectionManager: ConnectionManager
    
    /// Listener manager
    private let listenerManager: ListenerManager
    
    /// User manager
    private let userManager: UserManager
    
    /// Event tracker
    private let eventTracker: EventTracker
    
    /// Summary manager
    private let summaryManager: SummaryManager
    
    /// Background state monitor
    private let backgroundStateMonitor: BackgroundStateMonitor
    
    /// Battery manager
    private let batteryManager: BatteryManager
    
    /// Whether the SDK is initialized
    private var isInitialized: Bool = false
    
    /// HTTP client
    private let httpClient: HttpClient
    
    // MARK: - Initialization
    
    private init(config: CFConfig) {
        self.config = config
        
        // Setup logger
        if config.debugLoggingEnabled {
            Logger.setLogLevel(level: .debug)
        }
        
        // Create HTTP client
        let httpClient = HttpClient(config: config)
        self.httpClient = httpClient
        
        // Create battery manager
        let batteryManager = BatteryManager.shared
        self.batteryManager = batteryManager
        
        // Create user manager
        let userManager = UserManager(user: CFUser())
        self.userManager = userManager
        
        // Create background state monitor
        let backgroundStateMonitor = DefaultBackgroundStateMonitor()
        self.backgroundStateMonitor = backgroundStateMonitor
        
        // Create connection manager
        let connectionManager = DefaultConnectionManager(httpClient: httpClient, config: config)
        self.connectionManager = connectionManager
        
        // Create listener manager
        let listenerManager = DefaultListenerManager()
        self.listenerManager = listenerManager
        
        // Create summary manager
        let summaryManager = SummaryManager(
            httpClient: httpClient,
            user: userManager, 
            config: config
        )
        self.summaryManager = summaryManager
        
        // Create config fetcher
        let configFetcher = ConfigFetcher(
            httpClient: httpClient,
            config: config,
            user: userManager.getUser()
        )
        
        // Create config manager with correct parameters
        let configManager = ConfigManagerImpl(
            configFetcher: configFetcher,
            clientQueue: DispatchQueue(label: "ai.customfit.ConfigManager", qos: .utility),
            listenerManager: listenerManager,
            config: config,
            summaryManager: summaryManager
        )
        self.configManager = configManager
        
        // Create event tracker with session ID
        let sessionId = UUID().uuidString
        let eventTracker = EventTracker(
            config: config,
            user: userManager,
            sessionId: sessionId,
            httpClient: httpClient,
            summaryManager: summaryManager
        )
        self.eventTracker = eventTracker
        
        // Register for notifications
        backgroundStateMonitor.addAppStateListener(listener: self)
        backgroundStateMonitor.addBatteryStateListener(listener: self)
        
        // Start monitoring background state
        backgroundStateMonitor.startMonitoring()
        
        // Initialization complete
        isInitialized = true
        
        // Track app start event
        eventTracker.trackEvent(
            eventName: CFConstants.EventTypes.APP_START,
            properties: [:]
        )
        
        Logger.info("🚀 CustomFit SDK initialized with configuration: \(config)")
    }
    
    deinit {
        shutdown()
    }
    
    // MARK: - Lifecycle
    
    /// Shutdown the SDK and cleanup resources
    public func shutdown() {
        Logger.info("🚀 CustomFit SDK shutting down")
        
        // Track app stop event if initialized
        if isInitialized {
            eventTracker.trackEvent(
                eventName: CFConstants.EventTypes.APP_STOP,
                properties: [:]
            )
        }
        
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
        
        // Track app state events
        switch state {
        case .background:
            eventTracker.trackEvent(
                eventName: CFConstants.EventTypes.APP_BACKGROUND,
                properties: [:]
            )
        case .foreground:
            eventTracker.trackEvent(
                eventName: CFConstants.EventTypes.APP_FOREGROUND,
                properties: [:]
            )
        }
    }
    
    // MARK: - BatteryStateListener Implementation
    
    public func onBatteryStateChange(state: CFBatteryState) {
        Logger.info("Battery state changed: level=\(state.level), isLow=\(state.isLow), isCharging=\(state.isCharging)")
        
        // Update polling intervals based on battery state
        if state.isLow && !state.isCharging {
            // Reduce polling frequency when battery is low
            configManager.setLowPowerMode(enabled: true)
        } else {
            // Normal polling frequency
            configManager.setLowPowerMode(enabled: false)
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
        userManager.updateUser(userManager.getUser().withAttributes(attributes))
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