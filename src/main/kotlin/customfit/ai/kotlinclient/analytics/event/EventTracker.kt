package customfit.ai.kotlinclient.analytics.event

import customfit.ai.kotlinclient.analytics.summary.SummaryManager
import customfit.ai.kotlinclient.core.config.CFConfig
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.core.util.RetryUtil.withRetry
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.platform.AppState
import customfit.ai.kotlinclient.platform.AppStateListener
import customfit.ai.kotlinclient.platform.BatteryState
import customfit.ai.kotlinclient.platform.BatteryStateListener
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Timer
import java.util.UUID
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import customfit.ai.kotlinclient.logging.Timber

class EventTracker(
        private val sessionId: String,
        private val httpClient: HttpClient,
        private val user: CFUser,
        private val summaryManager: SummaryManager,
        private val cfConfig: CFConfig
) {
    // Use atomics to allow thread-safe updates
    private val eventsQueueSize = cfConfig.eventsQueueSize
    private val eventsFlushTimeSeconds = AtomicInteger(cfConfig.eventsFlushTimeSeconds)
    private val eventsFlushIntervalMs = AtomicLong(cfConfig.eventsFlushIntervalMs)

    private val eventQueue: LinkedBlockingQueue<EventData> = LinkedBlockingQueue(eventsQueueSize)
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // Timer management
    private var flushTimer: Timer? = null
    private val timerMutex = Mutex()

    init {
        Timber.i("EventTracker initialized with eventsQueueSize=$eventsQueueSize, eventsFlushTimeSeconds=${eventsFlushTimeSeconds.get()}, eventsFlushIntervalMs=${eventsFlushIntervalMs.get()}")
        startPeriodicFlush()
    }

    /**
     * Updates the flush interval and restarts the timer
     *
     * @param intervalMs new interval in milliseconds
     */
    suspend fun updateFlushInterval(intervalMs: Long) {
        require(intervalMs > 0) { "Interval must be greater than 0" }

        eventsFlushIntervalMs.set(intervalMs)
        restartPeriodicFlush()
        Timber.i("Updated events flush interval to $intervalMs ms")
    }

    /**
     * Updates the flush time threshold
     *
     * @param seconds new threshold in seconds
     */
    fun updateFlushTimeSeconds(seconds: Int) {
        require(seconds > 0) { "Seconds must be greater than 0" }

        eventsFlushTimeSeconds.set(seconds)
        Timber.i("Updated events flush time threshold to $seconds seconds")
    }

    fun trackEvent(eventName: String, properties: Map<String, Any> = emptyMap()) {
        if (eventName.isBlank()) {
            Timber.w("Event name cannot be blank")
            return
        }
        val validatedProperties = properties

        // Create event with:
        // - session_id from the tracker initialization (consistent across events)
        // - insert_id that's unique for each event (UUID)
        val event = EventData(
            event_customer_id = eventName,
            event_type = EventType.TRACK,
            properties = validatedProperties,
            event_timestamp = Instant.now(),
            session_id = sessionId,
            insert_id = UUID.randomUUID().toString()
        )
        if (eventQueue.size >= eventsQueueSize) {
            Timber.w("Event queue is full (size = $eventsQueueSize), dropping oldest event")
            eventQueue.poll() // Remove the oldest event
        }
        if (!eventQueue.offer(event)) {
            Timber.w("Event queue full, forcing flush for event: $event")
            scope.launch { flushEvents() }
            if (!eventQueue.offer(event)) {
                Timber.e("Failed to queue event after flush: $event")
            }
        } else {
            Timber.d("Event added to queue: $event")
            if (eventQueue.size >= eventsQueueSize) {
                scope.launch { flushEvents() }
            }
        }
    }

    private fun startPeriodicFlush() {
        scope.launch {
            timerMutex.withLock {
                flushTimer?.cancel()
                flushTimer = fixedRateTimer(
                    "EventFlushCheck",
                    daemon = true,
                    period = eventsFlushIntervalMs.get()
                ) {
                    scope.launch {
                        val lastEvent = eventQueue.peek()
                        val currentTime = Instant.now()
                        if (lastEvent != null &&
                            currentTime.minusSeconds(eventsFlushTimeSeconds.get().toLong())
                                .isAfter(lastEvent.event_timestamp)
                        ) {
                            flushEvents()
                        }
                    }
                }
            }
        }
    }

    private suspend fun restartPeriodicFlush() {
        timerMutex.withLock {
            flushTimer?.cancel()
            flushTimer = fixedRateTimer(
                "EventFlushCheck",
                daemon = true,
                period = eventsFlushIntervalMs.get()
            ) {
                scope.launch {
                    val lastEvent = eventQueue.peek()
                    val currentTime = Instant.now()
                    if (lastEvent != null &&
                        currentTime.minusSeconds(eventsFlushTimeSeconds.get().toLong())
                            .isAfter(lastEvent.event_timestamp)
                    ) {
                        flushEvents()
                    }
                }
            }
            Timber.d("Restarted periodic event flush check with interval ${eventsFlushIntervalMs.get()} ms")
        }
    }

    suspend fun flushEvents() {
        summaryManager.flushSummaries()
        if (eventQueue.isEmpty()) {
            Timber.d("No events to flush")
            return
        }
        val eventsToFlush = mutableListOf<EventData>()
        eventQueue.drainTo(eventsToFlush)
        if (eventsToFlush.isNotEmpty()) {
            sendTrackEvents(eventsToFlush)
            Timber.i("Flushed ${eventsToFlush.size} events successfully")
        }
    }

    // Define formatter for the specific timestamp format needed by the server
    private val eventTimestampFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSSX").withZone(ZoneOffset.UTC)

    private suspend fun sendTrackEvents(events: List<EventData>) {
        val jsonPayload = try {
            val jsonObject = buildJsonObject {
                put("events", buildJsonArray {
                    events.forEach { event ->
                        add(buildJsonObject {
                            put("event_customer_id", JsonPrimitive(event.event_customer_id))
                            put("event_type", JsonPrimitive(event.event_type.name))
                            put("properties", buildJsonObject {
                                event.properties.forEach { (k, v) ->
                                    put(k, anyToJsonElement(v))
                                }
                            })
                            put("event_timestamp", JsonPrimitive(eventTimestampFormatter.format(event.event_timestamp)))
                            put("session_id", JsonPrimitive(event.session_id))
                            put("insert_id", JsonPrimitive(event.insert_id))
                        })
                    }
                })
                put("user", buildJsonObject {
                    user.toUserMap().forEach { (k, v) ->
                        put(k, anyToJsonElement(v))
                    }
                })
                put("cf_client_sdk_version", JsonPrimitive("1.1.1"))
            }
            Json.encodeToString(jsonObject)
        } catch (e: Exception) {
            if (e is kotlinx.serialization.SerializationException) {
                Timber.e(e, "Serialization error creating event payload: ${e.message}")
            }
            throw e
        }

        try {
            withRetry(
                maxAttempts = cfConfig.maxRetryAttempts,
                initialDelayMs = cfConfig.retryInitialDelayMs,
                maxDelayMs = cfConfig.retryMaxDelayMs,
                backoffMultiplier = cfConfig.retryBackoffMultiplier
            ) {
                if (!httpClient.postJson("https://api.customfit.ai/v1/cfe?cfenc=${cfConfig.clientKey}", jsonPayload)) {
                    throw Exception("Failed to send event")
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to send event after retries: ${e.message}")
            // Re-queue the event if sending failed after all retries
            events.forEach { event ->
                if (!eventQueue.offer(event)) {
                    Timber.e("Failed to re-queue event after send failure: $event")
                }
            }
            throw e
        }
    }

    private fun anyToJsonElement(value: Any?): JsonElement = when (value) {
        null -> JsonNull
        is String -> JsonPrimitive(value)
        is Number -> JsonPrimitive(value)
        is Boolean -> JsonPrimitive(value)
        is Map<*, *> -> buildJsonObject {
            value.forEach { (k, v) ->
                if (k is String) {
                    put(k, anyToJsonElement(v))
                }
            }
        }
        is List<*> -> buildJsonArray {
            value.forEach { item ->
                add(anyToJsonElement(item))
            }
        }
        else -> JsonPrimitive(value.toString())
    }
}
