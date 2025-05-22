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
    
    // Track if a settings check is in progress
    private var isCheckingSettings: Bool = false
    
    // Flag to track if we've loaded from cache
    private var initialCacheLoadComplete: Bool = false
    
    // Background state monitor for battery awareness
    private var backgroundStateMonitor: BackgroundStateMonitor?
    
    // Store the current SDK settings (like Kotlin)
    private var currentSdkSettings: SdkSettings?
    
    // Track whether SDK functionality is currently enabled (like Kotlin)
    private var isSdkFunctionalityEnabled: Bool = true
    
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
        
        // Load cached flags asynchronously like Kotlin does
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.loadFromCache()
        }
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
    
    /// Get a specific config value with type checking
    /// - Parameters:
    ///   - key: Config key
    ///   - fallbackValue: Default value if no config found
    ///   - typeCheck: Function to verify the type is correct
    /// - Returns: Config value or fallback value
    public func getConfigValue<T>(key: String, fallbackValue: T, typeCheck: (Any) -> Bool) -> T {
        // If specific value exists and is of correct type
        if let configData = configMap[key] as? [String: Any], 
           let variation = configData["variation"] {
            // Check if the type is valid according to the provided check
            if typeCheck(variation) {
                // The variation is valid, so we can safely cast it
                Logger.info("CONFIG VALUE: \(key): \(variation)")
                return variation as! T
            } else {
                // Type check failed, log warning and return fallback
                Logger.warning("Type check failed for '\(key)': \(variation)")
                Logger.info("Using fallback value for '\(key)': \(fallbackValue)")
                return fallbackValue
            }
        }
        
        // If no config exists for this key, return fallback value
        Logger.info("No config found for key '\(key)', using fallback value: \(fallbackValue)")
        return fallbackValue
    }
    
    /// Convenience method for getting a config value with optional validation
    /// - Parameters:
    ///   - key: Config key
    ///   - fallbackValue: Default value if no config found
    ///   - validator: Optional function to validate the type
    /// - Returns: Config value or fallback value
    internal func getConfigValue<T>(key: String, fallbackValue: T, validator: ((Any) -> Bool)? = nil) -> T {
        if let validator = validator {
            // If validator is provided, use the protocol method
            return getConfigValue(key: key, fallbackValue: fallbackValue, typeCheck: validator)
        }
        
        // If no validator is provided, use a simple type check
        return getConfigValue(key: key, fallbackValue: fallbackValue) { value in
            return value is T || (value is NSNumber && fallbackValue is Bool)
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
        Logger.debug("🔧 ConfigManagerImpl.checkSdkSettings called")
        
        // Skip if already checking
        if isCheckingSettings {
            Logger.debug("🔧 ConfigManagerImpl: Skipping SDK settings check because another check is in progress")
            return
        }
        
        // Set the flag to indicate that a check is in progress
        isCheckingSettings = true
        Logger.debug("🔧 ConfigManagerImpl: Set isCheckingSettings = true")
        
        // Make sure we reset the flag when we're done
        defer { 
            isCheckingSettings = false 
            Logger.debug("🔧 ConfigManagerImpl: Reset isCheckingSettings = false")
        }
        
        // Perform the SDK settings check
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        Logger.debug("Starting SDK settings check at \(timestamp)")
        
        let dimensionId = config.dimensionId ?? ""
        Logger.debug("🔧 Using dimension ID for URL: '\(dimensionId)'")
        let sdkSettingsUrl = "\(CFConstants.Api.SDK_SETTINGS_BASE_URL)/\(dimensionId)/cf-sdk-settings.json"
        
        // Add more detailed logging for SDK settings API call
        Logger.debug("📡 Checking SDK settings at: \(sdkSettingsUrl)")
        
        // Skip if we're in offline mode
        if config.offlineMode {
            Logger.info("📡 API POLL: Skipping config fetch because we're in offline mode")
            return
        }
        
        // STEP 1: Fetch SDK settings metadata (like Kotlin does)
        Logger.debug("📡 API POLL: Fetch metadata strategy - First trying HEAD request: \(sdkSettingsUrl)")
        let metadataResult = await configFetcher.fetchMetadata(url: URL(string: sdkSettingsUrl)!)
        
        guard case .success(let metadata) = metadataResult else {
            if case .error(let message, _, _, _) = metadataResult {
                Logger.warning("SDK settings metadata fetch failed: \(message)")
            }
            return
        }
        
        Logger.info("📡 API POLL: Received metadata - Last-Modified: \(metadata[CFConstants.Http.HEADER_LAST_MODIFIED] ?? "none"), ETag: \(metadata[CFConstants.Http.HEADER_ETAG] ?? "none")")
        
        // Use metadata for conditional fetching
        let currentLastModified = metadata[CFConstants.Http.HEADER_LAST_MODIFIED]
        let currentETag = metadata[CFConstants.Http.HEADER_ETAG]
        
        // Debug logging for metadata comparison
        Logger.debug("Last-Modified comparison: Current=\(currentLastModified ?? "nil"), Previous=\(previousLastModified ?? "nil")")
        Logger.debug("ETag comparison: Current=\(currentETag ?? "nil"), Previous=\(previousETag ?? "nil")")
        
        // Check if either Last-Modified or ETag has changed
        let hasLastModifiedChanged = currentLastModified != nil && currentLastModified != previousLastModified
        let hasETagChanged = currentETag != nil && currentETag != previousETag
        let hasMetadataChanged = hasLastModifiedChanged || hasETagChanged
        
        // Only fetch full settings if this is the first check or metadata has changed
        let needsFullSettingsFetch = currentSdkSettings == nil || hasMetadataChanged
        
        Logger.debug("Will fetch full settings? \(needsFullSettingsFetch)")
        
        // STEP 2: Fetch full SDK settings if needed (like Kotlin does)
        if needsFullSettingsFetch {
            Logger.info("📡 API POLL: Fetching full SDK settings with GET: \(sdkSettingsUrl)")
            let settingsResult = await configFetcher.fetchSdkSettingsWithMetadata(url: URL(string: sdkSettingsUrl)!)
            
            guard case .success(let data) = settingsResult else {
                if case .error(let message, _, _, _) = settingsResult {
                    Logger.warning("SDK settings fetch failed: \(message)")
                }
                return
            }
            
            let (freshMetadata, freshSettings) = data
            Logger.info("📡 API POLL: Received metadata - Last-Modified: \(freshMetadata[CFConstants.Http.HEADER_LAST_MODIFIED] ?? "none"), ETag: \(freshMetadata[CFConstants.Http.HEADER_ETAG] ?? "none")")
            
            // STEP 3: Store the settings and check account enablement (like Kotlin does)
            if let freshSettings = freshSettings {
                currentSdkSettings = freshSettings
                
                // Check if account is enabled or SDK should be skipped
                let accountEnabled = freshSettings.cf_account_enabled
                let skipSdk = freshSettings.cf_skip_sdk
                
                Logger.debug("🔧 SDK SETTINGS: cf_account_enabled=\(accountEnabled), cf_skip_sdk=\(skipSdk)")
                
                if !accountEnabled {
                    Logger.warning("Account is disabled (cf_account_enabled=false). SDK functionality will be limited.")
                    isSdkFunctionalityEnabled = false
                } else if skipSdk {
                    Logger.warning("SDK should be skipped (cf_skip_sdk=true). SDK functionality will be limited.")
                    isSdkFunctionalityEnabled = false
                } else {
                    // Account is enabled and SDK should not be skipped
                    isSdkFunctionalityEnabled = true
                    Logger.info("🔧 SDK SETTINGS: Account enabled and SDK not skipped - SDK functionality enabled")
                }
                
                Logger.debug("🔧 SDK SETTINGS: isSdkFunctionalityEnabled=\(isSdkFunctionalityEnabled)")
            }
        } else {
            Logger.info("📡 API POLL: Using existing SDK settings, no change detected")
        }
        
        Logger.debug("Will fetch new config? \(hasMetadataChanged)")
        
        // STEP 4: Only fetch configs if SDK functionality is enabled AND metadata changed (like Kotlin does)
        if hasMetadataChanged {
            Logger.info("📡 API POLL: Metadata changed - fetching new config")
            Logger.info("SDK settings changed: Previous Last-Modified=\(previousLastModified ?? "nil"), Current=\(currentLastModified ?? "nil"), Previous ETag=\(previousETag ?? "nil"), Current ETag=\(currentETag ?? "nil")")
            
            // Only fetch configs if SDK functionality is enabled
            if isSdkFunctionalityEnabled {
                Logger.info("📡 API POLL: Fetching new config due to metadata change")
                Logger.debug("🔧 SDK functionality is enabled, proceeding with config fetch...")
                
                Logger.debug("📡 Making config fetch request...")
                let configResult = await configFetcher.fetchConfig(lastModified: currentLastModified, etag: currentETag)
                Logger.debug("📡 Config fetch request completed with result: \(configResult)")
                
                guard case .success(let newConfigs) = configResult else {
                    if case .error(let message, _, _, _) = configResult {
                        Logger.warning("Failed to fetch config with last-modified: \(currentLastModified ?? "nil"), etag: \(currentETag ?? "nil"): \(message)")
                    }
                    return
                }
                
                Logger.info("📡 API POLL: Successfully fetched \(newConfigs.count) config entries")
                Logger.debug("Config keys: \(newConfigs.keys)")
                
                // Update config map with new values
                updateConfigMap(newConfigs)
            } else {
                Logger.info("📡 API POLL: Skipping config fetch because SDK functionality is disabled")
                Logger.debug("🔧 isSdkFunctionalityEnabled=\(isSdkFunctionalityEnabled) - config fetch blocked")
            }
            
            // Store both metadata values for future comparisons regardless of SDK functionality status
            previousLastModified = currentLastModified
            previousETag = currentETag
        } else {
            Logger.info("📡 API POLL: Metadata unchanged - skipping config fetch")
        }
        
        let endTimestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        Logger.debug("Completed SDK settings check at \(endTimestamp)")
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
        Logger.debug("🔧 ConfigManagerImpl.startPeriodicSdkSettingsCheck called with interval=\(interval), initialCheck=\(initialCheck)")
        
        // Setup client queue operation with task-based error handling
        clientQueue.async { [weak self] in
            guard let self = self else { 
                Logger.warning("🔧 ConfigManagerImpl: self is nil in clientQueue")
                return 
            }
            Logger.debug("🔧 ConfigManagerImpl: Inside clientQueue, starting periodic SDK settings check...")
            
            // Cancel existing timer if any
            self.timerMutex.lock()
            self.sdkSettingsTimer?.invalidate()
            self.timerMutex.unlock()
            
            // Check if background polling is disabled in config
            if self.config.disableBackgroundPolling {
                Logger.info("🔧 ConfigManagerImpl: Background polling is disabled in config, skipping timer setup")
                
                // Perform immediate check only if requested, even if polling is disabled
                if initialCheck {
                    Logger.debug("🔧 ConfigManagerImpl: Performing immediate check despite disabled polling")
                    self.performTimeoutProtectedCheck()
                }
                
                return
            }
            
            Logger.debug("🔧 ConfigManagerImpl: Background polling is enabled, setting up timer...")
            
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
            Logger.info("🔧 ConfigManagerImpl: Starting periodic settings check with interval: \(actualIntervalMs) ms" +
                        (actualIntervalMs != interval ? " (adjusted for battery)" : ""))
            
            // Create a new timer on the main thread to ensure it works properly
            DispatchQueue.main.async {
                // Create a timer on the main run loop
                self.sdkSettingsTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(actualIntervalMs) / 1000.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Skip this check if another one is already in progress
                    if self.isCheckingSettings {
                        Logger.debug("Skipping periodic SDK settings check because another check is already in progress")
                        return
                    }
                    
                    // Log periodic trigger (like Kotlin does)
                    Logger.info("Periodic SDK settings check triggered by timer")
                    
                    // Use timeout-protected check
                    self.performTimeoutProtectedCheck()
                }
                
                // Ensure the timer continues to fire by adding to run loop with common mode
                if let timer = self.sdkSettingsTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
                
                Logger.info("Started SDK settings check timer with interval \(actualIntervalMs) ms")
            }
            
            // Perform immediate check only if requested
            if initialCheck {
                Logger.debug("🔧 ConfigManagerImpl: Performing immediate initial check")
                // Schedule the initial check with a small delay to allow initialization to complete
                self.clientQueue.asyncAfter(deadline: .now() + 0.1) {
                    Logger.debug("🔧 ConfigManagerImpl: About to call performTimeoutProtectedCheck for initial check")
                    self.performTimeoutProtectedCheck()
                }
            } else {
                Logger.debug("🔧 ConfigManagerImpl: Skipping immediate initial check (initialCheck=false)")
            }
        }
    }
    
    // Helper method to perform a check with timeout protection
    private func performTimeoutProtectedCheck() {
        Logger.debug("🔧 ConfigManagerImpl.performTimeoutProtectedCheck called")
        
        // Use async or sync version based on availability
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            Logger.debug("🔧 ConfigManagerImpl: Using async version (iOS 13+)")
            Task {
                // Implement retry logic with exponential backoff (like Kotlin)
                let maxAttempts = 3
                var attempt = 0
                var delay: TimeInterval = 0.1 // 100ms initial delay
                let maxDelay: TimeInterval = 1.0 // 1000ms max delay
                
                while attempt < maxAttempts {
                    attempt += 1
                    
                    let task = Task {
                        do {
                            Logger.debug("🔧 ConfigManagerImpl: SDK settings check attempt \(attempt)/\(maxAttempts)")
                            try await self.checkSdkSettings()
                            Logger.debug("🔧 ConfigManagerImpl: SDK settings check completed successfully (attempt \(attempt))")
                            return true
                        } catch {
                            Logger.warning("🔧 ConfigManagerImpl: SDK settings check failed (attempt \(attempt)): \(error.localizedDescription)")
                            return false
                        }
                    }
                    
                    // Set up a timeout for this attempt
                    let timeoutTask = Task {
                        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 second timeout per attempt
                        task.cancel()
                        return false
                    }
                    
                    // Wait for either completion or timeout
                    let success = await task.value
                    timeoutTask.cancel()
                    
                    if success {
                        Logger.debug("🔧 ConfigManagerImpl: SDK settings check succeeded on attempt \(attempt)")
                        return
                    }
                    
                    // If this wasn't the last attempt, wait before retrying
                    if attempt < maxAttempts {
                        Logger.debug("🔧 ConfigManagerImpl: Retrying after \(delay * 1000)ms delay...")
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        
                        // Exponential backoff with jitter (like Kotlin)
                        delay = min(delay * 2.0, maxDelay)
                    }
                }
                
                Logger.error("🔧 ConfigManagerImpl: SDK settings check failed after \(maxAttempts) attempts")
            }
        } else {
            Logger.debug("🔧 ConfigManagerImpl: Using sync version (pre-iOS 13)")
            // For older iOS versions, implement simpler retry logic
            let maxAttempts = 3
            var attempt = 0
            
            while attempt < maxAttempts {
                attempt += 1
                Logger.debug("🔧 ConfigManagerImpl: SDK settings check attempt \(attempt)/\(maxAttempts)")
                
                let dispatchGroup = DispatchGroup()
                dispatchGroup.enter()
                var success = false
                
                // Create a background queue for the operation
                let queue = DispatchQueue(label: "ai.customfit.sdkSettings", qos: .utility)
                
                // Use a timeout to avoid indefinite waiting
                let timeoutQueue = DispatchQueue(label: "ai.customfit.sdkSettingsTimeout")
                let timeoutWorkItem = DispatchWorkItem {
                    Logger.warning("🔧 ConfigManagerImpl: SDK settings check attempt \(attempt) timed out")
                    dispatchGroup.leave()
                }
                
                // Schedule timeout after 10 seconds per attempt
                timeoutQueue.asyncAfter(deadline: .now() + 10.0, execute: timeoutWorkItem)
                
                // Perform the check
                queue.async {
                    do {
                        try self.checkSdkSettingsSync()
                        success = true
                        timeoutWorkItem.cancel()
                        Logger.debug("🔧 ConfigManagerImpl: checkSdkSettingsSync completed successfully (attempt \(attempt))")
                    } catch {
                        Logger.warning("🔧 ConfigManagerImpl: SDK settings check failed (attempt \(attempt)): \(error.localizedDescription)")
                        timeoutWorkItem.cancel()
                    }
                    
                    dispatchGroup.leave()
                }
                
                // Wait for completion
                _ = dispatchGroup.wait(timeout: .now() + 11.0)
                
                if success {
                    Logger.debug("🔧 ConfigManagerImpl: SDK settings check succeeded on attempt \(attempt)")
                    return
                }
                
                // If this wasn't the last attempt, wait before retrying
                if attempt < maxAttempts {
                    let delay = min(0.1 * pow(2.0, Double(attempt - 1)), 1.0) // Exponential backoff
                    Logger.debug("🔧 ConfigManagerImpl: Retrying after \(delay * 1000)ms delay...")
                    Thread.sleep(forTimeInterval: delay)
                }
            }
            
            Logger.error("🔧 ConfigManagerImpl: SDK settings check failed after \(maxAttempts) attempts")
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
            guard let self = self else { return }
            
            // Get the appropriate interval
            let interval = self.config.sdkSettingsCheckIntervalMs
            
            Logger.info("Resuming SDK settings polling with interval: \(interval) ms")
            
            // Start the periodic check
            self.startPeriodicSdkSettingsCheck(
                interval: interval,
                initialCheck: true
            )
            
            Logger.info("SDK settings polling resumed")
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
        
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            // Use Task to call async method from sync context
            let semaphore = DispatchSemaphore(value: 0)
            var capturedError: Error?
            
            Task {
                do {
                    try await checkSdkSettings()
                    semaphore.signal()
                } catch {
                    Logger.error("Error in force refresh: \(error.localizedDescription)")
                    capturedError = error
                    semaphore.signal()
                }
            }
            
            // Wait with timeout to avoid deadlock
            let result = semaphore.wait(timeout: .now() + 30.0)
            if result == .timedOut {
                Logger.error("Timeout waiting for config refresh")
                throw NSError(domain: "ConfigManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for config refresh"])
            }
            
            if let error = capturedError {
                throw error
            }
        } else {
            // For older iOS versions, use a simpler approach that won't deadlock
            let semaphore = DispatchSemaphore(value: 0)
            
            // Create a background queue for the operation
            let queue = DispatchQueue(label: "ai.customfit.forceRefresh", qos: .userInitiated)
            
            // Use a timeout to avoid indefinite waiting
            let timeoutQueue = DispatchQueue(label: "ai.customfit.refreshTimeout")
            timeoutQueue.asyncAfter(deadline: .now() + 30.0) {
                Logger.warning("Timeout occurred in forceRefreshSync")
                semaphore.signal()
            }
            
            // Perform a lightweight check using simpler API
            queue.async {
                do {
                    try self.checkSdkSettingsSync()
                    semaphore.signal()
                } catch {
                    Logger.error("Error in force refresh: \(error.localizedDescription)")
                    semaphore.signal()
                }
            }
            
            // Wait with timeout
            let result = semaphore.wait(timeout: .now() + 30.0)
            if result == .timedOut {
                Logger.error("Timeout waiting for config refresh")
                throw NSError(domain: "ConfigManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for config refresh"])
            }
        }
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
        
        // Log updated config values like Kotlin does
        if !changedKeys.isEmpty {
            Logger.info("🔧 --- UPDATED CONFIG VALUES ---")
            for key in changedKeys {
                if let configData = configs[key] as? [String: Any], let variation = configData["variation"] {
                    Logger.info("🔧 CONFIG UPDATE: \(key): \(variation)")
                    notifyListeners(key: key, variation: variation)
                }
            }
        }
        
        // Notify all flags listeners
        if !changedKeys.isEmpty {
            listenerManager.notifyAllFlagsChange(changedKeys: Array(changedKeys))
        }
        
        Logger.info("Configs updated successfully with \(configs.count) entries")
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