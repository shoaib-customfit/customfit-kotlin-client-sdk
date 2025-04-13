package customfit.ai.kotlinclient.events

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
import org.joda.time.DateTime
import org.json.JSONArray
import org.json.JSONObject
import org.slf4j.LoggerFactory

class EventTracker(
        private val sessionId: String,
        private val httpClient: HttpClient,
        private val user: CFUser,
        private val summaryManager: SummaryManager
) {
    private val logger = LoggerFactory.getLogger(EventTracker::class.java)
    private val eventQueue: LinkedBlockingQueue<EventData> = LinkedBlockingQueue(MAX_QUEUE_SIZE)
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    companion object {
        private const val MAX_QUEUE_SIZE = 100
        private const val MAX_TIME_IN_SECONDS = 60
        private const val FLUSH_INTERVAL_MS = 1000L
    }

    init {
        startFlushEventCheck()
    }

    fun trackEvent(eventName: String, properties: Map<String, Any>) {
        if (eventName.isBlank()) {
            logger.warn("Event name cannot be blank")
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
        if (!eventQueue.offer(event)) {
            logger.warn("Event queue full, forcing flush for event: {}", event)
            scope.launch { flushEvents() }
            if (!eventQueue.offer(event)) {
                logger.error("Failed to queue event after flush: {}", event)
            }
        } else {
            logger.debug("Event added to queue: {}", event)
            if (eventQueue.size >= MAX_QUEUE_SIZE) {
                scope.launch { flushEvents() }
            }
        }
    }

    private fun startFlushEventCheck() {
        fixedRateTimer("EventFlushCheck", daemon = true, period = FLUSH_INTERVAL_MS) {
            scope.launch {
                val lastEvent = eventQueue.peek()
                val currentTime = DateTime.now()
                if (lastEvent != null &&
                                currentTime
                                        .minusSeconds(MAX_TIME_IN_SECONDS)
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
            logger.debug("No events to flush")
            return
        }
        val eventsToFlush = mutableListOf<EventData>()
        eventQueue.drainTo(eventsToFlush)
        if (eventsToFlush.isNotEmpty()) {
            sendTrackEvents(eventsToFlush)
            logger.info("Flushed {} events successfully", eventsToFlush.size)
        }
    }

    private suspend fun sendTrackEvents(events: List<EventData>) {
        val eventsJson =
                events.map { event ->
                    mapOf(
                            "event_customer_id" to event.event_customer_id,
                            "event_type" to event.event_type.toString(),
                            "properties" to event.properties,
                            "event_timestamp" to event.event_timestamp.toString(),
                            "session_id" to event.session_id,
                            "insert_id" to event.insert_id
                    )
                }
        val jsonPayload =
                try {
                    JSONObject()
                            .apply {
                                put("user", user)
                                put("events", JSONArray(eventsJson))
                                put("cf_client_sdk_version", "1.0.0")
                            }
                            .toString()
                } catch (e: Exception) {
                    logger.error("Error serializing events: {}", e.message, e)
                    events.forEach { eventQueue.offer(it) }
                    return
                }

        val success = httpClient.postJson("https://example.com/v1/cfe", jsonPayload)
        if (!success) {
            logger.warn("Failed to send {} events, re-queuing", events.size)
            events.forEach { eventQueue.offer(it) }
        } else {
            logger.info("Successfully sent {} events", events.size)
        }
    }

    // Helper function to convert Map to JSONObject recursively
    private fun mapToJsonObject(map: Map<String, Any?>): JSONObject {
        val jsonObject = JSONObject()
        map.forEach { (key, value) ->
            when (value) {
                is Map<*, *> -> jsonObject.put(key, mapToJsonObject(value as Map<String, Any?>))
                is List<*> -> jsonObject.put(key, JSONArray(value))
                null -> jsonObject.put(key, JSONObject.NULL)
                else -> jsonObject.put(key, value)
            }
        }
        return jsonObject
    }
}
