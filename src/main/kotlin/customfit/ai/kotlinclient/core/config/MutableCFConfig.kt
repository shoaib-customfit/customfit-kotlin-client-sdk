package customfit.ai.kotlinclient.core.config

import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.core.config.CFConfig
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** A wrapper around CFConfig that allows for dynamic updates to configuration values at runtime. */
class MutableCFConfig(initConfig: CFConfig) {

    private val mutex = Mutex()
    private var _config = initConfig

    /** Get the current immutable configuration */
    val config: CFConfig
        get() = _config

    /** Listeners that will be notified when config values change */
    private val configChangeListeners = CopyOnWriteArrayList<ConfigChangeListener>()

    // Delegate properties for common access
    val clientKey: String
        get() = _config.clientKey
    val dimensionId: String?
        get() = _config.dimensionId
    val offlineMode: Boolean
        get() = _config.offlineMode
    val eventsQueueSize: Int
        get() = _config.eventsQueueSize
    val eventsFlushTimeSeconds: Int
        get() = _config.eventsFlushTimeSeconds
    val eventsFlushIntervalMs: Long
        get() = _config.eventsFlushIntervalMs
    val summariesQueueSize: Int
        get() = _config.summariesQueueSize
    val summariesFlushTimeSeconds: Int
        get() = _config.summariesFlushTimeSeconds
    val summariesFlushIntervalMs: Long
        get() = _config.summariesFlushIntervalMs
    val sdkSettingsCheckIntervalMs: Long
        get() = _config.sdkSettingsCheckIntervalMs
    val networkConnectionTimeoutMs: Int
        get() = _config.networkConnectionTimeoutMs
    val networkReadTimeoutMs: Int
        get() = _config.networkReadTimeoutMs
    val loggingEnabled: Boolean
        get() = _config.loggingEnabled
    val debugLoggingEnabled: Boolean
        get() = _config.debugLoggingEnabled
    val autoEnvAttributesEnabled: Boolean
        get() = _config.autoEnvAttributesEnabled

    // Background polling settings
    val disableBackgroundPolling: Boolean
        get() = _config.disableBackgroundPolling
    val backgroundPollingIntervalMs: Long
        get() = _config.backgroundPollingIntervalMs
    val useReducedPollingWhenBatteryLow: Boolean
        get() = _config.useReducedPollingWhenBatteryLow
    val reducedPollingIntervalMs: Long
        get() = _config.reducedPollingIntervalMs
    val maxStoredEvents: Int
        get() = _config.maxStoredEvents

    /**
     * Updates the offline mode setting
     *
     * @param enabled true to enable offline mode, false to disable
     */
    suspend fun setOfflineMode(enabled: Boolean) = updateConfig {
        _config.copy(offlineMode = enabled)
    }

    /**
     * Updates the events flush interval
     *
     * @param intervalMs the new interval in milliseconds
     */
    suspend fun setEventsFlushIntervalMs(intervalMs: Long) = updateConfig {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        _config.copy(eventsFlushIntervalMs = intervalMs)
    }

    /**
     * Updates the summaries flush interval
     *
     * @param intervalMs the new interval in milliseconds
     */
    suspend fun setSummariesFlushIntervalMs(intervalMs: Long) = updateConfig {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        _config.copy(summariesFlushIntervalMs = intervalMs)
    }

    /**
     * Updates the SDK settings check interval
     *
     * @param intervalMs the new interval in milliseconds
     */
    suspend fun setSdkSettingsCheckIntervalMs(intervalMs: Long) = updateConfig {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        _config.copy(sdkSettingsCheckIntervalMs = intervalMs)
    }

    /**
     * Updates the network connection timeout
     *
     * @param timeoutMs the new timeout in milliseconds
     */
    suspend fun setNetworkConnectionTimeoutMs(timeoutMs: Int) = updateConfig {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        _config.copy(networkConnectionTimeoutMs = timeoutMs)
    }

    /**
     * Updates the network read timeout
     *
     * @param timeoutMs the new timeout in milliseconds
     */
    suspend fun setNetworkReadTimeoutMs(timeoutMs: Int) = updateConfig {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        _config.copy(networkReadTimeoutMs = timeoutMs)
    }

    /**
     * Updates the logging enabled setting
     *
     * @param enabled true to enable logging, false to disable
     */
    suspend fun setLoggingEnabled(enabled: Boolean) = updateConfig {
        _config.copy(loggingEnabled = enabled)
    }

    /**
     * Updates the debug logging enabled setting
     *
     * @param enabled true to enable debug logging, false to disable
     */
    suspend fun setDebugLoggingEnabled(enabled: Boolean) = updateConfig {
        _config.copy(debugLoggingEnabled = enabled)
    }

    /**
     * Updates the background polling enabled setting
     *
     * @param disable true to disable background polling, false to enable
     */
    suspend fun setDisableBackgroundPolling(disable: Boolean) = updateConfig {
        _config.copy(disableBackgroundPolling = disable)
    }

    /**
     * Updates the background polling interval
     *
     * @param intervalMs the new interval in milliseconds
     */
    suspend fun setBackgroundPollingIntervalMs(intervalMs: Long) = updateConfig {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        _config.copy(backgroundPollingIntervalMs = intervalMs)
    }

    /**
     * Updates whether to use reduced polling when battery is low
     *
     * @param useReduced true to reduce polling on low battery
     */
    suspend fun setUseReducedPollingWhenBatteryLow(useReduced: Boolean) = updateConfig {
        _config.copy(useReducedPollingWhenBatteryLow = useReduced)
    }

    /**
     * Updates the reduced polling interval used when battery is low
     *
     * @param intervalMs the new interval in milliseconds
     */
    suspend fun setReducedPollingIntervalMs(intervalMs: Long) = updateConfig {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        _config.copy(reducedPollingIntervalMs = intervalMs)
    }

    /**
     * Updates the maximum number of events stored when offline
     *
     * @param maxEvents the maximum number of events to store
     */
    suspend fun setMaxStoredEvents(maxEvents: Int) = updateConfig {
        require(maxEvents > 0) { "Max stored events must be greater than 0" }
        _config.copy(maxStoredEvents = maxEvents)
    }

    /**
     * Updates the auto environment attributes enabled setting
     *
     * @param enabled true to enable automatic environment attribute collection
     */
    suspend fun setAutoEnvAttributesEnabled(enabled: Boolean) = updateConfig {
        _config.copy(autoEnvAttributesEnabled = enabled)
    }

    /**
     * Generic method to update the config with a new value
     *
     * @param updateFn a function that returns the updated config
     */
    private suspend fun updateConfig(updateFn: () -> CFConfig) {
        mutex.withLock {
            val oldConfig = _config
            val newConfig = updateFn()
            _config = newConfig

            // Notify listeners
            notifyListeners(oldConfig, newConfig)
        }
    }

    /**
     * Add a listener that will be notified when config values change
     *
     * @param listener the listener to add
     */
    fun addConfigChangeListener(listener: ConfigChangeListener) {
        configChangeListeners.add(listener)
    }

    /**
     * Remove a previously added config change listener
     *
     * @param listener the listener to remove
     */
    fun removeConfigChangeListener(listener: ConfigChangeListener) {
        configChangeListeners.remove(listener)
    }

    /**
     * Notify all listeners of a config change
     *
     * @param oldConfig the previous config
     * @param newConfig the new config
     */
    private fun notifyListeners(oldConfig: CFConfig, newConfig: CFConfig) {
        for (listener in configChangeListeners) {
            try {
                listener.onConfigChanged(oldConfig, newConfig)
            } catch (e: Exception) {
                Timber.e(e, "Error notifying config change listener: ${e.message}")
            }
        }
    }

    /** Interface for objects that will be notified when config values change */
    interface ConfigChangeListener {
        /**
         * Called when a configuration value changes
         *
         * @param oldConfig the previous config
         * @param newConfig the new config
         */
        fun onConfigChanged(oldConfig: CFConfig, newConfig: CFConfig)
    }
}
