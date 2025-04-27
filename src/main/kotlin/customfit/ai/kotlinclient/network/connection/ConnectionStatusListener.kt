package customfit.ai.kotlinclient.network.connection

/** Interface for objects that will be notified of connection status changes. */
interface ConnectionStatusListener {
    /**
     * Called when the connection status changes.
     *
     * @param newStatus The new connection status
     * @param info Detailed connection information
     */
    fun onConnectionStatusChanged(newStatus: ConnectionStatus, info: ConnectionInformation)
}
