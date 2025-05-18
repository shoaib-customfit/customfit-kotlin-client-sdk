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
    
    /** Force config refresh regardless of Last-Modified header */
    suspend fun forceRefresh()
} 