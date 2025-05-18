package customfit.ai.kotlinclient.analytics.event

import customfit.ai.kotlinclient.analytics.summary.SummaryManager
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.core.error.ErrorHandler
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
    companion object {
        private const val SOURCE = "EventTracker"
    }
    
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
    suspend fun updateFlushInterval(intervalMs: Long): CFResult<Long> {
        try {
            require(intervalMs > 0) { "Interval must be greater than 0" }

            eventsFlushIntervalMs.set(intervalMs)
            restartPeriodicFlush()
            Timber.i("Updated events flush interval to $intervalMs ms")
            return CFResult.success(intervalMs)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Failed to update flush interval to $intervalMs",
                SOURCE,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            return CFResult.error("Failed to update flush interval", e, category = ErrorHandler.ErrorCategory.VALIDATION)
        }
    }

    /**
     * Updates the flush time threshold
     *
     * @param seconds new threshold in seconds
     */
    fun updateFlushTimeSeconds(seconds: Int): CFResult<Int> {
        try {
            require(seconds > 0) { "Seconds must be greater than 0" }

            eventsFlushTimeSeconds.set(seconds)
            Timber.i("Updated events flush time threshold to $seconds seconds")
            return CFResult.success(seconds)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Failed to update flush time seconds to $seconds",
                SOURCE,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            return CFResult.error("Failed to update flush time seconds", e, category = ErrorHandler.ErrorCategory.VALIDATION)
        }
    }

    /**
     * Tracks an event with improved error handling
     * Always flushes summaries before tracking a new event
     */
    fun trackEvent(eventName: String, properties: Map<String, Any> = emptyMap()): CFResult<EventData> {
        try {
            // Using Timber for consistent logging
            Timber.i("🔔 🔔 TRACK: Tracking event: $eventName with properties: $properties")
            
            // Always flush summaries first before tracking a new event
            scope.launch {
                Timber.i("🔔 🔔 TRACK: Flushing summaries before tracking event: $eventName")
                summaryManager.flushSummaries()
                    .onError { error ->
                        Timber.w("🔔 🔔 TRACK: Failed to flush summaries before tracking event: ${error.error}")
                    }
            }
            
            if (eventName.isBlank()) {
                val message = "Event name cannot be blank"
                Timber.w("🔔 TRACK: Invalid event - $message")
                ErrorHandler.handleError(
                    message,
                    SOURCE,
                    ErrorHandler.ErrorCategory.VALIDATION,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
                return CFResult.error(message, category = ErrorHandler.ErrorCategory.VALIDATION)
            }

            // Create event using our factory method with validation
            val event = EventData.create(
                eventCustomerId = eventName,
                eventType = EventType.TRACK,
                properties = properties,
                timestamp = Instant.now(),
                sessionId = sessionId,
                insertId = UUID.randomUUID().toString()
            )

            // Handle queue management with proper error tracking
            if (eventQueue.size >= eventsQueueSize) {
                Timber.w("🔔 TRACK: Event queue is full (size = $eventsQueueSize), dropping oldest event")
                ErrorHandler.handleError(
                    "Event queue is full (size = $eventsQueueSize), dropping oldest event",
                    SOURCE,
                    ErrorHandler.ErrorCategory.INTERNAL,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
                eventQueue.poll() // Remove the oldest event
            }

            if (!eventQueue.offer(event)) {
                Timber.w("🔔 TRACK: Event queue full, forcing flush for event: ${event.event_customer_id}")
                ErrorHandler.handleError(
                    "Event queue full, forcing flush for event: $event",
                    SOURCE,
                    ErrorHandler.ErrorCategory.INTERNAL,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
                scope.launch { flushEvents() }
                
                if (!eventQueue.offer(event)) {
                    val message = "Failed to queue event after flush"
                    Timber.e("🔔 TRACK: $message: ${event.event_customer_id}")
                    ErrorHandler.handleError(
                        "$message: $event",
                        SOURCE,
                        ErrorHandler.ErrorCategory.INTERNAL,
                        ErrorHandler.ErrorSeverity.HIGH
                    )
                    return CFResult.error(message, category = ErrorHandler.ErrorCategory.INTERNAL)
                }
            } else {
                Timber.i("🔔 TRACK: Event added to queue: ${event.event_customer_id}, queue size=${eventQueue.size}")
                if (eventQueue.size >= eventsQueueSize) {
                    Timber.i("🔔 TRACK: Queue size threshold reached (${eventQueue.size}/${eventsQueueSize}), triggering flush")
                    scope.launch { flushEvents() }
                }
            }
            
            return CFResult.success(event)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Unexpected error tracking event: $eventName",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            return CFResult.error("Failed to track event", e, category = ErrorHandler.ErrorCategory.INTERNAL)
        }
    }

    private fun startPeriodicFlush() {
        scope.launch {
            try {
                timerMutex.withLock {
                    flushTimer?.cancel()
                    flushTimer = fixedRateTimer(
                        "EventFlushCheck",
                        daemon = true,
                        period = eventsFlushIntervalMs.get()
                    ) {
                        scope.launch {
                            try {
                                val lastEvent = eventQueue.peek()
                                val currentTime = Instant.now()
                                if (lastEvent != null &&
                                    currentTime.minusSeconds(eventsFlushTimeSeconds.get().toLong())
                                        .isAfter(lastEvent.event_timestamp)
                                ) {
                                    flushEvents()
                                }
                            } catch (e: Exception) {
                                ErrorHandler.handleException(
                                    e,
                                    "Error in periodic flush timer",
                                    SOURCE,
                                    ErrorHandler.ErrorSeverity.MEDIUM
                                )
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                ErrorHandler.handleException(
                    e,
                    "Failed to start periodic flush timer",
                    SOURCE,
                    ErrorHandler.ErrorSeverity.HIGH
                )
            }
        }
    }

    private suspend fun restartPeriodicFlush() {
        try {
            timerMutex.withLock {
                flushTimer?.cancel()
                flushTimer = fixedRateTimer(
                    "EventFlushCheck",
                    daemon = true,
                    period = eventsFlushIntervalMs.get()
                ) {
                    scope.launch {
                        try {
                            val lastEvent = eventQueue.peek()
                            val currentTime = Instant.now()
                            if (lastEvent != null &&
                                currentTime.minusSeconds(eventsFlushTimeSeconds.get().toLong())
                                    .isAfter(lastEvent.event_timestamp)
                            ) {
                                flushEvents()
                            }
                        } catch (e: Exception) {
                            ErrorHandler.handleException(
                                e,
                                "Error in restarted periodic flush timer",
                                SOURCE,
                                ErrorHandler.ErrorSeverity.MEDIUM
                            )
                        }
                    }
                }
                Timber.d("Restarted periodic event flush check with interval ${eventsFlushIntervalMs.get()} ms")
            }
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Failed to restart periodic flush timer",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
        }
    }

    /**
     * Flushes events to the server with improved error handling
     * Note: Summaries are already flushed in trackEvent, but we ensure they're flushed here as well
     */
    suspend fun flushEvents(): CFResult<Int> {
        try {
            // Always ensure summaries are flushed first
            Timber.i("🔔 🔔 TRACK: Beginning event flush process")
            summaryManager.flushSummaries()
                .onError { error ->
                    Timber.w("🔔 🔔 TRACK: Failed to flush summaries before flushing events: ${error.error}")
                    ErrorHandler.handleError(
                        "Failed to flush summaries before flushing events: ${error.error}",
                        SOURCE,
                        error.category,
                        ErrorHandler.ErrorSeverity.MEDIUM
                    )
                }
            
            // Check if queue is empty
            if (eventQueue.isEmpty()) {
                Timber.d("🔔 TRACK: No events to flush")
                return CFResult.success(0)
            }
            
            // Drain the queue
            val eventsToFlush = mutableListOf<EventData>()
            eventQueue.drainTo(eventsToFlush)
            
            if (eventsToFlush.isNotEmpty()) {
                Timber.i("🔔 TRACK: Flushing ${eventsToFlush.size} events to server")
                
                eventsToFlush.forEachIndexed { index, event ->
                    Timber.d("🔔 TRACK: Event #${index+1}: ${event.event_customer_id}")
                }
                
                val result = sendTrackEvents(eventsToFlush)
                
                return result.fold(
                    onSuccess = {
                        Timber.i("🔔 TRACK: Flushed ${eventsToFlush.size} events successfully")
                        CFResult.success(eventsToFlush.size)
                    },
                    onError = { error ->
                        Timber.w("🔔 TRACK: Failed to flush events: ${error.error}")
                        CFResult.error(
                            "Failed to flush events: ${error.error}",
                            error.exception,
                            error.code,
                            error.category
                        )
                    }
                )
            } else {
                Timber.d("🔔 TRACK: No events to flush after drain")
                return CFResult.success(0)
            }
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Unexpected error flushing events",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            return CFResult.error("Failed to flush events", e, category = ErrorHandler.ErrorCategory.INTERNAL)
        }
    }

    // Define formatter for the specific timestamp format needed by the server
    private val eventTimestampFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSSX").withZone(ZoneOffset.UTC)

    /**
     * Sends tracked events to the server with improved error handling
     */
    private suspend fun sendTrackEvents(events: List<EventData>): CFResult<Boolean> {
        Timber.i("🔔 TRACK HTTP: Preparing to send ${events.size} events")
        
        // Log detailed event information before HTTP call
        events.forEachIndexed { index, event ->
            Timber.d("🔔 TRACK HTTP: Event #${index+1}: ${event.event_customer_id}, properties=${event.properties.keys.joinToString()}")
        }
        
        // First create the JSON payload
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
            Timber.e("🔔 TRACK HTTP: Error creating event payload for ${events.size} events")
            ErrorHandler.handleException(
                e,
                "Failed to serialize event payload",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            return CFResult.error(
                "Failed to serialize event payload",
                e,
                category = ErrorHandler.ErrorCategory.SERIALIZATION
            )
        }
        
        Timber.i("🔔 TRACK HTTP: Event payload size: ${jsonPayload.length} bytes")

        // Then send the events with retry
        val url = "https://api.customfit.ai/v1/cfe?cfenc=${cfConfig.clientKey}"
        Timber.i("🔔 TRACK HTTP: POST request to: $url")
        
        try {
            return withRetry(
                maxAttempts = cfConfig.maxRetryAttempts,
                initialDelayMs = cfConfig.retryInitialDelayMs,
                maxDelayMs = cfConfig.retryMaxDelayMs,
                backoffMultiplier = cfConfig.retryBackoffMultiplier
            ) {
                Timber.d("🔔 TRACK HTTP: Attempting to send events")
                val result = httpClient.postJson(url, jsonPayload)
                
                result.fold(
                    onSuccess = { 
                        Timber.i("🔔 TRACK HTTP: Events successfully sent to server")
                        CFResult.success(true) 
                    },
                    onError = { error ->
                        Timber.w("🔔 TRACK HTTP: Server returned error: ${error.error}")
                        throw Exception("Failed to send event: ${error.error}", error.exception)
                    }
                )
            }
        } catch (e: Exception) {
            Timber.e("🔔 TRACK HTTP: Failed to send events after ${cfConfig.maxRetryAttempts} attempts: ${e.message}")
            ErrorHandler.handleException(
                e,
                "Failed to send events after retries",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            
            // Re-queue the events if sending failed after all retries
            Timber.w("🔔 TRACK HTTP: Failed to send ${events.size} events, attempting to re-queue")
            
            var requeueFailed = false
            var requeueFailCount = 0
            
            events.forEach { event ->
                if (!eventQueue.offer(event)) {
                    requeueFailed = true
                    requeueFailCount++
                    Timber.e("🔔 TRACK: Failed to re-queue event ${event.event_customer_id} after send failure")
                    ErrorHandler.handleError(
                        "Failed to re-queue event after send failure: $event",
                        SOURCE,
                        ErrorHandler.ErrorCategory.INTERNAL,
                        ErrorHandler.ErrorSeverity.HIGH
                    )
                } else {
                    Timber.i("🔔 TRACK: Successfully re-queued event ${event.event_customer_id}")
                }
            }
            
            val errorMessage = if (requeueFailed) {
                "Failed to send events and $requeueFailCount event(s) could not be requeued" 
            } else {
                "Failed to send events but all ${events.size} were requeued"
            }
            
            Timber.w("🔔 TRACK: $errorMessage")
            
            return CFResult.error(
                errorMessage,
                e,
                category = ErrorHandler.ErrorCategory.NETWORK
            )
        }
    }

    /**
     * Converts any value to a JsonElement
     */
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

