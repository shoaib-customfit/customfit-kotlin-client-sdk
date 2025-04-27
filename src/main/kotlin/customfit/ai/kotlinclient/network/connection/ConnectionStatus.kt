package customfit.ai.kotlinclient.network.connection

/** Represents the current connection status of the SDK. */
enum class ConnectionStatus {
    /** SDK is connected and can communicate with the server. */
    CONNECTED,

    /** SDK is currently in the process of connecting or reconnecting. */
    CONNECTING,

    /** SDK is disconnected from the server due to network issues. */
    DISCONNECTED,

    /** SDK is intentionally in offline mode. */
    OFFLINE
}
