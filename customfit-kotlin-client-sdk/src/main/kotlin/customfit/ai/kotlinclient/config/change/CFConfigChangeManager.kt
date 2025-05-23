package customfit.ai.kotlinclient.config.change

import customfit.ai.kotlinclient.logging.Timber
import java.util.concurrent.ConcurrentHashMap

/**
 * Interface for observing configuration changes
 */
interface CFConfigChangeObserver {
    /**
     * Called when a configuration changes
     * @param configId The ID of the configuration that changed
     */
    fun onChanged(configId: String)
}

/**
 * Manages configuration change observers and notifies them of changes
 */
object CFConfigChangeManager {
    private val configChangeObservers = ConcurrentHashMap<String, MutableList<CFConfigChangeObserver>>()

    /**
     * Registers an observer for configuration changes
     * @param configId The ID of the configuration to observe
     * @param observer The observer to register
     */
    @Synchronized
    fun registerConfigChange(configId: String, observer: CFConfigChangeObserver) {
        try {
            configChangeObservers.computeIfAbsent(configId) { mutableListOf() }.add(observer)
            Timber.d("Registered observer for config: $configId")
        } catch (e: Exception) {
            Timber.w("Exception in registerConfigChange: ${e.message}")
        }
    }

    /**
     * Unregisters an observer for configuration changes
     * @param configId The ID of the configuration to stop observing
     * @param observer The observer to unregister
     */
    @Synchronized
    fun unregisterConfigChange(configId: String, observer: CFConfigChangeObserver) {
        try {
            configChangeObservers[configId]?.remove(observer)
            Timber.d("Unregistered observer for config: $configId")
        } catch (e: Exception) {
            Timber.w("Exception in unregisterConfigChange: ${e.message}")
        }
    }

    /**
     * Notifies all observers of configuration changes
     * @param newConfigs The new configuration values
     * @param oldConfigs The old configuration values
     */
    @Synchronized
    fun notifyObservers(newConfigs: Map<String, Any>?, oldConfigs: Map<String, Any>?) {
        if (configChangeObservers.isNotEmpty()) {
            configChangeObservers.forEach { (configId, observers) ->
                if (observers.isNotEmpty()) {
                    val newConfig = newConfigs?.get(configId)
                    val oldConfig = oldConfigs?.get(configId)
                    
                    if (shouldNotify(newConfig, oldConfig)) {
                        observers.forEach { observer ->
                            try {
                                observer.onChanged(configId)
                                Timber.d("Notified observer for config: $configId")
                            } catch (e: Exception) {
                                Timber.w("Exception in callback-handler: ${e.message}")
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     * Determines if observers should be notified based on configuration changes
     */
    private fun shouldNotify(newConfig: Any?, oldConfig: Any?): Boolean {
        return when {
            newConfig != null && oldConfig != null -> {
                // Compare the objects directly
                newConfig != oldConfig
            }
            newConfig != null && oldConfig == null -> true
            newConfig == null && oldConfig != null -> true
            else -> false
        }
    }

    /**
     * Clears all registered observers
     */
    @Synchronized
    fun clearObservers() {
        configChangeObservers.clear()
        Timber.d("Cleared all configuration observers")
    }
} 