package customfit.ai.kotlinclient.network.connection

/** Provides detailed information about the connection state. */
data class ConnectionInformation(
        /** The current connection status. */
        val status: ConnectionStatus,

        /** When true, indicates the SDK was put in offline mode intentionally. */
        val isOfflineMode: Boolean,

        /** Last connection error message, if any. */
        val lastError: String? = null,

        /** Timestamp of the last successful connection in milliseconds. */
        val lastSuccessfulConnectionTimeMs: Long = 0,

        /** Number of consecutive connection failures. */
        val failureCount: Int = 0,

        /** Time of the next reconnection attempt in milliseconds. */
        val nextReconnectTimeMs: Long = 0
)
