package customfit.ai.kotlinclient

import java.util.*
import java.util.concurrent.LinkedBlockingQueue
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.joda.time.DateTime
import org.json.JSONObject

class EventTracker(
        private val sessionId: String,
        private val httpClient: HttpClient,
        private val user: CFUser
) {
    private val eventQueue: LinkedBlockingQueue<EventData> = LinkedBlockingQueue()
    private val maxQueueSize = 100
    private val maxTimeInSeconds = 60

    init {
        startFlushEventCheck()
    }

    fun trackEvent(eventName: String, properties: Map<String, Any>) {
        val event =
                EventData(
                        event_customer_id = eventName,
                        event_type = EventType.TRACK,
                        properties = properties.toMutableMap(),
                        event_timestamp = DateTime.now(),
                        session_id = sessionId,
                        timeuuid = UUID.randomUUID(),
                        insert_id = UUID.randomUUID().toString()
                )
        eventQueue.offer(event)
        println("Event added to queue: $event")
        if (eventQueue.size >= maxQueueSize) {
            CoroutineScope(Dispatchers.Default).launch { flushEvents() }
        }
    }

    private fun startFlushEventCheck() {
        fixedRateTimer("EventFlushCheck", daemon = true, period = 1000) {
            CoroutineScope(Dispatchers.Default).launch {
                val lastEvent = eventQueue.peek()
                val currentTime = DateTime.now()
                if (lastEvent != null &&
                                currentTime
                                        .minusSeconds(maxTimeInSeconds)
                                        .isAfter(lastEvent.event_timestamp)
                ) {
                    flushEvents()
                }
            }
        }
    }

    suspend fun flushEvents() {
        if (eventQueue.isEmpty()) {
            println("No events to flush.")
            return
        }
        val eventsToFlush = mutableListOf<EventData>()
        eventQueue.drainTo(eventsToFlush)
        sendTrackEvents(eventsToFlush)
        println("Flushed ${eventsToFlush.size} events.")
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
                JSONObject(
                                mapOf(
                                        "user" to user,
                                        "events" to eventsJson,
                                        "cf_client_sdk_version" to "1.0.0"
                                )
                        )
                        .toString()

        val success = httpClient.postJson("https://example.com/v1/cfe", jsonPayload)
        println(if (success) "Events sent successfully." else "Error sending events.")
    }
}
