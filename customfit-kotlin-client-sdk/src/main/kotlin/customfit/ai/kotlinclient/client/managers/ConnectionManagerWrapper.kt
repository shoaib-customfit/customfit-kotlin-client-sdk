package customfit.ai.kotlinclient.client.managers

import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.network.connection.ConnectionInformation
import customfit.ai.kotlinclient.network.connection.ConnectionManager
import customfit.ai.kotlinclient.network.connection.ConnectionStatus
import customfit.ai.kotlinclient.network.connection.ConnectionStatusListener

/**
 * Interface for managing network connectivity
 */
interface ConnectionManagerInterface {
    /**
     * Add a connection status listener
     */
    fun addConnectionStatusListener(listener: ConnectionStatusListener)
    
    /**
     * Remove a connection status listener
     */
    fun removeConnectionStatusListener(listener: ConnectionStatusListener)
    
    /**
     * Get the current connection information
     */
    fun getConnectionInformation(): ConnectionInformation
    
    /**
     * Set offline mode
     */
    fun setOfflineMode(offlineMode: Boolean)
    
    /**
     * Check if in offline mode
     */
    fun isOfflineMode(): Boolean
    
    /**
     * Shutdown the connection manager
     */
    fun shutdown()
}

/**
 * Wrapper around the existing ConnectionManager to fit into the modular architecture
 */
class ConnectionManagerWrapper(config: CFConfig) : ConnectionManagerInterface {
    private val connectionManager = ConnectionManager(config) {
        Timber.d("Connection callback triggered")
        // The connection callback is now handled via listeners
    }
    
    override fun addConnectionStatusListener(listener: ConnectionStatusListener) {
        connectionManager.addConnectionStatusListener(listener)
    }
    
    override fun removeConnectionStatusListener(listener: ConnectionStatusListener) {
        connectionManager.removeConnectionStatusListener(listener)
    }
    
    override fun getConnectionInformation(): ConnectionInformation {
        return connectionManager.getConnectionInformation()
    }
    
    override fun setOfflineMode(offlineMode: Boolean) {
        connectionManager.setOfflineMode(offlineMode)
        Timber.d("Offline mode set to $offlineMode")
    }
    
    override fun isOfflineMode(): Boolean {
        return connectionManager.isOffline()
    }
    
    override fun shutdown() {
        connectionManager.shutdown()
    }
} 