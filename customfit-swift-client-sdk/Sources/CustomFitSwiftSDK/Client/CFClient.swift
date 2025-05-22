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
        Logger.info("🚀 Creating CFClient with timeout protection...")
        
        // Create the instance with timeout protection
        let startTime = Date()
        let newInstance = CFClient(config: config, user: user)
        let duration = Date().timeIntervalSince(startTime)
        
        Logger.info("🚀 CFClient created successfully in \(String(format: "%.3f", duration)) seconds")
        
        // Store in singleton
        instance = newInstance
        return newInstance
    }
    
    /// Special factory method that creates a minimal CFClient without starting listeners or polling
    /// Use this for debugging or when regular initialization is causing issues
    /// - Parameters:
    ///   - config: SDK configuration
    ///   - user: User
    /// - Returns: Minimal CFClient
    public static func createMinimalClient(config: CFConfig, user: CFUser) -> CFClient {
        Logger.info("⚠️ IMPORTANT: Creating minimal CFClient without full listeners or polling")
        
        // Create an instance with timeout protection
        let startTime = Date()
        let newInstance = CFClient(config: config, user: user, skipSetup: true)
        let duration = Date().timeIntervalSince(startTime)
        
        Logger.info("🚀 Minimal CFClient created successfully in \(String(format: "%.3f", duration)) seconds")
        
        // Mark the instance as initialized for any code that checks this flag
        newInstance.isInitialized = true
        
        // Store in the singleton
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
        
        Logger.info("🚀 CFClient initialization starting...")
        
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
        
        Logger.info("SummaryManager initialized with summariesQueueSize=\(self.mutableConfig.summariesQueueSize), summariesFlushTimeSeconds=\(self.mutableConfig.summariesFlushTimeSeconds), flushIntervalMs=\(self.mutableConfig.summariesFlushIntervalMs)")
        
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
        
        Logger.info("EventTracker initialized with eventsQueueSize=\(self.mutableConfig.eventsQueueSize), maxStoredEvents=\(self.mutableConfig.maxStoredEvents), eventsFlushTimeSeconds=\(self.mutableConfig.eventsFlushTimeSeconds), eventsFlushIntervalMs=\(self.mutableConfig.eventsFlushIntervalMs)")
        
        // Initial offline mode setup from config
        if self.mutableConfig.offlineMode {
            self.configFetcher.setOffline(true)
            self.connectionManager.setOfflineMode(offlineMode: true)
            Logger.info("CFClient initialized in offline mode based on config.")
        }

        // Mark as initialized immediately to prevent hanging
        self.isInitialized = true
        Logger.info("🚀 CFClient core initialization complete")
        
        // Perform initial SDK settings check synchronously (like Kotlin does)
        if !self.mutableConfig.offlineMode {
            Logger.info("🔧 Performing initial SDK settings check synchronously...")
            DispatchQueue.global(qos: .userInitiated).async {
                if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                    Task {
                        do {
                            try await self.configManager.checkSdkSettings()
                            Logger.info("🔧 Initial SDK settings check completed successfully")
                        } catch {
                            Logger.error("🔧 Initial SDK settings check failed: \(error.localizedDescription)")
                        }
                    }
                } else {
                    do {
                        try self.configManager.checkSdkSettingsSync()
                        Logger.info("🔧 Initial SDK settings check completed successfully")
                    } catch {
                        Logger.error("🔧 Initial SDK settings check failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Setup listeners asynchronously to prevent blocking
        setupListenersAsync()
        
        // Register for config changes
        self.mutableConfig.addConfigChangeListener(self)
        
        Logger.info("🚀 CFClient initialization completed successfully!")
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
        
        Logger.info("🚀 CFClient initialization starting...")
        
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
        
        Logger.info("SummaryManager initialized with summariesQueueSize=\(self.mutableConfig.summariesQueueSize), summariesFlushTimeSeconds=\(self.mutableConfig.summariesFlushTimeSeconds), flushIntervalMs=\(self.mutableConfig.summariesFlushIntervalMs)")
        
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

        Logger.info("EventTracker initialized with eventsQueueSize=\(self.mutableConfig.eventsQueueSize), maxStoredEvents=\(self.mutableConfig.maxStoredEvents), eventsFlushTimeSeconds=\(self.mutableConfig.eventsFlushTimeSeconds), eventsFlushIntervalMs=\(self.mutableConfig.eventsFlushIntervalMs)")
        
        // Initial offline mode setup from config
        if self.mutableConfig.offlineMode {
            self.configFetcher.setOffline(true)
            self.connectionManager.setOfflineMode(offlineMode: true)
            Logger.info("CFClient initialized in offline mode based on config.")
        }
        
        // Mark as initialized immediately to prevent hanging
        self.isInitialized = true
        Logger.info("🚀 CFClient core initialization complete")
        
        // Perform initial SDK settings check synchronously (like Kotlin does)
        if !self.mutableConfig.offlineMode {
            Logger.info("🔧 Performing initial SDK settings check synchronously...")
            DispatchQueue.global(qos: .userInitiated).async {
                if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                    Task {
                        do {
                            try await self.configManager.checkSdkSettings()
                            Logger.info("🔧 Initial SDK settings check completed successfully")
                        } catch {
                            Logger.error("🔧 Initial SDK settings check failed: \(error.localizedDescription)")
                        }
                    }
                } else {
                    do {
                        try self.configManager.checkSdkSettingsSync()
                        Logger.info("🔧 Initial SDK settings check completed successfully")
                    } catch {
                        Logger.error("🔧 Initial SDK settings check failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Setup listeners asynchronously to prevent blocking
        setupListenersAsync()
        
        // Register for config changes
        self.mutableConfig.addConfigChangeListener(self)
        
        Logger.info("🚀 CFClient initialization completed successfully!")
    }
    
    // Special initializer for minimal client that can skip listener setup
    internal init(config: CFConfig, user: CFUser, skipSetup: Bool) {
        self.mutableConfig = MutableCFConfig(initConfig: config)
        
        // Setup logger
        Logger.configure(
            loggingEnabled: self.mutableConfig.loggingEnabled,
            debugLoggingEnabled: self.mutableConfig.debugLoggingEnabled,
            logLevelStr: self.mutableConfig.logLevel
        )
        
        Logger.info("🚀 CFClient initialization starting (skipSetup: \(skipSetup))...")
        
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
        
        Logger.info("SummaryManager initialized with summariesQueueSize=\(self.mutableConfig.summariesQueueSize), summariesFlushTimeSeconds=\(self.mutableConfig.summariesFlushTimeSeconds), flushIntervalMs=\(self.mutableConfig.summariesFlushIntervalMs)")
        
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

        Logger.info("EventTracker initialized with eventsQueueSize=\(self.mutableConfig.eventsQueueSize), maxStoredEvents=\(self.mutableConfig.maxStoredEvents), eventsFlushTimeSeconds=\(self.mutableConfig.eventsFlushTimeSeconds), eventsFlushIntervalMs=\(self.mutableConfig.eventsFlushIntervalMs)")
        
        // Initial offline mode setup from config
        if self.mutableConfig.offlineMode {
            self.configFetcher.setOffline(true)
            self.connectionManager.setOfflineMode(offlineMode: true)
            Logger.info("CFClient initialized in offline mode based on config.")
        }
        
        // Mark as initialized immediately to prevent hanging
        self.isInitialized = true
        Logger.info("🚀 CFClient core initialization complete")
        
        // Perform initial SDK settings check synchronously (like Kotlin does)
        if !self.mutableConfig.offlineMode {
            Logger.info("🔧 Performing initial SDK settings check synchronously...")
            DispatchQueue.global(qos: .userInitiated).async {
                if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                    Task {
                        do {
                            try await self.configManager.checkSdkSettings()
                            Logger.info("🔧 Initial SDK settings check completed successfully")
                        } catch {
                            Logger.error("🔧 Initial SDK settings check failed: \(error.localizedDescription)")
                        }
                    }
                } else {
                    do {
                        try self.configManager.checkSdkSettingsSync()
                        Logger.info("🔧 Initial SDK settings check completed successfully")
                    } catch {
                        Logger.error("🔧 Initial SDK settings check failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Only set up listeners and register for config changes if not skipping setup
        if !skipSetup {
            Logger.info("Setting up listeners and registering for config changes")
            setupListenersAsync()
            self.mutableConfig.addConfigChangeListener(self)
        } else {
            Logger.info("SKIPPING listener setup and config change registration")
        }
        
        Logger.info("🚀 CFClient initialization completed successfully!")
    }
    
    private func setupListeners() {
        // Register for notifications
        backgroundStateMonitor.addAppStateListener(listener: self)
        backgroundStateMonitor.addBatteryStateListener(listener: self)
        
        // Start monitoring background state
        backgroundStateMonitor.startMonitoring()
        
        // Start periodic SDK settings check with the improved implementation
        // that includes timeout protection and proper error handling
        Logger.info("Starting periodic SDK settings check with improved safeguards")
        configManager.startPeriodicSdkSettingsCheck(
            interval: mutableConfig.sdkSettingsCheckIntervalMs,
            initialCheck: !mutableConfig.offlineMode // Only perform initial check if not in offline mode
        )
        
        // Initialization complete
        isInitialized = true
        
        Logger.info("🚀 CustomFit SDK initialized with configuration: \(mutableConfig.config)")
    }
    
    private func setupListenersAsync() {
        Logger.info("🔧 Setting up listeners asynchronously...")
        
        // Use a background queue to avoid blocking initialization
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Set up a timeout for the entire listener setup process
            let timeoutQueue = DispatchQueue(label: "ai.customfit.listenerSetupTimeout")
            let timeoutWorkItem = DispatchWorkItem {
                Logger.warning("⚠️ Listener setup timed out after 5 seconds - continuing without full setup")
            }
            
            // Schedule timeout after 5 seconds
            timeoutQueue.asyncAfter(deadline: .now() + 5.0, execute: timeoutWorkItem)
            
            // Perform listener setup operations
            do {
                Logger.debug("🔧 Registering app state listener...")
                self.backgroundStateMonitor.addAppStateListener(listener: self)
                
                Logger.debug("🔧 Registering battery state listener...")
                self.backgroundStateMonitor.addBatteryStateListener(listener: self)
                
                Logger.debug("🔧 Starting background state monitoring...")
                self.backgroundStateMonitor.startMonitoring()
                
                Logger.debug("🔧 Background state monitoring completed successfully!")
                
                // DEBUG: Log the actual config values
                Logger.debug("🔧 CONFIG DEBUG: offlineMode=\(self.mutableConfig.offlineMode)")
                Logger.debug("🔧 CONFIG DEBUG: disableBackgroundPolling=\(self.mutableConfig.disableBackgroundPolling)")
                Logger.debug("🔧 CONFIG DEBUG: condition result=\(!self.mutableConfig.offlineMode && !self.mutableConfig.disableBackgroundPolling)")
                
                // Only start periodic checks if not in offline mode and polling is enabled
                if !self.mutableConfig.offlineMode && !self.mutableConfig.disableBackgroundPolling {
                    Logger.debug("🔧 CONDITIONS MET: offlineMode=\(self.mutableConfig.offlineMode), disableBackgroundPolling=\(self.mutableConfig.disableBackgroundPolling)")
                    Logger.debug("🔧 Starting periodic SDK settings check...")
                    
                    // Start the config manager on the main queue to ensure timer works properly
                    DispatchQueue.main.async {
                        Logger.info("🔧 CALLING startPeriodicSdkSettingsCheck with initialCheck=true")
                        self.configManager.startPeriodicSdkSettingsCheck(
                            interval: self.mutableConfig.sdkSettingsCheckIntervalMs,
                            initialCheck: true // Enable initial check to match Kotlin behavior
                        )
                        
                        Logger.info("🔧 Periodic SDK settings check started successfully")
                    }
                } else {
                    Logger.info("🔧 SKIPPING periodic SDK settings check: offlineMode=\(self.mutableConfig.offlineMode), disableBackgroundPolling=\(self.mutableConfig.disableBackgroundPolling)")
                }
                
                // Cancel the main timeout since we completed successfully
                timeoutWorkItem.cancel()
                Logger.info("🚀 All listeners set up successfully!")
                
            } catch {
                // Cancel timeout and log error
                timeoutWorkItem.cancel()
                Logger.error("❌ Error setting up listeners: \(error.localizedDescription)")
                Logger.info("🚀 CFClient will continue to work with limited functionality")
            }
        }
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
        
        // Handle app state changes like Kotlin does
        if state == .background && mutableConfig.disableBackgroundPolling {
            // Pause polling in background if configured to do so
            Logger.info("App entered background - pausing polling due to disableBackgroundPolling=true")
            configManager.pausePolling()
        } else if state == .foreground {
            // Resume polling when app comes to foreground
            Logger.info("App entered foreground - resuming polling")
            configManager.resumePolling()
            
            // Check for updates immediately when coming to foreground (like Kotlin)
            Logger.debug("Performing immediate SDK settings check on app foreground")
            
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                Task {
                    do {
                        try await configManager.checkSdkSettings()
                        Logger.debug("Immediate foreground SDK settings check completed successfully")
                    } catch {
                        Logger.error("Failed to check SDK settings on foreground: \(error.localizedDescription)")
                    }
                }
            } else {
                // For older versions, use background queue
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    do {
                        try self?.configManager.checkSdkSettingsSync()
                        Logger.debug("Immediate foreground SDK settings check completed successfully")
                    } catch {
                        Logger.error("Failed to check SDK settings on foreground: \(error.localizedDescription)")
                    }
                }
            }
        }
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
        Logger.debug("CFClient: Waiting for SDK settings check initialization...")
        
        // Create a background queue that doesn't block the main thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Create a timeout to ensure we don't wait indefinitely
            let timeoutQueue = DispatchQueue(label: "ai.customfit.sdkSettingsTimeout")
            let timeoutWork = DispatchWorkItem {
                Logger.warning("CFClient: Timeout waiting for SDK settings check")
                completion(NSError(domain: "CFClient", code: 1000, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for SDK settings check"]))
            }
            
            // Schedule timeout after 10 seconds
            timeoutQueue.asyncAfter(deadline: .now() + 10.0, execute: timeoutWork)
            
            // For iOS 13+, use async/await
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                Task {
                    do {
                        // Ask ConfigManager to perform an immediate check
                        try await self.configManager.forceRefresh()
                        
                        // Cancel the timeout since we completed successfully
                        timeoutWork.cancel()
                        
                        Logger.debug("CFClient: SDK settings check completed successfully")
                        completion(nil)
                    } catch {
                        // Cancel the timeout since we completed with error
                        timeoutWork.cancel()
                        
                        Logger.error("CFClient: SDK settings check failed: \(error.localizedDescription)")
                        completion(error)
                    }
                }
            } else {
                // For older iOS versions, use a dispatch group with timeout
                let dispatchGroup = DispatchGroup()
                dispatchGroup.enter()
                
                // Create a background queue for the operation
                let queue = DispatchQueue(label: "ai.customfit.sdkSettings", qos: .utility)
                
                // Perform the check
                queue.async {
                    do {
                        try self.configManager.forceRefreshSync()
                        
                        // Cancel the timeout since we completed successfully
                        timeoutWork.cancel()
                        
                        Logger.debug("CFClient: SDK settings check completed successfully")
                        completion(nil)
                    } catch {
                        // Cancel the timeout since we completed with error
                        timeoutWork.cancel()
                        
                        Logger.error("CFClient: SDK settings check failed: \(error.localizedDescription)")
                        completion(error)
                    }
                    
                    dispatchGroup.leave()
                }
                
                // Wait with a reasonable timeout to avoid blocking forever
                let waitResult = dispatchGroup.wait(timeout: .now() + 10.0)
                if waitResult == .timedOut {
                    // This is a secondary timeout in case the primary one fails
                    Logger.warning("CFClient: DispatchGroup wait timed out in awaitSdkSettingsCheck")
                    
                    // Cancel the timeout work if not already cancelled
                    if !timeoutWork.isCancelled {
                        timeoutWork.cancel()
                        completion(NSError(domain: "CFClient", code: 1001, userInfo: [NSLocalizedDescriptionKey: "DispatchGroup wait timed out in awaitSdkSettingsCheck"]))
                    }
                }
            }
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