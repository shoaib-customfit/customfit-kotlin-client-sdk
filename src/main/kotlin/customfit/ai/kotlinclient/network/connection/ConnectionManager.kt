package customfit.ai.kotlinclient.network.connection

import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.logging.Timber
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Manages connection status monitoring and automatic reconnection logic. Platform-agnostic
 * implementation that relies on connection attempts outcomes rather than direct network monitoring.
 */
class ConnectionManager(private val config: CFConfig, private val onReconnect: () -> Unit) {
    // Connection state
    private val isOfflineMode = AtomicBoolean(false)
    private val failureCount = AtomicInteger(0)
    private val lastSuccessfulConnection = AtomicLong(0)
    private val nextReconnectTime = AtomicLong(0)
    private val lastErrorMessage = AtomicString(null)

    // Status tracking
    private var currentStatus = ConnectionStatus.DISCONNECTED
    private val listeners = CopyOnWriteArrayList<ConnectionStatusListener>()

    // Reconnection settings
    private val baseReconnectDelayMs = 1000L
    private val maxReconnectDelayMs = 30000L
    private var reconnectJob: Job? = null

    // Scopes
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val heartbeatTimer = Timer("ConnectionHeartbeat", true)
    private var heartbeatTask: TimerTask? = null

    init {
        // Initialize with connecting status if not offline
        if (!isOfflineMode.get()) {
            updateStatus(ConnectionStatus.CONNECTING)
        }

        // Start heartbeat to check connection status periodically
        startHeartbeat()
    }

    /** Set the client to offline mode */
    fun setOfflineMode(offline: Boolean) {
        this.isOfflineMode.set(offline)

        if (offline) {
            cancelReconnectJob()
            updateStatus(ConnectionStatus.OFFLINE)
        } else {
            updateStatus(ConnectionStatus.CONNECTING)
            initiateReconnect(0)
        }
    }

    /** Check if the client is in offline mode */
    fun isOffline(): Boolean = isOfflineMode.get()

    /** Gets the current connection information */
    fun getConnectionInformation(): ConnectionInformation =
            ConnectionInformation(
                    status = currentStatus,
                    isOfflineMode = isOfflineMode.get(),
                    lastError = lastErrorMessage.get(),
                    lastSuccessfulConnectionTimeMs = lastSuccessfulConnection.get(),
                    failureCount = failureCount.get(),
                    nextReconnectTimeMs = nextReconnectTime.get()
            )

    /** Register a connection status listener */
    fun addConnectionStatusListener(listener: ConnectionStatusListener) {
        listeners.add(listener)
        // Immediately notify the listener of the current state
        scope.launch(Dispatchers.Default) {
            val info = getConnectionInformation()
            listener.onConnectionStatusChanged(currentStatus, info)
        }
    }

    /** Unregister a connection status listener */
    fun removeConnectionStatusListener(listener: ConnectionStatusListener) {
        listeners.remove(listener)
    }

    /** Record a connection success */
    fun recordSuccess() {
        failureCount.set(0)
        lastSuccessfulConnection.set(System.currentTimeMillis())
        lastErrorMessage.set(null)
        updateStatus(ConnectionStatus.CONNECTED)
    }

    /** Record a connection failure */
    fun recordFailure(error: String?) {
        val failures = failureCount.incrementAndGet()
        lastErrorMessage.set(error)

        if (!isOfflineMode.get()) {
            updateStatus(ConnectionStatus.CONNECTING)

            // Calculate exponential backoff with jitter
            val delayMs = calculateBackoffDelay(failures)
            initiateReconnect(delayMs)
        }
    }

    /** Check connection by making a lightweight request */
    fun checkConnection() {
        if (isOfflineMode.get()) {
            return
        }

        scope.launch {
            // If we were previously connected, set status to connecting during check
            if (currentStatus == ConnectionStatus.CONNECTED) {
                updateStatus(ConnectionStatus.CONNECTING)
            }

            // Trigger reconnect which will attempt to reach the server
            initiateReconnect(0)
        }
    }

    /** Calculate backoff delay with exponential backoff and jitter */
    private fun calculateBackoffDelay(retryCount: Int): Long {
        // Calculate exponential backoff: baseDelay * 2^retryAttempt
        val exponentialDelay = baseReconnectDelayMs * (1L shl minOf(retryCount, 10))

        // Cap at maximum delay
        val cappedDelay = minOf(exponentialDelay, maxReconnectDelayMs)

        // Add jitter (±20%)
        val jitterFactor = 0.8 + Math.random() * 0.4

        return (cappedDelay * jitterFactor).toLong()
    }

    /** Initiate a reconnection attempt after a delay */
    private fun initiateReconnect(delayMs: Long) {
        cancelReconnectJob()

        if (delayMs > 0) {
            nextReconnectTime.set(System.currentTimeMillis() + delayMs)
            Timber.d("Scheduling reconnect in $delayMs ms")
        }

        reconnectJob =
                scope.launch {
                    if (delayMs > 0) {
                        delay(delayMs)
                    }

                    if (!isOfflineMode.get()) {
                        Timber.d("Attempting reconnection")
                        nextReconnectTime.set(0)
                        onReconnect()
                    }
                }
    }

    /** Cancel any pending reconnection job */
    private fun cancelReconnectJob() {
        reconnectJob?.cancel()
        reconnectJob = null
        nextReconnectTime.set(0)
    }

    /** Start heartbeat timer to check connection periodically */
    private fun startHeartbeat() {
        stopHeartbeat()

        heartbeatTask =
                object : TimerTask() {
                    override fun run() {
                        if (!isOfflineMode.get() &&
                                        (currentStatus == ConnectionStatus.DISCONNECTED ||
                                                System.currentTimeMillis() -
                                                        lastSuccessfulConnection.get() > 60000)
                        ) {
                            checkConnection()
                        }
                    }
                }

        heartbeatTimer.scheduleAtFixedRate(heartbeatTask, 15000, 15000)
    }

    /** Stop heartbeat timer */
    private fun stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = null
    }

    /** Update the connection status and notify listeners */
    private fun updateStatus(newStatus: ConnectionStatus) {
        if (currentStatus != newStatus) {
            currentStatus = newStatus
            val info = getConnectionInformation()

            Timber.i("Connection status changed to: $newStatus")

            // Notify listeners on main thread
            scope.launch(Dispatchers.Default) {
                for (listener in listeners) {
                    try {
                        listener.onConnectionStatusChanged(newStatus, info)
                    } catch (e: Exception) {
                        Timber.e(e, "Error notifying connection listener")
                    }
                }
            }
        }
    }

    /** Clean up resources */
    fun shutdown() {
        stopHeartbeat()
        heartbeatTimer.cancel()
        cancelReconnectJob()
        listeners.clear()
    }

    /** Simple AtomicReference replacement for nullable String */
    private class AtomicString(initialValue: String?) {
        @Volatile private var value = initialValue

        fun get(): String? = value

        fun set(newValue: String?) {
            value = newValue
        }
    }
}
