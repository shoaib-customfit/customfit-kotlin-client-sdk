import Foundation

/// Configuration management implementation
public class ConfigManagerImpl: ConfigManager {
    
    // MARK: - Properties
    
    private var config: CFConfig
    private var configMap: [String: Any] = [:]
    private let configCache: ConfigCache
    private let configFetcher: ConfigFetcher
    private var summaryManager: SummaryManager?
    private let clientQueue: DispatchQueue
    private let listenerManager: ListenerManager
    
    private var previousLastModified: String?
    private var previousETag: String?
    private var sdkSettingsTimer: Timer?
    private let timerMutex = NSLock()
    
    // Add a mutex to prevent concurrent SDK settings checks
    private let sdkSettingsCheckMutex = NSLock()
    
    // Store the current SDK settings
    private var currentSdkSettings: SdkSettings?
    
    // Track whether SDK functionality is currently enabled
    private var isSdkFunctionalityEnabled: Bool = true
    
    // Track if a settings check is in progress
    private var isCheckingSettings: Bool = false
    
    // Flag to track if we've loaded from cache
    private var initialCacheLoadComplete: Bool = false
    
    // Background state monitor for battery awareness
    private var backgroundStateMonitor: BackgroundStateMonitor?
    
    // MARK: - Initialization
    
    public init(
        configFetcher: ConfigFetcher,
        clientQueue: DispatchQueue,
        listenerManager: ListenerManager,
        config: CFConfig,
        summaryManager: SummaryManager,
        backgroundStateMonitor: BackgroundStateMonitor? = nil
    ) {
        self.config = config
        self.configCache = ConfigCache()
        self.configFetcher = configFetcher
        self.clientQueue = clientQueue
        self.listenerManager = listenerManager
        self.summaryManager = summaryManager
        self.backgroundStateMonitor = backgroundStateMonitor
        
        // Load cached flags if available
        loadFromCache()
    }
    
    /// Initialize with basic dependencies
    public convenience init(config: CFConfig) {
        let user = CFUser.defaultUser()
        let userManager = UserManager(user: user)
        let httpClient = HttpClient(config: config)
        let configFetcher = ConfigFetcher(httpClient: httpClient, config: config, user: user)
        let clientQueue = DispatchQueue(label: "ai.customfit.ConfigManager", qos: .utility)
        let listenerManager = ListenerManagerImpl()
        let summaryManager = SummaryManager(
            httpClient: httpClient,
            user: userManager,
            config: config
        )
        let backgroundStateMonitor = DefaultBackgroundStateMonitor()
        
        self.init(
            configFetcher: configFetcher,
            clientQueue: clientQueue,
            listenerManager: listenerManager,
            config: config,
            summaryManager: summaryManager,
            backgroundStateMonitor: backgroundStateMonitor
        )
    }
    
    // MARK: - ConfigManager Protocol
    
    public func getConfig() -> CFConfig {
        return config
    }
    
    public func updateConfig(_ config: CFConfig) {
        self.config = config
    }
    
    public func getAllFlags() -> [String: Any] {
        // If SDK functionality is disabled, return an empty map
        if !isSdkFunctionalityEnabled {
            Logger.debug("getAllFlags: SDK functionality is disabled, returning empty map")
            return [:]
        }
        
        var result = [String: Any]()
        for (key, configData) in configMap {
            if let data = configData as? [String: Any], let variation = data["variation"] {
                result[key] = variation
            }
        }
        return result
    }
    
    public func getConfigValue<T>(key: String, fallbackValue: T, typeCheck: (Any) -> Bool) -> T {
        // If SDK functionality is disabled, return the fallback value
        if !isSdkFunctionalityEnabled {
            Logger.debug("getConfigValue: SDK functionality is disabled, returning fallback for key '\(key)'")
            return fallbackValue
        }
        
        guard let config = configMap[key] else {
            Logger.warning("No config found for key '\(key)'")
            // Log the fallback value being used
            Logger.info("CONFIG VALUE: \(key): \(fallbackValue) (using fallback)")
            return fallbackValue
        }
        
        guard let configDict = config as? [String: Any] else {
            Logger.warning("Config for '\(key)' is not a dictionary: \(config)")
            // Log the fallback value being used
            Logger.info("CONFIG VALUE: \(key): \(fallbackValue) (using fallback)")
            return fallbackValue
        }
        
        guard let variation = configDict["variation"] else {
            Logger.warning("No variation for '\(key)'")
            // Log the fallback value being used
            Logger.info("CONFIG VALUE: \(key): \(fallbackValue) (using fallback)")
            return fallbackValue
        }
        
        if typeCheck(variation) {
            do {
                // Log the actual config value
                Logger.info("CONFIG VALUE: \(key): \(variation)")
                return variation as! T
            } catch {
                Logger.warning("Type mismatch for '\(key)': expected \(type(of: fallbackValue)), got \(type(of: variation))")
                // Log the fallback value being used
                Logger.info("CONFIG VALUE: \(key): \(fallbackValue) (using fallback due to type mismatch)")
                return fallbackValue
            }
        } else {
            Logger.warning("No valid variation for '\(key)': \(variation)")
            // Log the fallback value being used
            Logger.info("CONFIG VALUE: \(key): \(fallbackValue) (using fallback)")
            return fallbackValue
        }
    }
    
    public func getBooleanFlag(key: String, defaultValue: Bool) -> Bool {
        return getConfigValue(key: key, fallbackValue: defaultValue) { $0 is Bool }
    }
    
    public func getStringFlag(key: String, defaultValue: String) -> String {
        return getConfigValue(key: key, fallbackValue: defaultValue) { $0 is String }
    }
    
    public func getIntFlag(key: String, defaultValue: Int) -> Int {
        return getConfigValue(key: key, fallbackValue: defaultValue) { $0 is Int }
    }
    
    public func getDoubleFlag(key: String, defaultValue: Double) -> Double {
        return getConfigValue(key: key, fallbackValue: defaultValue) { $0 is Double }
    }
    
    public func getJSONFlag(key: String, defaultValue: [String: Any]) -> [String: Any] {
        return getConfigValue(key: key, fallbackValue: defaultValue) { $0 is [String: Any] }
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func checkSdkSettings() async throws {
        // Use a mutex to prevent concurrent SDK settings checks
        if !sdkSettingsCheckMutex.try() {
            Logger.debug("Skipping SDK settings check because another check is in progress")
            return
        }
        
        defer {
            sdkSettingsCheckMutex.unlock()
        }
        
        do {
            // Set the flag to indicate that a check is in progress
            isCheckingSettings = true
            defer { isCheckingSettings = false }
            
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            Logger.debug("Starting SDK settings check at \(timestamp)")
            
            let sdkSettingsUrl = "\(CFConstants.Api.SDK_SETTINGS_BASE_URL)\(String(format: CFConstants.Api.SDK_SETTINGS_PATH_PATTERN, config.clientKey ?? "default"))"
            
            // Add more detailed logging for SDK settings API call
            Logger.info("API POLL: Checking SDK settings at URL: \(sdkSettingsUrl)")
            
            // First try a lightweight HEAD request to check if there are changes
            let metadataResult = await configFetcher.fetchMetadata(url: URL(string: sdkSettingsUrl)!)
            
            guard case .success(let metadata) = metadataResult else {
                if case .error(let message, _, _, _) = metadataResult {
                    Logger.warning("SDK settings metadata fetch failed: \(message)")
                }
                return
            }
            
            // Add more detailed logging about the received metadata
            Logger.info("API POLL: Received metadata - Last-Modified: \(metadata[CFConstants.Http.HEADER_LAST_MODIFIED] ?? "none"), ETag: \(metadata[CFConstants.Http.HEADER_ETAG] ?? "none")")
            
            // Use metadata for conditional fetching
            let currentLastModified = metadata[CFConstants.Http.HEADER_LAST_MODIFIED]
            let currentETag = metadata[CFConstants.Http.HEADER_ETAG]
            
            if currentLastModified == nil && currentETag == nil {
                Logger.debug("No Last-Modified or ETag headers in response")
                return
            }
            
            // *** IMPORTANT DEBUG SECTION ***
            Logger.debug("Last-Modified comparison: Current=\(currentLastModified ?? "nil"), Previous=\(previousLastModified ?? "nil")")
            Logger.debug("ETag comparison: Current=\(currentETag ?? "nil"), Previous=\(previousETag ?? "nil")")
            
            // Check if either Last-Modified or ETag has changed
            let hasLastModifiedChanged = currentLastModified != nil && currentLastModified != previousLastModified
            let hasETagChanged = currentETag != nil && currentETag != previousETag
            let hasMetadataChanged = hasLastModifiedChanged || hasETagChanged
            
            // Only fetch full settings if:
            // 1. This is the first check (no SDK settings yet)
            // 2. Metadata has changed
            let needsFullSettingsFetch = currentSdkSettings == nil || hasMetadataChanged
            
            Logger.debug("Will fetch full settings? \(needsFullSettingsFetch)")
            
            // If we need to fetch the full settings, make a GET request
            if needsFullSettingsFetch {
                // Use the GET request to get the full settings
                Logger.info("API POLL: Fetching full SDK settings with GET: \(sdkSettingsUrl)")
                
                let settingsResult = await configFetcher.fetchSdkSettingsWithMetadata(url: URL(string: sdkSettingsUrl)!)
                
                guard case .success(let data) = settingsResult else {
                    if case .error(let message, _, _, _) = settingsResult {
                        Logger.warning("SDK settings fetch failed: \(message)")
                    }
                    return
                }
                
                // Use the fresh metadata and settings from the GET request
                let (freshMetadata, freshSettings) = data
                
                // Add more detailed logging about the received metadata
                Logger.info("API POLL: Received metadata - Last-Modified: \(freshMetadata[CFConstants.Http.HEADER_LAST_MODIFIED] ?? "none"), ETag: \(freshMetadata[CFConstants.Http.HEADER_ETAG] ?? "none")")
                
                // Store the settings
                if let freshSettings = freshSettings {
                    currentSdkSettings = freshSettings
                    
                    // Check if account is enabled or SDK should be skipped
                    let accountEnabled = freshSettings.cf_account_enabled
                    let skipSdk = freshSettings.cf_skip_sdk
                    
                    if !accountEnabled {
                        Logger.warning("Account is disabled (cf_account_enabled=false). SDK functionality will be limited.")
                        isSdkFunctionalityEnabled = false
                    } else if skipSdk {
                        Logger.warning("SDK should be skipped (cf_skip_sdk=true). SDK functionality will be limited.")
                        isSdkFunctionalityEnabled = false
                    } else {
                        // Account is enabled and SDK should not be skipped
                        isSdkFunctionalityEnabled = true
                    }
                }
            } else {
                // No need to fetch full settings, just use the metadata from HEAD
                Logger.info("API POLL: Using existing SDK settings, no change detected")
            }
            
            Logger.debug("Will fetch new config? \(hasMetadataChanged)")
            
            if hasMetadataChanged {
                Logger.info("API POLL: Metadata changed - fetching new config")
                Logger.info("SDK settings changed: Previous Last-Modified=\(previousLastModified ?? "nil"), Current=\(currentLastModified ?? "nil"), Previous ETag=\(previousETag ?? "nil"), Current ETag=\(currentETag ?? "nil")")
                
                // Only fetch configs if SDK functionality is enabled
                if isSdkFunctionalityEnabled {
                    Logger.info("API POLL: Fetching new config due to metadata change")
                    
                    let configResult = await configFetcher.fetchConfig(lastModified: currentLastModified, etag: currentETag)
                    
                    guard case .success(let newConfigs) = configResult else {
                        if case .error(let message, _, _, _) = configResult {
                            Logger.warning("Failed to fetch config with last-modified: \(currentLastModified ?? "nil"), etag: \(currentETag ?? "nil"): \(message)")
                        }
                        return
                    }
                    
                    Logger.info("API POLL: Successfully fetched \(newConfigs.count) config entries")
                    Logger.debug("Config keys: \(newConfigs.keys)")
                    
                    // Cache the successful response
                    configCache.saveConfigs(configs: newConfigs, lastModified: currentLastModified, etag: currentETag)
                    
                    // Update config map with new values
                    updateConfigMap(newConfigs)
                } else {
                    Logger.info("API POLL: Skipping config fetch because SDK functionality is disabled")
                }
                
                // Store both metadata values for future comparisons regardless of SDK functionality status
                previousLastModified = currentLastModified
                previousETag = currentETag
            } else {
                Logger.info("API POLL: Metadata unchanged - skipping config fetch")
            }
            
            let endTimestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            Logger.debug("Completed SDK settings check at \(endTimestamp)")
            
        } catch {
            Logger.error("Failed to check SDK settings: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Non-async compatibility version for pre-iOS 13
    public func checkSdkSettingsSync() throws {
        // Use a mutex to prevent concurrent SDK settings checks
        if !sdkSettingsCheckMutex.try() {
            Logger.debug("Skipping SDK settings check because another check is in progress")
            return
        }
        
        defer {
            sdkSettingsCheckMutex.unlock()
        }
        
        // Set the flag to indicate that a check is in progress
        isCheckingSettings = true
        defer { isCheckingSettings = false }
        
        // This method implements a simplified version that relies on callbacks
        // and doesn't use the modern async/await API
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        Logger.debug("Starting SDK settings check at \(timestamp)")
        
        Logger.info("SDK settings check running in compatibility mode (non-async version)")
        
        // Trigger an async fetch via the HTTP client using completion handlers
        // The actual implementation would depend on your HTTP client's API
        
        // This is a simplified implementation that immediately returns
        // In a real implementation, you would use completion handlers 
        // to handle the network requests
        
        Logger.info("API POLL: Simplified SDK settings check completed in compatibility mode")
    }
    
    public func startPeriodicSdkSettingsCheck(interval: Int64, initialCheck: Bool = true) {
        clientQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                self.timerMutex.lock()
                defer { self.timerMutex.unlock() }
                
                // Cancel existing timer if any
                self.sdkSettingsTimer?.invalidate()
                
                // Check if background polling is disabled in config
                if self.config.disableBackgroundPolling {
                    Logger.info("Background polling is disabled in config, skipping timer setup")
                    
                    // Perform immediate check only if requested, even if polling is disabled
                    if initialCheck {
                        self.clientQueue.async {
                            // Use async or sync version based on availability
                            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                                Task {
                                    do {
                                        try await self.checkSdkSettings()
                                    } catch {
                                        Logger.error("Failed to check SDK settings: \(error.localizedDescription)")
                                    }
                                }
                            } else {
                                do {
                                    try self.checkSdkSettingsSync()
                                } catch {
                                    Logger.error("Failed to check SDK settings: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                    
                    return
                }
                
                // Get the battery-aware polling interval
                let actualIntervalMs: Int64
                if let monitor = self.backgroundStateMonitor {
                    actualIntervalMs = monitor.getPollingInterval(
                        normalInterval: interval,
                        reducedInterval: self.config.reducedPollingIntervalMs,
                        useReducedWhenLow: self.config.useReducedPollingWhenBatteryLow
                    )
                } else {
                    actualIntervalMs = interval
                }
                
                // Log the actual interval we're using
                Logger.info("Starting periodic settings check with interval: \(actualIntervalMs) ms" +
                            (actualIntervalMs != interval ? " (adjusted for battery)" : ""))
                
                // Create a new timer
                self.sdkSettingsTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(actualIntervalMs) / 1000.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Skip this check if another one is already in progress
                    if self.isCheckingSettings {
                        Logger.debug("Skipping periodic SDK settings check because another check is already in progress")
                        return
                    }
                    
                    // Use async or sync version based on availability
                    if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                        Task {
                            do {
                                Logger.debug("Periodic SDK settings check triggered by timer (async)")
                                try await self.checkSdkSettings()
                            } catch {
                                Logger.error("Periodic SDK settings check failed: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        do {
                            Logger.debug("Periodic SDK settings check triggered by timer (sync)")
                            try self.checkSdkSettingsSync()
                        } catch {
                            Logger.error("Periodic SDK settings check failed: \(error.localizedDescription)")
                        }
                    }
                }
                
                Logger.debug("Started SDK settings check timer with interval \(actualIntervalMs) ms")
                
                // Perform immediate check only if requested
                if initialCheck {
                    self.clientQueue.async {
                        // Use async or sync version based on availability
                        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                            Task {
                                do {
                                    try await self.checkSdkSettings()
                                } catch {
                                    Logger.error("Failed to check SDK settings: \(error.localizedDescription)")
                                }
                            }
                        } else {
                            do {
                                try self.checkSdkSettingsSync()
                            } catch {
                                Logger.error("Failed to check SDK settings: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            } catch {
                Logger.error("Failed to start periodic SDK settings check: \(error.localizedDescription)")
            }
        }
    }
    
    public func restartPeriodicSdkSettingsCheck(interval: Int64, initialCheck: Bool = true) throws {
        timerMutex.lock()
        defer { timerMutex.unlock() }
        
        // Cancel existing timer if any
        sdkSettingsTimer?.invalidate()
        
        // Check if background polling is disabled in config
        if config.disableBackgroundPolling {
            Logger.info("Background polling is disabled in config, skipping timer restart")
            
            // Perform immediate check only if requested, even if polling is disabled
            if initialCheck {
                clientQueue.async { [weak self] in
                    // Use async or sync version based on availability
                    if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                        Task {
                            do {
                                try await self?.checkSdkSettings()
                            } catch {
                                Logger.error("Failed immediate SDK settings check: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        do {
                            try self?.checkSdkSettingsSync()
                        } catch {
                            Logger.error("Failed immediate SDK settings check: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            return
        }
        
        // Get the battery-aware polling interval
        let actualIntervalMs: Int64
        if let monitor = self.backgroundStateMonitor {
            actualIntervalMs = monitor.getPollingInterval(
                normalInterval: interval,
                reducedInterval: self.config.reducedPollingIntervalMs,
                useReducedWhenLow: self.config.useReducedPollingWhenBatteryLow
            )
        } else {
            actualIntervalMs = interval
        }
        
        // Log the actual interval being used
        Logger.info("Restarting periodic settings check with interval: \(actualIntervalMs) ms" +
                   (actualIntervalMs != interval ? " (adjusted for battery)" : ""))
        
        // Create a new timer with updated interval
        sdkSettingsTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(actualIntervalMs) / 1000.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Skip this check if another one is already in progress
            if self.isCheckingSettings {
                Logger.debug("Skipping periodic SDK settings check because another check is already in progress")
                return
            }
            
            // Use async or sync version based on availability
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                Task {
                    do {
                        Logger.debug("Periodic SDK settings check triggered by timer (async)")
                        try await self.checkSdkSettings()
                    } catch {
                        Logger.error("Periodic SDK settings check failed: \(error.localizedDescription)")
                    }
                }
            } else {
                do {
                    Logger.debug("Periodic SDK settings check triggered by timer (sync)")
                    try self.checkSdkSettingsSync()
                } catch {
                    Logger.error("Periodic SDK settings check failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Perform immediate check only if requested
        if initialCheck {
            // Use async or sync version based on availability
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                Task {
                    do {
                        try await self.checkSdkSettings()
                    } catch {
                        Logger.error("Failed to check SDK settings: \(error.localizedDescription)")
                    }
                }
            } else {
                do {
                    try self.checkSdkSettingsSync()
                } catch {
                    Logger.error("Failed to check SDK settings: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func pausePolling() {
        timerMutex.lock()
        defer { timerMutex.unlock() }
        
        sdkSettingsTimer?.invalidate()
        sdkSettingsTimer = nil
        Logger.info("SDK settings polling paused")
    }
    
    public func resumePolling() {
        clientQueue.async { [weak self] in
            do {
                try self?.startPeriodicSdkSettingsCheck(
                    interval: self?.config.sdkSettingsCheckIntervalMs ?? CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS,
                    initialCheck: true
                )
                Logger.info("SDK settings polling resumed")
            } catch {
                Logger.error("Failed to resume SDK settings polling: \(error.localizedDescription)")
            }
        }
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func forceRefresh() async throws {
        Logger.debug("Forcing config refresh by resetting metadata tracking")
        previousLastModified = nil
        previousETag = nil
        try await checkSdkSettings()
    }
    
    public func forceRefreshSync() throws {
        Logger.debug("Forcing config refresh by resetting metadata tracking (sync method)")
        previousLastModified = nil
        previousETag = nil
        try checkSdkSettingsSync()
    }
    
    public func updateConfigMap(_ configs: [String: Any]) {
        // Track changes for notification
        var changedKeys = Set<String>()
        
        // Compare with existing configs to find changes
        for (key, newConfig) in configs {
            if let oldConfig = configMap[key] {
                if !isEqual(oldConfig, newConfig) {
                    changedKeys.insert(key)
                }
            } else {
                // New config
                changedKeys.insert(key)
            }
        }
        
        // Look for removed configs
        for key in configMap.keys {
            if configs[key] == nil {
                changedKeys.insert(key)
            }
        }
        
        // Update the config map with new configs
        configMap = configs
        
        // Notify listeners of changes
        for key in changedKeys {
            if let configData = configs[key] as? [String: Any], let variation = configData["variation"] {
                notifyListeners(key: key, variation: variation)
            }
        }
        
        // Notify all flags listeners
        if !changedKeys.isEmpty {
            listenerManager.notifyAllFlagsChange(changedKeys: Array(changedKeys))
        }
    }
    
    public func notifyListeners(key: String, variation: Any) {
        listenerManager.notifyFeatureFlagChange(key: key, oldValue: nil, newValue: variation)
    }
    
    public func shutdown() {
        pausePolling()
        // Remove listener reference, don't try to clear them
        Logger.info("Config manager shut down")
    }
    
    public func trackConfigSummary(_ config: [String: Any]) -> CFResult<Bool> {
        guard let summaryManager = summaryManager else {
            Logger.warning("Cannot track config summary: SummaryManager not initialized")
            return CFResult.createError(message: "SummaryManager not initialized", category: .state)
        }
        return summaryManager.trackConfigSummary(config)
    }
    
    public func flushSummaries() -> CFResult<Int> {
        guard let summaryManager = summaryManager else {
            Logger.warning("Cannot flush summaries: SummaryManager not initialized")
            return CFResult.createError(message: "SummaryManager not initialized", category: .state)
        }
        return summaryManager.flushSummaries()
    }
    
    // MARK: - Additional API Methods
    
    public func getFeatureFlag(key: String, defaultValue: Bool) -> Bool {
        return getBooleanFlag(key: key, defaultValue: defaultValue)
    }
    
    public func getFeatureValue<T>(key: String, defaultValue: T) -> T {
        return getConfigValue(key: key, fallbackValue: defaultValue) { _ in true }
    }
    
    public func getAllFeatures() -> [String: Any] {
        return getAllFlags()
    }
    
    public func refreshFeatures(completion: ((CFResult<Bool>) -> Void)?) {
        clientQueue.async { [weak self] in
            // Use async or sync version based on availability
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                Task {
                    do {
                        try await self?.forceRefresh()
                        completion?(CFResult.createSuccess(value: true))
                    } catch {
                        completion?(CFResult.createError(message: "Failed to refresh features: \(error.localizedDescription)", error: error))
                    }
                }
            } else {
                do {
                    try self?.forceRefreshSync()
                    completion?(CFResult.createSuccess(value: true))
                } catch {
                    completion?(CFResult.createError(message: "Failed to refresh features: \(error.localizedDescription)", error: error))
                }
            }
        }
    }
    
    public func setLowPowerMode(enabled: Bool) {
        // If low power mode is enabled, use reduced polling interval
        if enabled {
            clientQueue.async { [weak self] in
                do {
                    try self?.restartPeriodicSdkSettingsCheck(
                        interval: self?.config.reducedPollingIntervalMs ?? CFConstants.BackgroundPolling.REDUCED_SDK_SETTINGS_CHECK_INTERVAL_MS,
                        initialCheck: false
                    )
                    Logger.info("SDK settings polling switched to low power mode")
                } catch {
                    Logger.error("Failed to switch to low power mode: \(error.localizedDescription)")
                }
            }
        } else {
            // Use normal polling interval
            clientQueue.async { [weak self] in
                do {
                    try self?.restartPeriodicSdkSettingsCheck(
                        interval: self?.config.sdkSettingsCheckIntervalMs ?? CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS,
                        initialCheck: false
                    )
                    Logger.info("SDK settings polling switched to normal mode")
                } catch {
                    Logger.error("Failed to switch to normal power mode: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func clearAllListeners() {
        // Clear feature flag listeners
        if let listenerManager = listenerManager as? DefaultListenerManager {
            listenerManager.clearAllListeners()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadFromCache() {
        if initialCacheLoadComplete {
            return
        }
        
        Logger.info("Loading configuration from cache...")
        
        let (cachedConfig, cachedLastModified, cachedETag) = configCache.loadCachedConfig()
        
        if let cachedConfig = cachedConfig, !cachedConfig.isEmpty {
            Logger.info("Found cached configuration with \(cachedConfig.count) entries")
            
            // Update the config map with cached values
            updateConfigMap(cachedConfig)
            
            // Set metadata for future conditional requests
            previousLastModified = cachedLastModified
            previousETag = cachedETag
            
            Logger.info("Successfully initialized from cached configuration")
        } else {
            Logger.info("No cached configuration found, will wait for server response")
        }
        
        initialCacheLoadComplete = true
    }
    
    /// Simple equality check for Any values
    private func isEqual(_ a: Any, _ b: Any) -> Bool {
        // Handle primitive types
        if let a = a as? String, let b = b as? String {
            return a == b
        } else if let a = a as? Bool, let b = b as? Bool {
            return a == b
        } else if let a = a as? Int, let b = b as? Int {
            return a == b
        } else if let a = a as? Double, let b = b as? Double {
            return a == b
        }
        
        // Handle dictionaries
        if let a = a as? [String: Any], let b = b as? [String: Any] {
            if a.keys.count != b.keys.count {
                return false
            }
            
            for (key, aValue) in a {
                guard let bValue = b[key] else {
                    return false
                }
                
                if !isEqual(aValue, bValue) {
                    return false
                }
            }
            
            return true
        }
        
        // Handle arrays
        if let a = a as? [Any], let b = b as? [Any] {
            if a.count != b.count {
                return false
            }
            
            for i in 0..<a.count {
                if !isEqual(a[i], b[i]) {
                    return false
                }
            }
            
            return true
        }
        
        // Default to false for unsupported types
        return false
    }
} 