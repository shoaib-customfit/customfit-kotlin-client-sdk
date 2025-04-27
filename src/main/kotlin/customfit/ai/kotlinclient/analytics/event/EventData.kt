package customfit.ai.kotlinclient.analytics.event

import com.fasterxml.jackson.databind.annotation.JsonDeserialize
import com.fasterxml.jackson.databind.annotation.JsonSerialize
import customfit.ai.kotlinclient.serialization.CustomDateDeserializer
import customfit.ai.kotlinclient.serialization.CustomDateSerializer
import customfit.ai.kotlinclient.analytics.event.EventType
import java.time.Instant

data class EventData(
        val event_customer_id: String,
        val event_type: EventType,
        val properties: Map<String, Any> = emptyMap(),
        @JsonDeserialize(using = CustomDateDeserializer::class)
        @JsonSerialize(using = CustomDateSerializer::class)
        val event_timestamp: Instant,
        val session_id: String?,
        val insert_id: String? = null
)
