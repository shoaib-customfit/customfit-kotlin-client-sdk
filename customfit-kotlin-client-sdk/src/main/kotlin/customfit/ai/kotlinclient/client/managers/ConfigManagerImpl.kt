package customfit.ai.kotlinclient.client.managers

import customfit.ai.kotlinclient.constants.CFConstants
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.network.ConfigFetcher
import customfit.ai.kotlinclient.client.managers.ListenerManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.ConcurrentHashMap
import java.text.SimpleDateFormat
import java.util.Date
import java.util.concurrent.atomic.AtomicBoolean
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.utils.CoroutineUtils
import java.util.TimerTask

/**
 * Implementation of ConfigManager that handles config fetching and processing
 * with support for offline caching and immediate initialization from cache
 */
class ConfigManagerImpl(
    private val configFetcher: ConfigFetcher,
    private val clientScope: CoroutineScope,
    private val listenerManager: ListenerManager,
    private val cfConfig: customfit.ai.kotlinclient.config.core.CFConfig,
    private val summaryManager: customfit.ai.kotlinclient.analytics.summary.SummaryManager
) : ConfigManager {
    
    private val configMap: MutableMap<String, Any> = ConcurrentHashMap()
    private var previousLastModified: String? = null
    private var previousETag: String? = null
    private var sdkSettingsTimer: java.util.Timer? = null
    private val timerMutex = kotlinx.coroutines.sync.Mutex()
    
    // Add a mutex to prevent concurrent SDK settings checks
    private val sdkSettingsCheckMutex = kotlinx.coroutines.sync.Mutex()
    
    // Store the current SDK settings
    private var currentSdkSettings: customfit.ai.kotlinclient.core.model.SdkSettings? = null
    
    // Track whether SDK functionality is currently enabled
    private val isSdkFunctionalityEnabled = AtomicBoolean(true)
    
    // Track if a settings check is in progress
    private val isCheckingSettings = AtomicBoolean(false)
    
    // Configuration cache
    private val configCache = ConfigCache()
    
    // Flag to track if we've loaded from cache
    private val initialCacheLoadComplete = AtomicBoolean(false)
    
    // Init block to immediately load from cache on creation
    init {
        clientScope.launch {
            loadFromCache()
        }
    }
    
    /**
     * Load configuration from cache during initialization
     */
    private suspend fun loadFromCache() {
        if (initialCacheLoadComplete.get()) {
            return
        }
        
        Timber.i("Loading configuration from cache...")
        
        try {
            val (cachedConfig, cachedLastModified, cachedETag) = configCache.getCachedConfig()
            
            if (cachedConfig != null) {
                Timber.i("Found cached configuration with ${cachedConfig.size} entries")
                
                // Validate the cached config structure before using it
                val validConfig = cachedConfig.filterValues { value ->
                    when (value) {
                        is Map<*, *> -> value.containsKey("variation")
                        else -> {
                            Timber.w("Invalid cached config entry: ${value::class.simpleName}")
                            false
                        }
                    }
                }
                
                if (validConfig.isNotEmpty()) {
                    // Update the config map with validated cached values
                    updateConfigMap(validConfig)
                    
                    // Set metadata for future conditional requests
                    previousLastModified = cachedLastModified
                    previousETag = cachedETag
                    
                    Timber.i("Successfully initialized from cached configuration (${validConfig.size} valid entries)")
                } else {
                    Timber.w("No valid configuration entries found in cache")
                }
            } else {
                Timber.i("No cached configuration found, will wait for server response")
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to load configuration from cache: ${e.message}")
            // Clear corrupted cache on any error
            try {
                configCache.clearCache()
                Timber.i("Cleared corrupted cache")
            } catch (clearError: Exception) {
                Timber.e(clearError, "Failed to clear corrupted cache: ${clearError.message}")
            }
        }
        
        initialCacheLoadComplete.set(true)
    }
    
    override fun getAllFlags(): Map<String, Any> {
        // If SDK functionality is disabled, return an empty map
        if (!isSdkFunctionalityEnabled.get()) {
            Timber.d("getAllFlags: SDK functionality is disabled, returning empty map")
            return emptyMap()
        }
        
        val result = mutableMapOf<String, Any>()
        configMap.forEach { (key, configData) ->
            val data = configData as? Map<*, *>
            val variation = data?.get("variation")
            if (variation != null) {
                result[key] = variation
            }
        }
        return result
    }
    
    override fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        // If SDK functionality is disabled, return the fallback value
        if (!isSdkFunctionalityEnabled.get()) {
            Timber.d("getConfigValue: SDK functionality is disabled, returning fallback for key '$key'")
            return fallbackValue
        }
        
        val config = configMap[key]
        if (config == null) {
            Timber.warn { "No config found for key '$key'" }
            // Log the fallback value being used
            Timber.i("CONFIG VALUE: $key: $fallbackValue (using fallback)")
            return fallbackValue
        }
        if (config !is Map<*, *>) {
            Timber.warn { "Config for '$key' is not a map: $config" }
            // Log the fallback value being used
            Timber.i("CONFIG VALUE: $key: $fallbackValue (using fallback)")
            return fallbackValue
        }
        val variation = config["variation"]
        val result =
                if (variation != null && typeCheck(variation)) {
                    try {
                        // Log the actual config value
                        Timber.i("CONFIG VALUE: $key: $variation")
                        @Suppress("UNCHECKED_CAST")
                        variation as T
                    } catch (e: ClassCastException) {
                        Timber.warn {
                            "Type mismatch for '$key': expected ${fallbackValue!!::class.simpleName}, got ${variation::class.simpleName}"
                        }
                        // Log the fallback value being used
                        Timber.i("CONFIG VALUE: $key: $fallbackValue (using fallback due to type mismatch)")
                        fallbackValue
                    }
                } else {
                    Timber.warn { "No valid variation for '$key': $variation" }
                    // Log the fallback value being used
                    Timber.i("CONFIG VALUE: $key: $fallbackValue (using fallback)")
                    fallbackValue
                }
                
        // Push summary for tracking and analytics with required fields
        try {
            @Suppress("UNCHECKED_CAST")
            val configMapWithKey = HashMap<String, Any>(config as Map<String, Any>)
            
            // Add key to help with debugging
            configMapWithKey["key"] = key
            
            // Ensure required fields are present
            if (!configMapWithKey.containsKey("experience_id") && configMapWithKey.containsKey("id")) {
                configMapWithKey["experience_id"] = configMapWithKey["id"] as String
            }
            
            // Add default values for other required fields if missing
            if (!configMapWithKey.containsKey("config_id")) {
                configMapWithKey["config_id"] = configMapWithKey["id"] ?: "default-config-id"
            }
            
            if (!configMapWithKey.containsKey("variation_id")) {
                configMapWithKey["variation_id"] = configMapWithKey["id"] ?: "default-variation-id"
            }
            
            if (!configMapWithKey.containsKey("version")) {
                configMapWithKey["version"] = "1.0.0"
            }
            
            val summaryResult = summaryManager.pushSummary(configMapWithKey)
            summaryResult.onError { error ->
                Timber.w("Failed to push summary for key '$key': ${error.error}")
            }
            Timber.d("Summary pushed for key: $key")
        } catch (e: Exception) {
            Timber.e(e, "Exception while pushing summary for key '$key'")
        }
                
        return result
    }
    
    override suspend fun checkSdkSettings() {
        // Use a mutex to prevent concurrent SDK settings checks
        if (!sdkSettingsCheckMutex.tryLock()) {
            Timber.d("Skipping SDK settings check because another check is in progress")
            return
        }
        
        try {
            // Set the flag to indicate that a check is in progress
            isCheckingSettings.set(true)
            
            val timestamp = SimpleDateFormat("HH:mm:ss.SSS").format(Date())
            Timber.d("Starting SDK settings check at $timestamp")
            
            CoroutineUtils.withCircuitBreaker(
                operationKey = "sdk_settings_fetch",
                failureThreshold = 3,
                resetTimeoutMs = 30_000,
                fallback = Unit
            ) {
                CoroutineUtils.withTiming("checkSdkSettings") {
                    CoroutineUtils.withTimeoutOrNull(CFConstants.Network.SDK_SETTINGS_TIMEOUT_MS.toLong()) {
                        CoroutineUtils.withRetry(
                            maxAttempts = 3,
                            initialDelayMs = 100,
                            maxDelayMs = 1000,
                            retryOn = { it !is kotlinx.coroutines.CancellationException }
                        ) {
                            val sdkSettingsUrl = "${CFConstants.Api.SDK_SETTINGS_BASE_URL}${CFConstants.Api.SDK_SETTINGS_PATH_PATTERN.format(cfConfig.dimensionId)}"
                                
                            // Add more detailed logging for SDK settings API call
                            Timber.i("API POLL: Checking SDK settings at URL: $sdkSettingsUrl")
                                
                            // First try a lightweight HEAD request to check if there are changes
                            val metadataResult = configFetcher.fetchMetadata(sdkSettingsUrl)
                            
                            if (metadataResult !is CFResult.Success) {
                                Timber.w("SDK settings metadata fetch failed: ${metadataResult}")
                                Timber.warn { "Failed to fetch SDK settings metadata" }
                                return@withRetry Unit
                            }
                            
                            val metadata = metadataResult.data
                                
                            // Add more detailed logging about the received metadata
                            Timber.i("API POLL: Received metadata - Last-Modified: ${metadata[CFConstants.Http.HEADER_LAST_MODIFIED]}, ETag: ${metadata[CFConstants.Http.HEADER_ETAG]}")
                                
                            // Use metadata for conditional fetching
                            val currentLastModified = metadata["Last-Modified"]
                            val currentETag = metadata["ETag"]
                                
                            if (currentLastModified == null && currentETag == null) {
                                Timber.d("No Last-Modified or ETag headers in response")
                                return@withRetry Unit
                            }
                                
                            // *** IMPORTANT DEBUG SECTION ***
                            Timber.d("Last-Modified comparison: Current=$currentLastModified, Previous=$previousLastModified")
                            Timber.d("ETag comparison: Current=$currentETag, Previous=$previousETag")
                                
                            // Check if either Last-Modified or ETag has changed
                            val hasLastModifiedChanged = currentLastModified != null && currentLastModified != previousLastModified
                            val hasETagChanged = currentETag != null && currentETag != previousETag
                            val hasMetadataChanged = hasLastModifiedChanged || hasETagChanged
                                
                            // Only fetch full settings if:
                            // 1. This is the first check (no SDK settings yet)
                            // 2. Metadata has changed
                            val needsFullSettingsFetch = currentSdkSettings == null || hasMetadataChanged
                                
                            Timber.d("Will fetch full settings? $needsFullSettingsFetch")
                                
                            // If we need to fetch the full settings, make a GET request
                            if (needsFullSettingsFetch) {
                                // Use the GET request to get the full settings
                                Timber.i("API POLL: Fetching full SDK settings with GET: $sdkSettingsUrl")
                                val settingsResult = configFetcher.fetchSdkSettingsWithMetadata(sdkSettingsUrl)
                                    
                                if (settingsResult !is CFResult.Success) {
                                    Timber.w("SDK settings fetch failed: ${settingsResult}")
                                    Timber.warn { "Failed to fetch SDK settings" }
                                    return@withRetry Unit
                                }
                                    
                                // Use the fresh metadata and settings from the GET request
                                val (freshMetadata, freshSettings) = settingsResult.data
                                    
                                // Add more detailed logging about the received metadata
                                Timber.i("API POLL: Received metadata - Last-Modified: ${freshMetadata[CFConstants.Http.HEADER_LAST_MODIFIED]}, ETag: ${freshMetadata[CFConstants.Http.HEADER_ETAG]}")
                                    
                                // Store the settings
                                if (freshSettings != null) {
                                    currentSdkSettings = freshSettings
                                        
                                    // Check if account is enabled or SDK should be skipped
                                    val accountEnabled = freshSettings.cf_account_enabled
                                    val skipSdk = freshSettings.cf_skip_sdk
                                        
                                    if (!accountEnabled) {
                                        Timber.w("Account is disabled (cf_account_enabled=false). SDK functionality will be limited.")
                                        isSdkFunctionalityEnabled.set(false)
                                    } else if (skipSdk) {
                                        Timber.w("SDK should be skipped (cf_skip_sdk=true). SDK functionality will be limited.")
                                        isSdkFunctionalityEnabled.set(false)
                                    } else {
                                        // Account is enabled and SDK should not be skipped
                                        isSdkFunctionalityEnabled.set(true)
                                    }
                                }
                            } else {
                                // No need to fetch full settings, just use the metadata from HEAD
                                Timber.i("API POLL: Using existing SDK settings, no change detected")
                            }
                                
                            Timber.d("Will fetch new config? $hasMetadataChanged")

                            if (hasMetadataChanged) {
                                Timber.i("API POLL: Metadata changed - fetching new config")
                                Timber.i(
                                    "SDK settings changed: Previous Last-Modified=$previousLastModified, Current=$currentLastModified, Previous ETag=$previousETag, Current ETag=$currentETag"
                                )
                                    
                                // Only fetch configs if SDK functionality is enabled
                                if (isSdkFunctionalityEnabled.get()) {
                                    Timber.i("API POLL: Fetching new config due to metadata change")
                                    val configResult = configFetcher.fetchConfig(currentLastModified, currentETag)
                                        
                                    if (configResult !is CFResult.Success) {
                                        Timber.w("Config fetch failed: ${configResult}")
                                        Timber.warn {
                                            "Failed to fetch config with last-modified: $currentLastModified, etag: $currentETag"
                                        }
                                        return@withRetry Unit
                                    }
                                
                                    val newConfigs = configResult.data
                                    Timber.i("API POLL: Successfully fetched ${newConfigs.size} config entries")
                                    Timber.d("Config keys: ${newConfigs.keys}")
                                    Timber.d("Hero text if present: ${(newConfigs["hero_text"] as? Map<*, *>)?.get("variation")}")
                                        
                                    // Cache the successful response
                                    configCache.cacheConfig(newConfigs, currentLastModified, currentETag)
                                        
                                    // Update config map with new values
                                    updateConfigMap(newConfigs)
                                } else {
                                    Timber.i("API POLL: Skipping config fetch because SDK functionality is disabled")
                                }
                                    
                                // Store both metadata values for future comparisons regardless of SDK functionality status
                                previousLastModified = currentLastModified
                                previousETag = currentETag
                            } else {
                                Timber.i("API POLL: Metadata unchanged - skipping config fetch")
                            }
                        }
                    }
                        ?: Timber.warn { "SDK settings check timed out" }
                }
            }
            
            val endTimestamp = SimpleDateFormat("HH:mm:ss.SSS").format(Date())
            Timber.d("Completed SDK settings check at $endTimestamp")
        } finally {
            // Reset the flag to indicate that the check is complete
            isCheckingSettings.set(false)
            
            // Release the mutex to allow other checks to proceed
            sdkSettingsCheckMutex.unlock()
        }
    }
    
    override suspend fun forceRefresh() {
        Timber.d("Forcing config refresh by resetting metadata tracking")
        previousLastModified = null
        previousETag = null
        checkSdkSettings()
    }
    
    override fun startPeriodicSdkSettingsCheck(intervalMs: Long, initialCheck: Boolean) {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                errorMessage = "Failed to start periodic SDK settings check"
            ) {
                timerMutex.withLock {
                    // Cancel existing timer if any
                    sdkSettingsTimer?.cancel()
                    
                    // Check if background polling is disabled in config
                    if (cfConfig.disableBackgroundPolling) {
                        Timber.i("Background polling is disabled in config, skipping timer setup")
                        
                        // Perform immediate check only if requested, even if polling is disabled
                        if (initialCheck) {
                            clientScope.launch {
                                checkSdkSettings()
                            }
                        }
                        
                        return@withLock
                    }
                    
                    // Get the battery-aware polling interval
                    val batteryManager = customfit.ai.kotlinclient.utils.BatteryManager.getInstance()
                    val actualIntervalMs = batteryManager.getPollingInterval(
                        normalIntervalMs = intervalMs,
                        reducedIntervalMs = cfConfig.reducedPollingIntervalMs,
                        useReducedWhenLow = cfConfig.useReducedPollingWhenBatteryLow
                    )
                    
                    // Log the actual interval we're using
                    Timber.i("Starting periodic settings check with interval: $actualIntervalMs ms" +
                             (if (actualIntervalMs != intervalMs) " (adjusted for battery)" else ""))

                    // Create a new timer
                    sdkSettingsTimer = createStartTimer(actualIntervalMs) {
                        clientScope.launch {
                            // Skip this check if another one is already in progress
                            if (isCheckingSettings.get()) {
                                Timber.d("Skipping periodic SDK settings check because another check is already in progress")
                                return@launch
                            }
                            
                            CoroutineUtils.withErrorHandling(
                                errorMessage = "Periodic SDK settings check failed"
                            ) {
                                Timber.d("Periodic SDK settings check triggered by timer")
                                checkSdkSettings()
                            }
                            .onFailure { e ->
                                Timber.e(
                                    e,
                                    "Periodic SDK settings check failed: ${e.message}"
                                )
                            }
                        }
                    }

                    Timber.d("Started SDK settings check timer with interval $actualIntervalMs ms")

                    // Perform immediate check only if requested
                    if (initialCheck) {
                        clientScope.launch {
                            checkSdkSettings()
                        }
                    }
                }
            }
            .onFailure { e ->
                Timber.e(e, "Failed to start periodic SDK settings check: ${e.message}")
            }
        }
    }
    
    override suspend fun restartPeriodicSdkSettingsCheck(intervalMs: Long, initialCheck: Boolean) {
        timerMutex.withLock {
            // Cancel existing timer if any
            sdkSettingsTimer?.cancel()
            
            // Check if background polling is disabled in config
            if (cfConfig.disableBackgroundPolling) {
                Timber.i("Background polling is disabled in config, skipping timer restart")
                
                // Perform immediate check only if requested, even if polling is disabled
                if (initialCheck) {
                    clientScope.launch {
                        CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed immediate SDK settings check"
                        ) {
                            Timber.d(
                                "Performing immediate SDK settings check from restartPeriodicSdkSettingsCheck"
                            )
                            checkSdkSettings()
                        }
                        .onFailure { e ->
                            Timber.e(e, "Failed immediate SDK settings check: ${e.message}")
                        }
                    }
                }
                
                return@withLock
            }
            
            // Get the battery-aware polling interval
            val batteryManager = customfit.ai.kotlinclient.utils.BatteryManager.getInstance()
            val actualIntervalMs = batteryManager.getPollingInterval(
                normalIntervalMs = intervalMs,
                reducedIntervalMs = cfConfig.reducedPollingIntervalMs,
                useReducedWhenLow = cfConfig.useReducedPollingWhenBatteryLow
            )
            
            // Log the actual interval being used
            Timber.i("Restarting periodic settings check with interval: $actualIntervalMs ms" +
                     (if (actualIntervalMs != intervalMs) " (adjusted for battery)" else ""))

            // Create a new timer with updated interval
            sdkSettingsTimer = createRestartTimer(actualIntervalMs) {
                clientScope.launch {
                    // Skip this check if another one is already in progress
                    if (isCheckingSettings.get()) {
                        Timber.d("Skipping periodic SDK settings check because another check is already in progress")
                        return@launch
                    }
                    
                    CoroutineUtils.withErrorHandling(
                        errorMessage = "Periodic SDK settings check failed"
                    ) {
                        Timber.d("Periodic SDK settings check triggered by timer")
                        checkSdkSettings()
                    }
                    .onFailure { e ->
                        Timber.e(
                            e,
                            "Periodic SDK settings check failed: ${e.message}"
                        )
                    }
                }
            }
            Timber.d("Restarted periodic SDK settings check with interval $actualIntervalMs ms")

            // Perform immediate check only if requested
            if (initialCheck) {
                clientScope.launch {
                    CoroutineUtils.withErrorHandling(
                        errorMessage = "Failed immediate SDK settings check"
                    ) {
                        Timber.d(
                            "Performing immediate SDK settings check from restartPeriodicSdkSettingsCheck"
                        )
                        checkSdkSettings()
                    }
                    .onFailure { e ->
                        Timber.e(e, "Failed immediate SDK settings check: ${e.message}")
                    }
                }
            }
        }
    }
    
    override fun pausePolling() {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Failed to pause polling") {
                timerMutex.withLock {
                    sdkSettingsTimer?.cancel()
                    sdkSettingsTimer = null
                }
            }
            .onFailure { e -> Timber.e(e, "Failed to pause polling: ${e.message}") }
        }
    }
    
    override fun resumePolling() {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Failed to resume polling") {
                restartPeriodicSdkSettingsCheck(CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS)
            }
            .onFailure { e -> Timber.e(e, "Failed to resume polling: ${e.message}") }
        }
    }
    
    override suspend fun updateConfigMap(configs: Map<String, Any>) {
        Timber.i("🔄 updateConfigMap called with ${configs.size} configs")
        val updatedKeys = mutableSetOf<String>()
        
        synchronized(configMap) {
            Timber.i("🔄 Current configMap has ${configMap.size} entries")
            for (key in configs.keys) {
                val oldValue = configMap[key]
                val newValue = configs[key]
                if (!configMap.containsKey(key) || configMap[key] != configs[key]) {
                    updatedKeys.add(key)
                    Timber.i("🔄 Key '$key' marked as updated (old: $oldValue, new: $newValue)")
                } else {
                    Timber.d("🔄 Key '$key' unchanged")
                }
            }
            configMap.clear()
            configMap.putAll(configs)
            Timber.i("🔄 ConfigMap updated, now has ${configMap.size} entries")
        }

        // Log all updated keys and their new values
        Timber.i("🔄 Found ${updatedKeys.size} updated keys: $updatedKeys")
        if (updatedKeys.isNotEmpty()) {
            Timber.i("--- UPDATED CONFIG VALUES ---")
            for (key in updatedKeys) {
                val config = configs[key] as? Map<*, *>
                val variation = config?.get("variation")
                if (variation != null) {
                    Timber.i("CONFIG UPDATE: $key: $variation")
                    Timber.i("🔔 Notifying listeners for key: $key with value: $variation")
                    notifyListeners(key, variation)
                } else {
                    Timber.w("🔄 No variation found for key '$key', config: $config")
                }
            }
        } else {
            Timber.w("🔄 No updated keys found, listeners will not be notified")
        }
        
        Timber.i("Configs updated successfully with ${configs.size} entries")
    }
    
    override fun notifyListeners(key: String, variation: Any) {
        Timber.i("🔔 notifyListeners called for key: $key, value: $variation")
        
        // Don't notify listeners if SDK functionality is disabled
        if (!isSdkFunctionalityEnabled.get()) {
            Timber.d("notifyListeners: SDK functionality is disabled, skipping listener notifications for '$key'")
            return
        }
        
        Timber.i("🔔 SDK functionality enabled, proceeding with listener notifications")
        
        // Delegate to listener manager
        Timber.i("🔔 Calling listenerManager.notifyConfigListeners for key: $key")
        listenerManager.notifyConfigListeners(key, variation)
        
        // Notify feature flag listeners
        Timber.i("🔔 Calling listenerManager.notifyFeatureFlagListeners for key: $key")
        listenerManager.notifyFeatureFlagListeners(key, variation)
        
        // Notify all flags listeners with all flags
        Timber.i("🔔 Calling listenerManager.notifyAllFlagsListeners")
        listenerManager.notifyAllFlagsListeners(getAllFlags())
        
        Timber.i("🔔 Completed all listener notifications for key: $key")
    }
    
    override fun shutdown() {
        sdkSettingsTimer?.cancel()
        sdkSettingsTimer = null
    }
    
    /**
     * Creates a timer for starting periodic SDK settings checks
     */
    private fun createStartTimer(
        intervalMs: Long,
        action: TimerTask.() -> Unit
    ): java.util.Timer {
        return java.util.Timer("SDKTimerStartCheck-${System.currentTimeMillis()}", true).apply {
            schedule(object : TimerTask() {
                override fun run() {
                    action()
                }
            }, intervalMs, intervalMs)
        }
    }

    /**
     * Creates a timer for restarting periodic SDK settings checks
     */
    private fun createRestartTimer(
        intervalMs: Long,
        action: TimerTask.() -> Unit
    ): java.util.Timer {
        return java.util.Timer("SDKTimerRestartCheck-${System.currentTimeMillis()}", true).apply {
            schedule(object : TimerTask() {
                override fun run() {
                    action()
                }
            }, intervalMs, intervalMs)
        }
    }
} 