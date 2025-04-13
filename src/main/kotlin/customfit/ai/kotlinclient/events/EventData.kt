package customfit.ai.kotlinclient.events

import com.fasterxml.jackson.databind.annotation.JsonDeserialize
import com.fasterxml.jackson.databind.annotation.JsonSerialize
import customfit.ai.kotlinclient.serialization.CustomDateDeserializer
import customfit.ai.kotlinclient.serialization.CustomDateSerializer
import java.util.*
import org.joda.time.DateTime

data class EventData(
        val event_customer_id: String,
        val event_type: EventType,
        val properties: Map<String, Any> = emptyMap(),
        @JsonDeserialize(using = CustomDateDeserializer::class)
        @JsonSerialize(using = CustomDateSerializer::class)
        val event_timestamp: DateTime,
        val session_id: String?,
        val insert_id: String? = null
)
