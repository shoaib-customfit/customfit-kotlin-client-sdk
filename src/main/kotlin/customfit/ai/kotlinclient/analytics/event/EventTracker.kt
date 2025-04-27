package customfit.ai.kotlinclient.events

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.summaries.SummaryManager
import java.util.*
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
import mu.KotlinLogging
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.ZoneOffset
import kotlinx.serialization.json.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.Serializable

private val logger = KotlinLogging.logger {}

// --- Copied Helper function to serialize Any --- 
private fun anyToJsonElement(value: Any?): JsonElement = when (value) {
    null -> JsonNull
    is JsonElement -> value // If it's already a JsonElement, return it directly
    is String -> JsonPrimitive(value)
    is Number -> JsonPrimitive(value)
    is Boolean -> JsonPrimitive(value)
    is Map<*, *> -> buildJsonObject { // Recursively handle maps
        value.forEach { (k, v) ->
            if (k is String) {
                put(k, anyToJsonElement(v)) // Recursive call
            } else {
                // Handle non-string keys if necessary, e.g., convert toString or throw error
                logger.warn { "Skipping non-string key in map during serialization: $k" }
            }
        }
    }
    is Iterable<*> -> buildJsonArray { // Recursively handle lists/collections
        value.forEach { 
            add(anyToJsonElement(it)) // Recursive call
        }
    }
    // Add other specific types if needed (e.g., Date -> JsonPrimitive(date.toString()))
    else -> throw kotlinx.serialization.SerializationException("Serializer for class '${value::class.simpleName}' is not found. Cannot serialize value of type Any.")
}
// --- End Helper function --- 

class EventTracker(
        private val sessionId: String,  // This is the session ID that will be used for all events
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
        logger.info { "EventTracker initialized with eventsQueueSize=$eventsQueueSize, eventsFlushTimeSeconds=${eventsFlushTimeSeconds.get()}, eventsFlushIntervalMs=${eventsFlushIntervalMs.get()}" }
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
        logger.info { "Updated events flush interval to $intervalMs ms" }
    }
    
    /**
     * Updates the flush time threshold
     * 
     * @param seconds new threshold in seconds
     */
    fun updateFlushTimeSeconds(seconds: Int) {
        require(seconds > 0) { "Seconds must be greater than 0" }
        
        eventsFlushTimeSeconds.set(seconds)
        logger.info { "Updated events flush time threshold to $seconds seconds" }
    }

    fun trackEvent(eventName: String, properties: Map<String, Any> = emptyMap()) {
        if (eventName.isBlank()) {
            logger.warn { "Event name cannot be blank" }
            return
        }
        val validatedProperties =
                properties.filterKeys { it is String }.mapKeys { it.key as String }
        
        // Create event with:
        // - session_id from the tracker initialization (consistent across events)
        // - insert_id that's unique for each event (UUID)
        val event =
                EventData(
                        event_customer_id = eventName,
                        event_type = EventType.TRACK,
                        properties = validatedProperties,
                        event_timestamp = Instant.now(),
                        session_id = sessionId,
                        insert_id = UUID.randomUUID().toString()
                )
        if (eventQueue.size >= eventsQueueSize) {
            logger.warn { "Event queue is full (size = $eventsQueueSize), dropping oldest event" }
            eventQueue.poll() // Remove the oldest event
        }
        if (!eventQueue.offer(event)) {
            logger.warn { "Event queue full, forcing flush for event: $event" }
            scope.launch { flushEvents() }
            if (!eventQueue.offer(event)) {
                logger.error { "Failed to queue event after flush: $event" }
            }
        } else {
            logger.debug { "Event added to queue: $event" }
            if (eventQueue.size >= eventsQueueSize) {
                scope.launch { flushEvents() }
            }
        }
    }

    private fun startPeriodicFlush() {
        scope.launch {
            timerMutex.withLock {
                flushTimer?.cancel()
                flushTimer = fixedRateTimer("EventFlushCheck", daemon = true, period = eventsFlushIntervalMs.get()) {
                    scope.launch {
                        val lastEvent = eventQueue.peek()
                        val currentTime = Instant.now()
                        if (lastEvent != null &&
                                    currentTime
                                            .minusSeconds(eventsFlushTimeSeconds.get().toLong())
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
            flushTimer = fixedRateTimer("EventFlushCheck", daemon = true, period = eventsFlushIntervalMs.get()) {
                scope.launch {
                    val lastEvent = eventQueue.peek()
                    val currentTime = Instant.now()
                    if (lastEvent != null &&
                                currentTime
                                        .minusSeconds(eventsFlushTimeSeconds.get().toLong())
                                        .isAfter(lastEvent.event_timestamp)
                    ) {
                        flushEvents()
                    }
                }
            }
            logger.debug { "Restarted periodic event flush check with interval ${eventsFlushIntervalMs.get()} ms" }
        }
    }

    suspend fun flushEvents() {
        summaryManager.flushSummaries()
        if (eventQueue.isEmpty()) {
            logger.debug { "No events to flush" }
            return
        }
        val eventsToFlush = mutableListOf<EventData>()
        eventQueue.drainTo(eventsToFlush)
        if (eventsToFlush.isNotEmpty()) {
            sendTrackEvents(eventsToFlush)
            logger.info { "Flushed ${eventsToFlush.size} events successfully" }
        }
    }

    // Define formatter for the specific timestamp format needed by the server
    private val eventTimestampFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSSX")
                                                              .withZone(ZoneOffset.UTC) // Or system default ZoneId.systemDefault()

    private suspend fun sendTrackEvents(events: List<EventData>) {
        val jsonPayload =
                try {
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
                                    
                                    // Format Instant using DateTimeFormatter
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
                        
                        put("cf_client_sdk_version", JsonPrimitive("1.1.1")) // Use correct version
                    }
                    
                    Json.encodeToString(jsonObject)
                } catch (e: Exception) {
                    if (e is kotlinx.serialization.SerializationException) {
                        logger.error(e) { "Serialization error creating event payload: ${e.message}" }
                    } else {
                        logger.error(e) { "Error serializing events: ${e.message}" }
                    }
                    events.forEach { eventQueue.offer(it) }
                    return
                }

        // Print the API payload for debugging
        val timestamp = java.text.SimpleDateFormat("HH:mm:ss.SSS").format(java.util.Date())
        logger.debug { "================ EVENT API PAYLOAD ================" }
        logger.debug { jsonPayload }
        logger.debug { "==================================================" }

        val success = httpClient.postJson("https://api.customfit.ai/v1/cfe?cfenc=${cfConfig.clientKey}", jsonPayload)
        if (!success) {
            logger.warn { "Failed to send ${events.size} events, re-queuing" }
            val capacity = eventsQueueSize - this.eventQueue.size
            if (capacity > 0) {
                events.take(capacity).forEach { this.eventQueue.offer(it) }
            } else {
                 logger.warn { "Event queue is full, couldn't re-queue failed events" }
            }
        } else {
            logger.info { "Successfully sent ${events.size} events" }
        }
    }
}
