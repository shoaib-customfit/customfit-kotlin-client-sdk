package customfit.ai.kotlinclient.events

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.summaries.SummaryManager
import java.util.*
import java.util.concurrent.LinkedBlockingQueue
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import mu.KotlinLogging
import org.joda.time.DateTime
import org.json.JSONArray
import org.json.JSONObject

private val logger = KotlinLogging.logger {}

class EventTracker(
        private val sessionId: String,
        private val httpClient: HttpClient,
        private val user: CFUser,
        private val summaryManager: SummaryManager,
        private val cfConfig: CFConfig
) {
    // Use values from config or fallback to defaults
    private val eventsQueueSize = cfConfig.eventsQueueSize
    private val eventsFlushTimeSeconds = cfConfig.eventsFlushTimeSeconds
    private val eventsFlushIntervalMs = cfConfig.eventsFlushIntervalMs
    
    private val eventQueue: LinkedBlockingQueue<EventData> = LinkedBlockingQueue(eventsQueueSize)
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    init {
        logger.info { "EventTracker initialized with eventsQueueSize=$eventsQueueSize, eventsFlushTimeSeconds=$eventsFlushTimeSeconds, eventsFlushIntervalMs=$eventsFlushIntervalMs" }
        startPeriodicFlush()
    }

    fun trackEvent(eventName: String, properties: Map<String, Any> = emptyMap()) {
        if (eventName.isBlank()) {
            logger.warn { "Event name cannot be blank" }
            return
        }
        val validatedProperties =
                properties.filterKeys { it is String }.mapKeys { it.key as String }
        val event =
                EventData(
                        event_customer_id = eventName,
                        event_type = EventType.TRACK,
                        properties = validatedProperties,
                        event_timestamp = DateTime.now(),
                        session_id = sessionId,
                        timeuuid = UUID.randomUUID(),
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
        fixedRateTimer("EventFlushCheck", daemon = true, period = eventsFlushIntervalMs) {
            scope.launch {
                val lastEvent = eventQueue.peek()
                val currentTime = DateTime.now()
                if (lastEvent != null &&
                                currentTime
                                        .minusSeconds(eventsFlushTimeSeconds)
                                        .isAfter(lastEvent.event_timestamp)
                ) {
                    flushEvents()
                }
            }
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
                    JSONArray().apply {
                        events.forEach { event ->
                            put(
                                    JSONObject()
                                            .apply {
                                                put("event_customer_id", event.event_customer_id)
                                                put("event_type", event.event_type.name)
                                                put("properties", JSONObject(event.properties))
                                                put("event_timestamp", event.event_timestamp)
                                                put("session_id", event.session_id)
                                                put("timeuuid", event.timeuuid)
                                                put("insert_id", event.insert_id)
                                                
                                                // Add user properties
                                                put("user_id", user.user_customer_id)
                                                put("anonymous_id", user.anonymous)
                                                val userProperties = user.getCurrentProperties()
                                                if (userProperties.isNotEmpty()) {
                                                    put("user_properties", JSONObject(userProperties))
                                                }
                                                
                                                // No summary data in event payload - handled by SummaryManager
                                            }
                            )
                        }
                    }
                            .toString()
                } catch (e: Exception) {
                    logger.error(e) { "Error serializing events: ${e.message}" }
                    events.forEach { eventQueue.offer(it) }
                    return
                }

        val success = httpClient.postJson("https://api.customfit.ai/v1/cfe", jsonPayload)
        if (!success) {
            logger.warn { "Failed to send ${events.size} events, re-queuing" }
            events.forEach { eventQueue.offer(it) }
        } else {
            logger.info { "Successfully sent ${events.size} events" }
        }
    }
}
