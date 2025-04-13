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
import org.json.JSONArray
import org.json.JSONObject

private val logger = KotlinLogging.logger {}

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
                    val jsonObject = JSONObject()
                    
                    // Add events array with properly formatted event objects
                    val eventsArray = JSONArray()
                    events.forEach { event ->
                        val eventObject = JSONObject()
                        eventObject.put("event_customer_id", event.event_customer_id)
                        eventObject.put("event_type", event.event_type.name)
                        eventObject.put("properties", JSONObject(event.properties))
                        
                        // Format timestamp to match server expectation: yyyy-MM-dd HH:mm:ss.SSSZ (no 'T')
                        event.event_timestamp?.let { 
                            eventObject.put("event_timestamp", it.toString("yyyy-MM-dd HH:mm:ss.SSSZ")) 
                        }
                        
                        eventObject.put("session_id", event.session_id)
                        eventObject.put("insert_id", event.insert_id)
                        eventsArray.put(eventObject)
                    }
                    jsonObject.put("events", eventsArray)
                    
                    // Add user object
                    jsonObject.put("user", JSONObject().apply {
                        put("user_customer_id", user.user_customer_id)
                        put("anonymous", user.anonymous)
                        // Include private_fields if available
                        if (user.private_fields != null) {
                            put("private_fields", JSONObject(user.private_fields))
                        }
                        // Include session_fields if available
                        if (user.session_fields != null) {
                            put("session_fields", JSONObject(user.session_fields))
                        }
                        // Include properties
                        put("properties", JSONObject(user.properties))
                        // Include any other available fields from the user
                      
                        // dimension_id would be added here if available
                    })
                    
                    // Add SDK version
                    jsonObject.put("cf_client_sdk_version", "1.0.0")
                    
                    jsonObject.toString()
                } catch (e: Exception) {
                    logger.error(e) { "Error serializing events: ${e.message}" }
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
            events.forEach { eventQueue.offer(it) }
        } else {
            logger.info { "Successfully sent ${events.size} events" }
        }
    }
}
