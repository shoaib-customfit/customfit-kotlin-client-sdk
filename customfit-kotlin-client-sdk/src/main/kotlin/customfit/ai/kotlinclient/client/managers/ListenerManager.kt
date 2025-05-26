package customfit.ai.kotlinclient.client.managers

import customfit.ai.kotlinclient.client.listener.AllFlagsListener
import customfit.ai.kotlinclient.client.listener.FeatureFlagChangeListener
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.network.connection.ConnectionInformation
import customfit.ai.kotlinclient.network.connection.ConnectionStatus
import customfit.ai.kotlinclient.network.connection.ConnectionStatusListener
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Interface for managing listeners
 */
interface ListenerManager {
    /**
     * Add a listener for a specific configuration
     */
    fun <T : Any> addConfigListener(key: String, listener: (T) -> Unit)
    
    /**
     * Remove a listener for a specific configuration
     */
    fun <T : Any> removeConfigListener(key: String, listener: (T) -> Unit)
    
    /**
     * Remove all listeners for a specific configuration
     */
    fun clearConfigListeners(key: String)
    
    /**
     * Add a listener for feature flag changes
     */
    fun registerFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener)
    
    /**
     * Remove a listener for feature flag changes
     */
    fun unregisterFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener)
    
    /**
     * Add a listener for all flags changes
     */
    fun registerAllFlagsListener(listener: AllFlagsListener)
    
    /**
     * Remove a listener for all flags changes
     */
    fun unregisterAllFlagsListener(listener: AllFlagsListener)
    
    /**
     * Add a connection status listener
     */
    fun addConnectionStatusListener(listener: ConnectionStatusListener)
    
    /**
     * Remove a connection status listener
     */
    fun removeConnectionStatusListener(listener: ConnectionStatusListener)
    
    /**
     * Notify config listeners about a value change
     */
    fun notifyConfigListeners(key: String, value: Any)
    
    /**
     * Notify feature flag listeners about a value change
     */
    fun notifyFeatureFlagListeners(key: String, value: Any)
    
    /**
     * Notify all flags listeners
     */
    fun notifyAllFlagsListeners(flags: Map<String, Any>)
    
    /**
     * Notify connection status listeners
     */
    fun notifyConnectionStatusListeners(status: ConnectionStatus, info: ConnectionInformation)
    
    /**
     * Clear all listeners
     */
    fun clearAllListeners()
}

/**
 * Implementation of ListenerManager that handles all types of listeners
 */
class ListenerManagerImpl : ListenerManager {
    // Listener collections
    private val configListeners = ConcurrentHashMap<String, MutableList<(Any) -> Unit>>()
    private val featureFlagListeners = ConcurrentHashMap<String, MutableList<FeatureFlagChangeListener>>()
    private val allFlagsListeners = ConcurrentHashMap.newKeySet<AllFlagsListener>()
    private val connectionStatusListeners = CopyOnWriteArrayList<ConnectionStatusListener>()
    
    override fun <T : Any> addConfigListener(key: String, listener: (T) -> Unit) {
        @Suppress("UNCHECKED_CAST")
        configListeners.getOrPut(key) { mutableListOf() }.add(listener as (Any) -> Unit)
        Timber.d("Added listener for key: $key")
    }
    
    override fun <T : Any> removeConfigListener(key: String, listener: (T) -> Unit) {
        @Suppress("UNCHECKED_CAST") 
        configListeners[key]?.remove(listener as (Any) -> Unit)
        Timber.d("Removed listener for key: $key")
    }
    
    override fun clearConfigListeners(key: String) {
        configListeners.remove(key)
        Timber.d("Cleared all listeners for key: $key")
    }
    
    override fun registerFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        featureFlagListeners.computeIfAbsent(flagKey) { mutableListOf() }.add(listener)
        Timber.d("Registered feature flag listener for key: $flagKey")
    }
    
    override fun unregisterFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        featureFlagListeners[flagKey]?.remove(listener as Any)
        Timber.d("Unregistered feature flag listener for key: $flagKey")
    }
    
    override fun registerAllFlagsListener(listener: AllFlagsListener) {
        allFlagsListeners.add(listener)
        Timber.d("Registered all flags listener")
    }
    
    override fun unregisterAllFlagsListener(listener: AllFlagsListener) {
        allFlagsListeners.remove(listener)
        Timber.d("Unregistered all flags listener")
    }
    
    override fun addConnectionStatusListener(listener: ConnectionStatusListener) {
        connectionStatusListeners.add(listener)
        Timber.d("Added connection status listener")
    }
    
    override fun removeConnectionStatusListener(listener: ConnectionStatusListener) {
        connectionStatusListeners.remove(listener)
        Timber.d("Removed connection status listener")
    }
    
    override fun notifyConfigListeners(key: String, value: Any) {
        Timber.i("🔔 ListenerManager.notifyConfigListeners called for key: $key, value: $value")
        val listeners = configListeners[key]
        Timber.i("🔔 Found ${listeners?.size ?: 0} listeners for key: $key")
        
        listeners?.forEach { listener ->
            try {
                Timber.i("🔔 Invoking listener for key: $key with value: $value")
                listener(value)
                Timber.i("🔔 Successfully invoked listener for key: $key")
            } catch (e: Exception) {
                Timber.e(e, "Error notifying config listener for key $key: ${e.message}")
            }
        }
        
        if (listeners == null || listeners.isEmpty()) {
            Timber.w("🔔 No listeners found for key: $key")
        }
    }
    
    override fun notifyFeatureFlagListeners(key: String, value: Any) {
        featureFlagListeners[key]?.forEach { listener ->
            try {
                listener.onFeatureFlagChange(key, value)
            } catch (e: Exception) {
                Timber.e(e, "Error notifying feature flag listener for key $key: ${e.message}")
            }
        }
    }
    
    override fun notifyAllFlagsListeners(flags: Map<String, Any>) {
        if (allFlagsListeners.isNotEmpty()) {
            allFlagsListeners.forEach { listener ->
                try {
                    listener.onFlagsChange(flags)
                } catch (e: Exception) {
                    Timber.e(e, "Error notifying all flags listener: ${e.message}")
                }
            }
        }
    }
    
    override fun notifyConnectionStatusListeners(status: ConnectionStatus, info: ConnectionInformation) {
        for (listener in connectionStatusListeners) {
            try {
                listener.onConnectionStatusChanged(status, info)
            } catch (e: Exception) {
                Timber.e(e, "Error notifying connection status listener: ${e.message}")
            }
        }
    }
    
    override fun clearAllListeners() {
        configListeners.clear()
        featureFlagListeners.clear()
        allFlagsListeners.clear()
        connectionStatusListeners.clear()
        Timber.d("Cleared all listeners")
    }
} 