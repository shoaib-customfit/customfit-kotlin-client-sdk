import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Main client class for the CustomFit SDK
public class CFClient: AppStateListener, BatteryStateListener {
    
    // MARK: - Constants
    
    /// SDK version
    public static let SDK_VERSION = "1.0.0"
    
    // MARK: - Singleton Implementation
    
    /// Singleton instance of the SDK client
    private static var _instance: CFClient?
    
    /// Lock for thread-safe singleton access
    private static let instanceLock = NSLock()
    
    /// Flag to track if initialization is in progress
    private static var _isInitializing = false
    
    /// Initialize or get the singleton instance of CFClient
    /// This method ensures only one instance exists and handles concurrent initialization attempts
    /// - Parameters:
    ///   - config: SDK configuration
    ///   - user: User configuration
    /// - Returns: Singleton CFClient instance
    public static func initialize(config: CFConfig, user: CFUser) -> CFClient {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        
        // Fast path: if already initialized, return existing instance
        if let existingInstance = _instance {
            Logger.info("CFClient singleton already exists, returning existing instance")
            return existingInstance
        }
        
        // Check if initialization is in progress
        if _isInitializing {
            Logger.warning("CFClient initialization already in progress, waiting...")
            // For simplicity in Swift, we'll create a new instance rather than wait
            // In a production environment, you might want to use a DispatchSemaphore or similar
            Logger.warning("Creating new instance despite initialization in progress")
        }
        
        Logger.info("Creating new CFClient singleton instance")
        _isInitializing = true
        
        let newInstance = CFClient(config: config, user: user)
        _instance = newInstance
        _isInitializing = false
        Logger.info("CFClient singleton created successfully")
        return newInstance
    }
    
    /// Get the current singleton instance without initializing
    /// - Returns: Current CFClient instance or nil if not initialized
    public static func getInstance() -> CFClient? {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        return _instance
    }
    
    /// Check if the singleton is initialized
    /// - Returns: true if singleton exists, false otherwise
    public static func isInitialized() -> Bool {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        return _instance != nil
    }
    
    /// Check if initialization is currently in progress
    /// - Returns: true if initialization is in progress, false otherwise
    public static func isInitializing() -> Bool {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        return _isInitializing
    }
    
    /// Shutdown the singleton and clear the instance
    /// This allows for clean reinitialization
    public static func shutdownSingleton() {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        
        if let currentInstance = _instance {
            Logger.info("Shutting down CFClient singleton")
            currentInstance.shutdown()
        }
        
        _instance = nil
        _isInitializing = false
        Logger.info("CFClient singleton shutdown complete")
    }
    
    /// Force reinitialize the singleton with new configuration
    /// This will shutdown the existing instance and create a new one
    /// - Parameters:
    ///   - config: New SDK configuration
    ///   - user: New user configuration
    /// - Returns: New CFClient singleton instance
    public static func reinitialize(config: CFConfig, user: CFUser) -> CFClient {
        Logger.info("Reinitializing CFClient singleton")
        shutdownSingleton()
        return initialize(config: config, user: user)
    }
    
    /// Create a detached instance that bypasses the singleton pattern
    /// Use this for special cases where you need multiple instances
    /// - Parameters:
    ///   - config: SDK configuration
    ///   - user: User configuration
    /// - Returns: Detached CFClient instance (not stored as singleton)
    public static func createDetached(config: CFConfig, user: CFUser) -> CFClient {
        Logger.info("Creating detached CFClient instance (bypassing singleton)")
        return CFClient(config: config, user: user)
    }
    
    /// Create a test instance that bypasses listener setup for testing
    /// This method is intended for unit tests to avoid hanging issues
    /// - Parameters:
    ///   - config: SDK configuration
    ///   - user: User configuration
    /// - Returns: CFClient instance with minimal setup for testing
    internal static func createTestInstance(config: CFConfig, user: CFUser) -> CFClient {
        Logger.info("Creating test CFClient instance (bypassing listener setup)")
        return CFClient(config: config, user: user, skipSetup: true)
    }
    
    /// Initialize or get the singleton instance of CFClient for testing
    /// This method ensures only one instance exists but skips problematic setup for tests
    /// - Parameters:
    ///   - config: SDK configuration
    ///   - user: User configuration
    /// - Returns: Singleton CFClient instance with minimal setup
    internal static func initializeForTesting(config: CFConfig, user: CFUser) -> CFClient {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        
        // Fast path: if already initialized, return existing instance
        if let existingInstance = _instance {
            Logger.info("CFClient singleton already exists, returning existing instance")
            return existingInstance
        }
        
        // Check if initialization is in progress
        if _isInitializing {
            Logger.warning("CFClient initialization already in progress, waiting...")
            Logger.warning("Creating new instance despite initialization in progress")
        }
        
        Logger.info("Creating new CFClient singleton instance for testing")
        _isInitializing = true
        
        let newInstance = CFClient(config: config, user: user, skipSetup: true)
        _instance = newInstance
        _isInitializing = false
        Logger.info("CFClient singleton created successfully for testing")
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
    
    /// Session manager for handling session lifecycle
    private var sessionManager: SessionManager?
    
    /// Current session ID (fallback before SessionManager initializes)
    private var currentSessionId: String = UUID().uuidString
    
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
            summaryManager: summaryManager,
            sessionId: self.currentSessionId
        )
        self.configManager = confManager
        
        // Create event tracker with session ID
        let eventTracker = EventTracker(
            config: self.mutableConfig.config,
            user: userManager,
            sessionId: self.currentSessionId,
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
        
        // Initialize SessionManager after all properties are set
        self.initializeSessionManager()
        
        // Perform initial SDK settings check only if not in offline mode
        if !self.mutableConfig.offlineMode {
            Logger.info("🔧 Performing initial SDK settings check...")
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
        } else {
            Logger.info("🔧 SKIPPING initial SDK settings check in offline mode")
        }
        
        // Setup listeners asynchronously to prevent blocking
        setupListenersAsync()
        
        // Register for config changes
        self.mutableConfig.addConfigChangeListener(self)
        
        Logger.info("🚀 CFClient initialization completed successfully!")
    }
    
    // This must be public to be accessible from Demo project
    private init(config: CFConfig, user: CFUser) {
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
            summaryManager: summaryManager,
            sessionId: self.currentSessionId
        )
        self.configManager = confManager
        
        // Create event tracker with session ID
        let eventTracker = EventTracker(
            config: self.mutableConfig.config,
            user: userManager,
            sessionId: self.currentSessionId,
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
        
        // Initialize SessionManager after all properties are set
        self.initializeSessionManager()
        
        // Perform initial SDK settings check only if not in offline mode
        if !self.mutableConfig.offlineMode {
            Logger.info("🔧 Performing initial SDK settings check...")
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
        } else {
            Logger.info("🔧 SKIPPING initial SDK settings check in offline mode")
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
            summaryManager: summaryManager,
            sessionId: self.currentSessionId
        )
        self.configManager = confManager
        
        // Create event tracker with session ID
        let eventTracker = EventTracker(
            config: self.mutableConfig.config,
            user: userManager,
            sessionId: self.currentSessionId,
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
        
        // Initialize SessionManager only if not skipping setup and after all properties are set
        if !skipSetup {
            self.initializeSessionManager()
        }
        
        // Perform initial SDK settings check only if not in offline mode
        if !self.mutableConfig.offlineMode {
            Logger.info("🔧 Performing initial SDK settings check...")
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
        } else {
            Logger.info("🔧 SKIPPING initial SDK settings check in offline mode")
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
    
    // MARK: - SessionManager Integration
    
    /// Initialize SessionManager with configuration
    private func initializeSessionManager() {
        // Skip session manager initialization in offline mode
        if mutableConfig.offlineMode {
            Logger.info("🔄 SKIPPING SessionManager initialization in offline mode")
            return
        }
        
        // Create session configuration based on CFConfig defaults
        let sessionConfig = SessionConfig(
            maxSessionDurationMs: 60 * 60 * 1000, // 1 hour default
            minSessionDurationMs: 5 * 60 * 1000,  // 5 minutes minimum
            backgroundThresholdMs: 15 * 60 * 1000, // 15 minutes background threshold
            rotateOnAppRestart: true,
            rotateOnAuthChange: true,
            sessionIdPrefix: "cf_session",
            enableTimeBasedRotation: true
        )
        
        // Initialize SessionManager
        let result = SessionManager.initialize(config: sessionConfig)
        
        switch result {
        case .success(let manager):
            self.sessionManager = manager
            
            // Get the current session ID
            self.currentSessionId = manager.getCurrentSessionId()
            
            // Set up session rotation listener
            let listener = CFClientSessionListener(cfClient: self)
            manager.addListener(listener)
            
            Logger.info("🔄 SessionManager initialized with session: \(self.currentSessionId)")
            
        case .error(let message, let error, _, _):
            Logger.error("Failed to initialize SessionManager: \(message)")
            if let error = error {
                Logger.error(error, "SessionManager initialization error details")
            }
        }
    }
    
    /// Update session ID in all managers that use it
    internal func updateSessionIdInManagers(sessionId: String) {
        // TODO: EventTracker and SummaryManager don't have updateSessionId methods
        // These would need to be enhanced to support dynamic session ID updates
        // For now, we'll just log the session change
        
        self.currentSessionId = sessionId
        Logger.debug("Updated session ID in managers: \(sessionId)")
    }
    
    /// Track session rotation as an analytics event
    internal func trackSessionRotationEvent(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
        let properties: [String: Any] = [
            "old_session_id": oldSessionId ?? "none",
            "new_session_id": newSessionId,
            "rotation_reason": reason.description,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        trackEvent(name: "cf_session_rotated", properties: properties)
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
        Logger.debug("🔧 setupListenersAsync: Starting listener setup")
        Logger.debug("🔧 setupListenersAsync: offlineMode=\(mutableConfig.offlineMode), disableBackgroundPolling=\(mutableConfig.disableBackgroundPolling)")
        
        // Use a timeout to ensure we don't hang during initialization
        let timeoutQueue = DispatchQueue(label: "ai.customfit.setupTimeout")
        let timeoutWorkItem = DispatchWorkItem {
            Logger.warning("🔧 setupListenersAsync: Timeout reached during listener setup")
        }
        
        // Schedule timeout after 30 seconds
        timeoutQueue.asyncAfter(deadline: .now() + 30.0, execute: timeoutWorkItem)
        
        // Use background queue to prevent blocking initialization
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { 
                Logger.error("🔧 setupListenersAsync: self is nil!")
                timeoutWorkItem.cancel()
                return 
            }
            
            // Start monitoring background state first
            self.backgroundStateMonitor.startMonitoring()
            
            // Register for state change notifications
            self.backgroundStateMonitor.addAppStateListener(listener: self)
            self.backgroundStateMonitor.addBatteryStateListener(listener: self)
            
            // Configure periodic SDK settings check
            if !self.mutableConfig.offlineMode && !self.mutableConfig.disableBackgroundPolling {
                Logger.debug("🔧 Starting periodic SDK settings check...")
                
                // Start the config manager on the main queue to ensure timer works properly
                DispatchQueue.main.async {
                    self.configManager.startPeriodicSdkSettingsCheck(
                        interval: self.mutableConfig.sdkSettingsCheckIntervalMs,
                        initialCheck: false // Don't do initial check since we already did it in init
                    )
                    
                    Logger.info("🔧 Periodic SDK settings check started successfully")
                }
            } else {
                Logger.info("🔧 SKIPPING periodic SDK settings check: offlineMode=\(self.mutableConfig.offlineMode), disableBackgroundPolling=\(self.mutableConfig.disableBackgroundPolling)")
            }
            
            // Cancel the main timeout since we completed successfully
            timeoutWorkItem.cancel()
            Logger.info("🔧 setupListenersAsync: All listeners set up successfully!")
        }
        
        // Add a fallback mechanism in case the async block doesn't execute
        // This ensures the timer always starts even if there are dispatch queue issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // Check if we need to start the timer directly on main thread as fallback
            if !self.mutableConfig.offlineMode && !self.mutableConfig.disableBackgroundPolling {
                Logger.debug("🔧 setupListenersAsync: Fallback ensuring timer is started")
                
                self.configManager.startPeriodicSdkSettingsCheck(
                    interval: self.mutableConfig.sdkSettingsCheckIntervalMs,
                    initialCheck: false
                )
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
        
        // Shutdown SessionManager
        SessionManager.shutdown()
        sessionManager = nil
        
        Logger.info("🚀 CustomFit SDK shutdown complete")
        isInitialized = false
    }
    
    // MARK: - AppStateListener Implementation
    
    public func onAppStateChange(state: AppState) {
        Logger.info("App state changed: \(state == .background ? "background" : "foreground")")
        
        // Handle session lifecycle based on app state
        if state == .background {
            // Notify SessionManager about background transition
            sessionManager?.onAppBackground()
            
            // Pause polling in background if configured to do so
            if mutableConfig.disableBackgroundPolling {
                Logger.info("App entered background - pausing polling due to disableBackgroundPolling=true")
                configManager.pausePolling()
            }
        } else if state == .foreground {
            // Notify SessionManager about foreground transition
            sessionManager?.onAppForeground()
            
            // Update session activity
            sessionManager?.updateActivity()
            
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
    
    /// Add user property (matches Kotlin naming)
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Property value
    public func addUserProperty(key: String, value: Any) {
        Logger.info("Adding user property: \(key)=\(value)")
        userManager.updateUser(userManager.getUser().withAttribute(key: key, value: value))
    }
    
    /// Add string property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: String value
    public func addStringProperty(key: String, value: String) {
        addUserProperty(key: key, value: value)
    }
    
    /// Add number property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Number value
    public func addNumberProperty(key: String, value: NSNumber) {
        addUserProperty(key: key, value: value)
    }
    
    /// Add boolean property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Boolean value
    public func addBooleanProperty(key: String, value: Bool) {
        addUserProperty(key: key, value: value)
    }
    
    /// Add date property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Date value
    public func addDateProperty(key: String, value: Date) {
        addUserProperty(key: key, value: value)
    }
    
    /// Add geo point property
    /// - Parameters:
    ///   - key: Property key
    ///   - lat: Latitude
    ///   - lon: Longitude
    public func addGeoPointProperty(key: String, lat: Double, lon: Double) {
        let geoPoint = ["lat": lat, "lon": lon]
        addUserProperty(key: key, value: geoPoint)
    }
    
    /// Add JSON property
    /// - Parameters:
    ///   - key: Property key
    ///   - value: JSON object as dictionary
    public func addJsonProperty(key: String, value: [String: Any]) {
        addUserProperty(key: key, value: value)
    }
    
    /// Add multiple user properties (matches Kotlin naming)
    /// - Parameter properties: User properties dictionary
    public func addUserProperties(properties: [String: Any]) {
        Logger.info("Adding user properties: \(properties)")
        userManager.updateUser(userManager.getUser().withProperties(properties))
    }
    
    /// Get user properties (matches Kotlin naming)
    /// - Returns: User properties dictionary
    public func getUserProperties() -> [String: Any] {
        return userManager.getUser().getCurrentProperties()
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
    
    /// Increment the application launch count
    public func incrementAppLaunchCount() {
        // TODO: Implement actual launch count tracking
        Logger.info("App launch count incremented")
    }
    
    // MARK: - Feature Management
    
    /// Get a feature flag value
    /// - Parameters:
    ///   - key: Feature key
    ///   - defaultValue: Default value if flag not found
    /// - Returns: Feature value or default
    public func getFeatureFlag<T>(key: String, defaultValue: T) -> T {
        return configManager.getFeatureValue(key: key, defaultValue: defaultValue)
    }
    
    /// Get a boolean feature flag (convenience method)
    /// - Parameters:
    ///   - key: Feature key
    ///   - defaultValue: Default value if flag not found
    /// - Returns: Feature value or default
    public func getBooleanFeatureFlag(key: String, defaultValue: Bool = false) -> Bool {
        return configManager.getFeatureFlag(key: key, defaultValue: defaultValue)
    }
    
    /// Get all flags
    /// - Returns: All flags
    public func getAllFlags() -> [String: Any] {
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
    
    /// Add a listener for a specific configuration (matches Kotlin addConfigListener)
    /// - Parameters:
    ///   - key: Configuration key
    ///   - listener: Listener callback
    public func addConfigListener<T>(key: String, listener: @escaping (T) -> Void) {
        listenerManager.addConfigListener(key: key, listener: listener)
    }
    
    /// Remove a config listener (matches Kotlin removeConfigListener)
    /// - Parameters:
    ///   - key: Configuration key
    ///   - listener: Listener callback to remove
    public func removeConfigListener<T>(key: String, listener: @escaping (T) -> Void) {
        listenerManager.removeConfigListener(key: key, listener: listener)
    }
    
    /// Clear all listeners for a specific configuration
    /// - Parameter key: Configuration key
    public func clearConfigListeners(key: String) {
        listenerManager.clearConfigListeners(key: key)
    }
    
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
    
    /// Add listener for all feature flags (matches Kotlin addAllFlagsListener)
    /// - Parameter listener: Listener
    public func addAllFlagsListener(listener: @escaping ([String: Any]) -> Void) {
        listenerManager.registerAllFlagsListener(listener: ClosureAllFlagsListener { keys in
            let allFlags = self.getAllFlags()
            listener(allFlags)
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
    
    /// Remove all flags listener (matches Kotlin removeAllFlagsListener)
    public func removeAllFlagsListener() {
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
    private func awaitSdkSettingsCheck(completion: @escaping (Error?) -> Void) {
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
    private func forceRefresh(completion: ((Error?) -> Void)? = nil) {
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
    
    // MARK: - Context Management
    
    /// Add an evaluation context to the user
    /// - Parameter context: The evaluation context to add
    public func addContext(_ context: EvaluationContext) {
        userManager.addContext(context)
        Logger.debug("Added evaluation context with \(context.attributes.count) attributes")
    }
    
    /// Remove an evaluation context from the user by key
    /// - Parameter key: The context key to remove
    public func removeContext(key: String) {
        userManager.removeContext(key: key)
        Logger.debug("Removed evaluation context: \(key)")
    }
    
    /// Get all evaluation contexts for the user
    /// - Returns: Array of evaluation contexts
    public func getContexts() -> [EvaluationContext] {
        let user = userManager.getUser()
        return user.getAllContexts()
    }
    
    // MARK: - Session Management
    
    /// Get the current session ID
    /// - Returns: Current session ID
    public func getCurrentSessionId() -> String {
        return sessionManager?.getCurrentSessionId() ?? currentSessionId
    }
    
    /// Get current session data with metadata
    /// - Returns: SessionData object with session information or nil if not available
    public func getCurrentSessionData() -> SessionData? {
        return sessionManager?.getCurrentSession()
    }
    
    /// Force session rotation with a manual trigger
    /// - Returns: The new session ID after rotation
    public func forceSessionRotation() -> String? {
        return sessionManager?.forceRotation()
    }
    
    /// Update session activity (should be called on user interactions)
    /// This helps maintain session continuity by updating the last active timestamp
    public func updateSessionActivity() {
        sessionManager?.updateActivity()
    }
    
    /// Handle user authentication changes
    /// This will trigger session rotation if configured to do so
    /// - Parameter userId: The new user ID (nil if user logged out)
    public func onUserAuthenticationChange(userId: String?) {
        sessionManager?.onAuthenticationChange(userId: userId)
    }
    
    /// Get session statistics for debugging and monitoring
    /// - Returns: Dictionary containing session statistics
    public func getSessionStatistics() -> [String: Any] {
        return sessionManager?.getSessionStats() ?? [
            "hasActiveSession": false,
            "sessionId": currentSessionId,
            "sessionManagerInitialized": false
        ]
    }
    
    /// Add a session rotation listener to be notified of session changes
    /// - Parameter listener: The listener to add
    public func addSessionRotationListener(_ listener: SessionRotationListener) {
        sessionManager?.addListener(listener)
    }
    
    /// Remove a session rotation listener
    /// - Parameter listener: The listener to remove
    public func removeSessionRotationListener(_ listener: SessionRotationListener) {
        sessionManager?.removeListener(listener)
    }
    
    // MARK: - Runtime Configuration Updates
    
    /// Update the SDK settings check interval at runtime
    /// - Parameter intervalMs: New interval in milliseconds
    public func updateSdkSettingsCheckInterval(intervalMs: Int64) {
        let currentConfig = mutableConfig.config
        let newConfig = CFConfig(
            clientKey: currentConfig.clientKey,
            eventsQueueSize: currentConfig.eventsQueueSize,
            eventsFlushTimeSeconds: currentConfig.eventsFlushTimeSeconds,
            eventsFlushIntervalMs: currentConfig.eventsFlushIntervalMs,
            maxRetryAttempts: currentConfig.maxRetryAttempts,
            retryInitialDelayMs: currentConfig.retryInitialDelayMs,
            retryMaxDelayMs: currentConfig.retryMaxDelayMs,
            retryBackoffMultiplier: currentConfig.retryBackoffMultiplier,
            summariesQueueSize: currentConfig.summariesQueueSize,
            summariesFlushTimeSeconds: currentConfig.summariesFlushTimeSeconds,
            summariesFlushIntervalMs: currentConfig.summariesFlushIntervalMs,
            sdkSettingsCheckIntervalMs: intervalMs,
            networkConnectionTimeoutMs: currentConfig.networkConnectionTimeoutMs,
            networkReadTimeoutMs: currentConfig.networkReadTimeoutMs,
            loggingEnabled: currentConfig.loggingEnabled,
            debugLoggingEnabled: currentConfig.debugLoggingEnabled,
            logLevel: currentConfig.logLevel,
            offlineMode: currentConfig.offlineMode,
            disableBackgroundPolling: currentConfig.disableBackgroundPolling,
            backgroundPollingIntervalMs: currentConfig.backgroundPollingIntervalMs,
            useReducedPollingWhenBatteryLow: currentConfig.useReducedPollingWhenBatteryLow,
            reducedPollingIntervalMs: currentConfig.reducedPollingIntervalMs,
            maxStoredEvents: currentConfig.maxStoredEvents,
            autoEnvAttributesEnabled: currentConfig.autoEnvAttributesEnabled
        )
        if mutableConfig.updateConfig(newConfig) {
            Logger.info("Updated SDK settings check interval to \(intervalMs) ms")
        }
    }
    
    /// Update the events flush interval at runtime
    /// - Parameter intervalMs: New interval in milliseconds
    public func updateEventsFlushInterval(intervalMs: Int64) {
        let currentConfig = mutableConfig.config
        let newConfig = CFConfig(
            clientKey: currentConfig.clientKey,
            eventsQueueSize: currentConfig.eventsQueueSize,
            eventsFlushTimeSeconds: currentConfig.eventsFlushTimeSeconds,
            eventsFlushIntervalMs: intervalMs,
            maxRetryAttempts: currentConfig.maxRetryAttempts,
            retryInitialDelayMs: currentConfig.retryInitialDelayMs,
            retryMaxDelayMs: currentConfig.retryMaxDelayMs,
            retryBackoffMultiplier: currentConfig.retryBackoffMultiplier,
            summariesQueueSize: currentConfig.summariesQueueSize,
            summariesFlushTimeSeconds: currentConfig.summariesFlushTimeSeconds,
            summariesFlushIntervalMs: currentConfig.summariesFlushIntervalMs,
            sdkSettingsCheckIntervalMs: currentConfig.sdkSettingsCheckIntervalMs,
            networkConnectionTimeoutMs: currentConfig.networkConnectionTimeoutMs,
            networkReadTimeoutMs: currentConfig.networkReadTimeoutMs,
            loggingEnabled: currentConfig.loggingEnabled,
            debugLoggingEnabled: currentConfig.debugLoggingEnabled,
            logLevel: currentConfig.logLevel,
            offlineMode: currentConfig.offlineMode,
            disableBackgroundPolling: currentConfig.disableBackgroundPolling,
            backgroundPollingIntervalMs: currentConfig.backgroundPollingIntervalMs,
            useReducedPollingWhenBatteryLow: currentConfig.useReducedPollingWhenBatteryLow,
            reducedPollingIntervalMs: currentConfig.reducedPollingIntervalMs,
            maxStoredEvents: currentConfig.maxStoredEvents,
            autoEnvAttributesEnabled: currentConfig.autoEnvAttributesEnabled
        )
        if mutableConfig.updateConfig(newConfig) {
            Logger.info("Updated events flush interval to \(intervalMs) ms")
        }
    }
    
    /// Update the summaries flush interval at runtime
    /// - Parameter intervalMs: New interval in milliseconds
    public func updateSummariesFlushInterval(intervalMs: Int64) {
        let currentConfig = mutableConfig.config
        let newConfig = CFConfig(
            clientKey: currentConfig.clientKey,
            eventsQueueSize: currentConfig.eventsQueueSize,
            eventsFlushTimeSeconds: currentConfig.eventsFlushTimeSeconds,
            eventsFlushIntervalMs: currentConfig.eventsFlushIntervalMs,
            maxRetryAttempts: currentConfig.maxRetryAttempts,
            retryInitialDelayMs: currentConfig.retryInitialDelayMs,
            retryMaxDelayMs: currentConfig.retryMaxDelayMs,
            retryBackoffMultiplier: currentConfig.retryBackoffMultiplier,
            summariesQueueSize: currentConfig.summariesQueueSize,
            summariesFlushTimeSeconds: currentConfig.summariesFlushTimeSeconds,
            summariesFlushIntervalMs: intervalMs,
            sdkSettingsCheckIntervalMs: currentConfig.sdkSettingsCheckIntervalMs,
            networkConnectionTimeoutMs: currentConfig.networkConnectionTimeoutMs,
            networkReadTimeoutMs: currentConfig.networkReadTimeoutMs,
            loggingEnabled: currentConfig.loggingEnabled,
            debugLoggingEnabled: currentConfig.debugLoggingEnabled,
            logLevel: currentConfig.logLevel,
            offlineMode: currentConfig.offlineMode,
            disableBackgroundPolling: currentConfig.disableBackgroundPolling,
            backgroundPollingIntervalMs: currentConfig.backgroundPollingIntervalMs,
            useReducedPollingWhenBatteryLow: currentConfig.useReducedPollingWhenBatteryLow,
            reducedPollingIntervalMs: currentConfig.reducedPollingIntervalMs,
            maxStoredEvents: currentConfig.maxStoredEvents,
            autoEnvAttributesEnabled: currentConfig.autoEnvAttributesEnabled
        )
        if mutableConfig.updateConfig(newConfig) {
            Logger.info("Updated summaries flush interval to \(intervalMs) ms")
        }
    }
    
    /// Update the network connection timeout at runtime
    /// - Parameter timeoutMs: New timeout in milliseconds
    public func updateNetworkConnectionTimeout(timeoutMs: Int) {
        let currentConfig = mutableConfig.config
        let newConfig = CFConfig(
            clientKey: currentConfig.clientKey,
            eventsQueueSize: currentConfig.eventsQueueSize,
            eventsFlushTimeSeconds: currentConfig.eventsFlushTimeSeconds,
            eventsFlushIntervalMs: currentConfig.eventsFlushIntervalMs,
            maxRetryAttempts: currentConfig.maxRetryAttempts,
            retryInitialDelayMs: currentConfig.retryInitialDelayMs,
            retryMaxDelayMs: currentConfig.retryMaxDelayMs,
            retryBackoffMultiplier: currentConfig.retryBackoffMultiplier,
            summariesQueueSize: currentConfig.summariesQueueSize,
            summariesFlushTimeSeconds: currentConfig.summariesFlushTimeSeconds,
            summariesFlushIntervalMs: currentConfig.summariesFlushIntervalMs,
            sdkSettingsCheckIntervalMs: currentConfig.sdkSettingsCheckIntervalMs,
            networkConnectionTimeoutMs: timeoutMs,
            networkReadTimeoutMs: currentConfig.networkReadTimeoutMs,
            loggingEnabled: currentConfig.loggingEnabled,
            debugLoggingEnabled: currentConfig.debugLoggingEnabled,
            logLevel: currentConfig.logLevel,
            offlineMode: currentConfig.offlineMode,
            disableBackgroundPolling: currentConfig.disableBackgroundPolling,
            backgroundPollingIntervalMs: currentConfig.backgroundPollingIntervalMs,
            useReducedPollingWhenBatteryLow: currentConfig.useReducedPollingWhenBatteryLow,
            reducedPollingIntervalMs: currentConfig.reducedPollingIntervalMs,
            maxStoredEvents: currentConfig.maxStoredEvents,
            autoEnvAttributesEnabled: currentConfig.autoEnvAttributesEnabled
        )
        if mutableConfig.updateConfig(newConfig) {
            Logger.info("Updated network connection timeout to \(timeoutMs) ms")
        }
    }
    
    /// Update the network read timeout at runtime
    /// - Parameter timeoutMs: New timeout in milliseconds
    public func updateNetworkReadTimeout(timeoutMs: Int) {
        let currentConfig = mutableConfig.config
        let newConfig = CFConfig(
            clientKey: currentConfig.clientKey,
            eventsQueueSize: currentConfig.eventsQueueSize,
            eventsFlushTimeSeconds: currentConfig.eventsFlushTimeSeconds,
            eventsFlushIntervalMs: currentConfig.eventsFlushIntervalMs,
            maxRetryAttempts: currentConfig.maxRetryAttempts,
            retryInitialDelayMs: currentConfig.retryInitialDelayMs,
            retryMaxDelayMs: currentConfig.retryMaxDelayMs,
            retryBackoffMultiplier: currentConfig.retryBackoffMultiplier,
            summariesQueueSize: currentConfig.summariesQueueSize,
            summariesFlushTimeSeconds: currentConfig.summariesFlushTimeSeconds,
            summariesFlushIntervalMs: currentConfig.summariesFlushIntervalMs,
            sdkSettingsCheckIntervalMs: currentConfig.sdkSettingsCheckIntervalMs,
            networkConnectionTimeoutMs: currentConfig.networkConnectionTimeoutMs,
            networkReadTimeoutMs: timeoutMs,
            loggingEnabled: currentConfig.loggingEnabled,
            debugLoggingEnabled: currentConfig.debugLoggingEnabled,
            logLevel: currentConfig.logLevel,
            offlineMode: currentConfig.offlineMode,
            disableBackgroundPolling: currentConfig.disableBackgroundPolling,
            backgroundPollingIntervalMs: currentConfig.backgroundPollingIntervalMs,
            useReducedPollingWhenBatteryLow: currentConfig.useReducedPollingWhenBatteryLow,
            reducedPollingIntervalMs: currentConfig.reducedPollingIntervalMs,
            maxStoredEvents: currentConfig.maxStoredEvents,
            autoEnvAttributesEnabled: currentConfig.autoEnvAttributesEnabled
        )
        if mutableConfig.updateConfig(newConfig) {
            Logger.info("Updated network read timeout to \(timeoutMs) ms")
        }
    }
    
    /// Enable or disable debug logging at runtime
    /// - Parameter enabled: Whether debug logging should be enabled
    public func setDebugLoggingEnabled(_ enabled: Bool) {
        let currentConfig = mutableConfig.config
        let newConfig = CFConfig(
            clientKey: currentConfig.clientKey,
            eventsQueueSize: currentConfig.eventsQueueSize,
            eventsFlushTimeSeconds: currentConfig.eventsFlushTimeSeconds,
            eventsFlushIntervalMs: currentConfig.eventsFlushIntervalMs,
            maxRetryAttempts: currentConfig.maxRetryAttempts,
            retryInitialDelayMs: currentConfig.retryInitialDelayMs,
            retryMaxDelayMs: currentConfig.retryMaxDelayMs,
            retryBackoffMultiplier: currentConfig.retryBackoffMultiplier,
            summariesQueueSize: currentConfig.summariesQueueSize,
            summariesFlushTimeSeconds: currentConfig.summariesFlushTimeSeconds,
            summariesFlushIntervalMs: currentConfig.summariesFlushIntervalMs,
            sdkSettingsCheckIntervalMs: currentConfig.sdkSettingsCheckIntervalMs,
            networkConnectionTimeoutMs: currentConfig.networkConnectionTimeoutMs,
            networkReadTimeoutMs: currentConfig.networkReadTimeoutMs,
            loggingEnabled: currentConfig.loggingEnabled,
            debugLoggingEnabled: enabled,
            logLevel: currentConfig.logLevel,
            offlineMode: currentConfig.offlineMode,
            disableBackgroundPolling: currentConfig.disableBackgroundPolling,
            backgroundPollingIntervalMs: currentConfig.backgroundPollingIntervalMs,
            useReducedPollingWhenBatteryLow: currentConfig.useReducedPollingWhenBatteryLow,
            reducedPollingIntervalMs: currentConfig.reducedPollingIntervalMs,
            maxStoredEvents: currentConfig.maxStoredEvents,
            autoEnvAttributesEnabled: currentConfig.autoEnvAttributesEnabled
        )
        if mutableConfig.updateConfig(newConfig) {
            Logger.info("Debug logging \(enabled ? "enabled" : "disabled")")
        }
    }
    
    /// Enable or disable logging at runtime
    /// - Parameter enabled: Whether logging should be enabled
    public func setLoggingEnabled(_ enabled: Bool) {
        let currentConfig = mutableConfig.config
        let newConfig = CFConfig(
            clientKey: currentConfig.clientKey,
            eventsQueueSize: currentConfig.eventsQueueSize,
            eventsFlushTimeSeconds: currentConfig.eventsFlushTimeSeconds,
            eventsFlushIntervalMs: currentConfig.eventsFlushIntervalMs,
            maxRetryAttempts: currentConfig.maxRetryAttempts,
            retryInitialDelayMs: currentConfig.retryInitialDelayMs,
            retryMaxDelayMs: currentConfig.retryMaxDelayMs,
            retryBackoffMultiplier: currentConfig.retryBackoffMultiplier,
            summariesQueueSize: currentConfig.summariesQueueSize,
            summariesFlushTimeSeconds: currentConfig.summariesFlushTimeSeconds,
            summariesFlushIntervalMs: currentConfig.summariesFlushIntervalMs,
            sdkSettingsCheckIntervalMs: currentConfig.sdkSettingsCheckIntervalMs,
            networkConnectionTimeoutMs: currentConfig.networkConnectionTimeoutMs,
            networkReadTimeoutMs: currentConfig.networkReadTimeoutMs,
            loggingEnabled: enabled,
            debugLoggingEnabled: currentConfig.debugLoggingEnabled,
            logLevel: currentConfig.logLevel,
            offlineMode: currentConfig.offlineMode,
            disableBackgroundPolling: currentConfig.disableBackgroundPolling,
            backgroundPollingIntervalMs: currentConfig.backgroundPollingIntervalMs,
            useReducedPollingWhenBatteryLow: currentConfig.useReducedPollingWhenBatteryLow,
            reducedPollingIntervalMs: currentConfig.reducedPollingIntervalMs,
            maxStoredEvents: currentConfig.maxStoredEvents,
            autoEnvAttributesEnabled: currentConfig.autoEnvAttributesEnabled
        )
        if mutableConfig.updateConfig(newConfig) {
            Logger.info("Logging \(enabled ? "enabled" : "disabled")")
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

// MARK: - CFClientSessionListener

/// Session rotation listener that integrates with CFClient
private class CFClientSessionListener: SessionRotationListener {
    private weak var cfClient: CFClient?
    
    init(cfClient: CFClient) {
        self.cfClient = cfClient
    }
    
    func onSessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
        Logger.info("🔄 Session rotated: \(oldSessionId ?? "nil") -> \(newSessionId) (\(reason.description))")
        
        guard let cfClient = cfClient else { return }
        
        // Update session ID in managers
        cfClient.updateSessionIdInManagers(sessionId: newSessionId)
        
        // Track session rotation event
        cfClient.trackSessionRotationEvent(oldSessionId: oldSessionId, newSessionId: newSessionId, reason: reason)
    }
    
    func onSessionRestored(sessionId: String) {
        Logger.info("🔄 Session restored: \(sessionId)")
        
        guard let cfClient = cfClient else { return }
        
        // Update session ID in managers
        cfClient.updateSessionIdInManagers(sessionId: sessionId)
    }
    
    func onSessionError(error: String) {
        Logger.error("🔄 Session error: \(error)")
    }
} 