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
import org.joda.time.DateTime
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
                        event_timestamp = DateTime.now(),  // Raw DateTime object, formatting applied during serialization
                        session_id = sessionId,  // Use session ID from initialization
                        insert_id = UUID.randomUUID().toString()  // Generate unique insert_id for each event
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
                // Cancel existing timer if any
                flushTimer?.cancel()
                
                // Create a new timer
                flushTimer = fixedRateTimer("EventFlushCheck", daemon = true, period = eventsFlushIntervalMs.get()) {
                    scope.launch {
                        val lastEvent = eventQueue.peek()
                        val currentTime = DateTime.now()
                        if (lastEvent != null &&
                                    currentTime
                                            .minusSeconds(eventsFlushTimeSeconds.get())
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
            // Cancel existing timer if any
            flushTimer?.cancel()
            
            // Create a new timer with updated interval
            flushTimer = fixedRateTimer("EventFlushCheck", daemon = true, period = eventsFlushIntervalMs.get()) {
                scope.launch {
                    val lastEvent = eventQueue.peek()
                    val currentTime = DateTime.now()
                    if (lastEvent != null &&
                                currentTime
                                        .minusSeconds(eventsFlushTimeSeconds.get())
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

    private suspend fun sendTrackEvents(events: List<EventData>) {
        val jsonPayload =
                try {
                    // Use kotlinx.serialization builders
                    val jsonObject = buildJsonObject {
                        // Add events array
                        put("events", buildJsonArray {
                            events.forEach { event ->
                                add(buildJsonObject { // Use buildJsonObject for each event
                                    put("event_customer_id", JsonPrimitive(event.event_customer_id))
                                    put("event_type", JsonPrimitive(event.event_type.name))
                                    // Encode properties map using the helper
                                    put("properties", buildJsonObject { 
                                        event.properties.forEach { (k, v) ->
                                            // Use anyToJsonElement for property values
                                            put(k, anyToJsonElement(v)) 
                                        }
                                    })
                                    
                                    // Format timestamp to match server expectation: yyyy-MM-dd HH:mm:ss.SSSZ
                                    event.event_timestamp?.let { 
                                        put("event_timestamp", JsonPrimitive(it.toString("yyyy-MM-dd HH:mm:ss.SSSZ"))) 
                                    }
                                    
                                    put("session_id", JsonPrimitive(event.session_id))
                                    put("insert_id", JsonPrimitive(event.insert_id))
                                })
                            }
                        })
                        
                        // Add user object using user.toUserMap() and the helper
                        put("user", buildJsonObject { 
                            // Use helper function for values in user map
                            user.toUserMap().forEach { (k, v) -> 
                                put(k, anyToJsonElement(v))
                            } 
                        })
                        
                        // Add SDK version
                        put("cf_client_sdk_version", JsonPrimitive("1.1.1")) // Use correct version
                    }
                    
                    Json.encodeToString(jsonObject)
                } catch (e: Exception) {
                    // Catch specific SerializationException from helper if needed
                    if (e is kotlinx.serialization.SerializationException) {
                        logger.error(e) { "Serialization error creating event payload: ${e.message}" }
                    } else {
                        logger.error(e) { "Error serializing events: ${e.message}" }
                    }
                    // Re-queue events on serialization error
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
            // Re-add events to queue in case of failure
            // Consider potential for infinite loops if server consistently fails
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
