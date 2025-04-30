package customfit.ai.kotlinclient.client.managers

import customfit.ai.kotlinclient.constants.CFConstants
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.network.ConfigFetcher
import customfit.ai.kotlinclient.client.managers.ListenerManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.ConcurrentHashMap

/**
 * Interface for managing config and feature flag functionality
 */
interface ConfigManager {
    /** Get all feature flags with their current values */
    fun getAllFlags(): Map<String, Any>
    
    /** Get a specific config value */
    fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T
    
    /** Check and update SDK settings */
    suspend fun checkSdkSettings()
    
    /** Start periodic SDK settings check */
    fun startPeriodicSdkSettingsCheck(intervalMs: Long, initialCheck: Boolean = true)
    
    /** Restart periodic SDK settings check */
    suspend fun restartPeriodicSdkSettingsCheck(intervalMs: Long, initialCheck: Boolean = true)
    
    /** Pause polling */
    fun pausePolling()
    
    /** Resume polling */
    fun resumePolling()
    
    /** Update a config value and notify listeners */
    suspend fun updateConfigMap(configs: Map<String, Any>)
    
    /** Notify listeners when a config value changes */
    fun notifyListeners(key: String, variation: Any)
    
    /** Shutdown and clean up resources */
    fun shutdown()
}

/**
 * Implementation of ConfigManager that handles config fetching and processing
 */
class ConfigManagerImpl(
    private val configFetcher: ConfigFetcher,
    private val clientScope: CoroutineScope,
    private val listenerManager: ListenerManager,
    private val cfConfig: customfit.ai.kotlinclient.config.core.CFConfig
) : ConfigManager {
    
    private val configMap: MutableMap<String, Any> = ConcurrentHashMap()
    private var previousLastModified: String? = null
    private var sdkSettingsTimer: java.util.Timer? = null
    private val timerMutex = kotlinx.coroutines.sync.Mutex()
    
    override fun getAllFlags(): Map<String, Any> {
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
        val config = configMap[key]
        if (config == null) {
            customfit.ai.kotlinclient.logging.Timber.warn { "No config found for key '$key'" }
            return fallbackValue
        }
        if (config !is Map<*, *>) {
            customfit.ai.kotlinclient.logging.Timber.warn { "Config for '$key' is not a map: $config" }
            return fallbackValue
        }
        val variation = config["variation"]
        val result =
                if (variation != null && typeCheck(variation)) {
                    try {
                        variation as T
                    } catch (e: ClassCastException) {
                        customfit.ai.kotlinclient.logging.Timber.warn {
                            "Type mismatch for '$key': expected ${fallbackValue!!::class.simpleName}, got ${variation::class.simpleName}"
                        }
                        fallbackValue
                    }
                } else {
                    customfit.ai.kotlinclient.logging.Timber.warn { "No valid variation for '$key': $variation" }
                    fallbackValue
                }
        return result
    }
    
    override suspend fun checkSdkSettings() {
        customfit.ai.kotlinclient.utils.CoroutineUtils.withCircuitBreaker(
                operationKey = "sdk_settings_fetch",
                failureThreshold = 3,
                resetTimeoutMs = 30_000,
                fallback = Unit
        ) {
            customfit.ai.kotlinclient.utils.CoroutineUtils.withTiming("checkSdkSettings") {
                customfit.ai.kotlinclient.utils.CoroutineUtils.withTimeoutOrNull(customfit.ai.kotlinclient.constants.CFConstants.Network.SDK_SETTINGS_TIMEOUT_MS.toLong()) {
                    customfit.ai.kotlinclient.utils.CoroutineUtils.withRetry(
                            maxAttempts = 3,
                            initialDelayMs = 100,
                            maxDelayMs = 1000,
                            retryOn = { it !is kotlinx.coroutines.CancellationException }
                    ) {
                        val sdkSettingsUrl = "${CFConstants.Api.SDK_SETTINGS_BASE_URL}${CFConstants.Api.SDK_SETTINGS_PATH_PATTERN.format(cfConfig.dimensionId)}"
                        val metadataResult = configFetcher.fetchMetadata(sdkSettingsUrl)
                        
                        if (metadataResult !is CFResult.Success) {
                            customfit.ai.kotlinclient.logging.Timber.warn { "Failed to fetch SDK settings metadata" }
                            return@withRetry Unit
                        }
                        
                        val metadata = metadataResult.data
                        val currentLastModified = metadata["Last-Modified"] ?: return@withRetry Unit

                        if (currentLastModified != previousLastModified) {
                            customfit.ai.kotlinclient.logging.Timber.i(
                                    "SDK settings changed: Previous=$previousLastModified, Current=$currentLastModified"
                            )
                            val configResult = configFetcher.fetchConfig(currentLastModified)
                            
                            if (configResult !is CFResult.Success) {
                                customfit.ai.kotlinclient.logging.Timber.warn {
                                    "Failed to fetch config with last-modified: $currentLastModified"
                                }
                                return@withRetry Unit
                            }
                            
                            val newConfigs = configResult.data
                            updateConfigMap(newConfigs)
                            previousLastModified = currentLastModified
                        } else {
                            customfit.ai.kotlinclient.logging.Timber.d("No change in SDK settings")
                        }
                    }
                }
                        ?: customfit.ai.kotlinclient.logging.Timber.warn { "SDK settings check timed out" }
            }
        }
    }
    
    override fun startPeriodicSdkSettingsCheck(intervalMs: Long, initialCheck: Boolean) {
        clientScope.launch {
            customfit.ai.kotlinclient.utils.CoroutineUtils.withErrorHandling(
                    errorMessage = "Failed to start periodic SDK settings check"
            ) {
                timerMutex.withLock {
                    // Cancel existing timer if any
                    sdkSettingsTimer?.cancel()

                    // Create a new timer
                    sdkSettingsTimer =
                            kotlin.concurrent.fixedRateTimer(
                                    "SdkSettingsCheck",
                                    daemon = true,
                                    initialDelay = intervalMs,
                                    period = intervalMs
                            ) {
                                clientScope.launch {
                                    customfit.ai.kotlinclient.utils.CoroutineUtils.withErrorHandling(
                                            errorMessage = "Periodic SDK settings check failed"
                                    ) {
                                        customfit.ai.kotlinclient.logging.Timber.d("Periodic SDK settings check triggered by timer")
                                        checkSdkSettings()
                                    }
                                    .onFailure { e ->
                                        customfit.ai.kotlinclient.logging.Timber.e(
                                                e,
                                                "Periodic SDK settings check failed: ${e.message}"
                                        )
                                    }
                                }
                            }

                    customfit.ai.kotlinclient.logging.Timber.d("Started SDK settings check timer with interval $intervalMs ms")

                    // Perform immediate check only if requested
                    if (initialCheck) {
                        clientScope.launch {
                            checkSdkSettings()
                        }
                    }
                }
            }
            .onFailure { e ->
                customfit.ai.kotlinclient.logging.Timber.e(e, "Failed to start periodic SDK settings check: ${e.message}")
            }
        }
    }
    
    override suspend fun restartPeriodicSdkSettingsCheck(intervalMs: Long, initialCheck: Boolean) {
        timerMutex.withLock {
            // Cancel existing timer if any
            sdkSettingsTimer?.cancel()

            // Create a new timer with updated interval
            sdkSettingsTimer =
                    kotlin.concurrent.fixedRateTimer(
                            "SdkSettingsCheck",
                            daemon = true,
                            initialDelay = intervalMs,
                            period = intervalMs
                    ) {
                        clientScope.launch {
                            customfit.ai.kotlinclient.utils.CoroutineUtils.withErrorHandling(
                                    errorMessage = "Periodic SDK settings check failed"
                            ) {
                                customfit.ai.kotlinclient.logging.Timber.d("Periodic SDK settings check triggered by timer")
                                checkSdkSettings()
                            }
                            .onFailure { e ->
                                customfit.ai.kotlinclient.logging.Timber.e(
                                        e,
                                        "Periodic SDK settings check failed: ${e.message}"
                                )
                            }
                        }
                    }
            customfit.ai.kotlinclient.logging.Timber.d("Restarted periodic SDK settings check with interval $intervalMs ms")

            // Perform immediate check only if requested
            if (initialCheck) {
                clientScope.launch {
                    customfit.ai.kotlinclient.utils.CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed immediate SDK settings check"
                    ) {
                        customfit.ai.kotlinclient.logging.Timber.d(
                                "Performing immediate SDK settings check from restartPeriodicSdkSettingsCheck"
                        )
                        checkSdkSettings()
                    }
                    .onFailure { e ->
                        customfit.ai.kotlinclient.logging.Timber.e(e, "Failed immediate SDK settings check: ${e.message}")
                    }
                }
            }
        }
    }
    
    override fun pausePolling() {
        clientScope.launch {
            customfit.ai.kotlinclient.utils.CoroutineUtils.withErrorHandling(errorMessage = "Failed to pause polling") {
                timerMutex.withLock {
                    sdkSettingsTimer?.cancel()
                    sdkSettingsTimer = null
                }
            }
            .onFailure { e -> customfit.ai.kotlinclient.logging.Timber.e(e, "Failed to pause polling: ${e.message}") }
        }
    }
    
    override fun resumePolling() {
        clientScope.launch {
            customfit.ai.kotlinclient.utils.CoroutineUtils.withErrorHandling(errorMessage = "Failed to resume polling") {
                restartPeriodicSdkSettingsCheck(CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS)
            }
            .onFailure { e -> customfit.ai.kotlinclient.logging.Timber.e(e, "Failed to resume polling: ${e.message}") }
        }
    }
    
    override suspend fun updateConfigMap(configs: Map<String, Any>) {
        val updatedKeys = mutableSetOf<String>()
        
        synchronized(configMap) {
            for (key in configs.keys) {
                if (!configMap.containsKey(key) || configMap[key] != configs[key]) {
                    updatedKeys.add(key)
                }
            }
            configMap.clear()
            configMap.putAll(configs)
        }

        for (key in updatedKeys) {
            val config = configs[key] as? Map<*, *>
            val variation = config?.get("variation")
            if (variation != null) {
                notifyListeners(key, variation)
            }
        }
        customfit.ai.kotlinclient.logging.Timber.i("Configs updated successfully with ${configs.size} entries")
    }
    
    override fun notifyListeners(key: String, variation: Any) {
        // Delegate to listener manager
        listenerManager.notifyConfigListeners(key, variation)
        
        // Notify feature flag listeners
        listenerManager.notifyFeatureFlagListeners(key, variation)
        
        // Notify all flags listeners with all flags
        listenerManager.notifyAllFlagsListeners(getAllFlags())
    }
    
    override fun shutdown() {
        sdkSettingsTimer?.cancel()
        sdkSettingsTimer = null
    }
} 