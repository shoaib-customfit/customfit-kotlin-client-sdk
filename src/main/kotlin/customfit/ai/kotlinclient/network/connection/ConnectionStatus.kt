package customfit.ai.kotlinclient.network

/**
 * Represents the current connection status of the SDK.
 */
enum class ConnectionStatus {
    /**
     * SDK is connected and can communicate with the server.
     */
    CONNECTED,
    
    /**
     * SDK is currently in the process of connecting or reconnecting.
     */
    CONNECTING,
    
    /**
     * SDK is disconnected from the server due to network issues.
     */
    DISCONNECTED,
    
    /**
     * SDK is intentionally in offline mode.
     */
    OFFLINE
}

/**
 * Provides detailed information about the connection state.
 */
data class ConnectionInformation(
    /**
     * The current connection status.
     */
    val status: ConnectionStatus,
    
    /**
     * When true, indicates the SDK was put in offline mode intentionally.
     */
    val isOfflineMode: Boolean,
    
    /**
     * Last connection error message, if any.
     */
    val lastError: String? = null,
    
    /**
     * Timestamp of the last successful connection in milliseconds.
     */
    val lastSuccessfulConnectionTimeMs: Long = 0,
    
    /**
     * Number of consecutive connection failures.
     */
    val failureCount: Int = 0,
    
    /**
     * Time of the next reconnection attempt in milliseconds.
     */
    val nextReconnectTimeMs: Long = 0
)

/**
 * Interface for objects that will be notified of connection status changes.
 */
interface ConnectionStatusListener {
    /**
     * Called when the connection status changes.
     *
     * @param newStatus The new connection status
     * @param info Detailed connection information
     */
    fun onConnectionStatusChanged(newStatus: ConnectionStatus, info: ConnectionInformation)
} 