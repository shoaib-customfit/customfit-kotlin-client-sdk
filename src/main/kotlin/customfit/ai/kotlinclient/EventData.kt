package customfit.ai.kotlinclient

import com.fasterxml.jackson.databind.annotation.JsonDeserialize
import com.fasterxml.jackson.databind.annotation.JsonSerialize
import org.joda.time.DateTime
import java.util.*

data class EventData(
    val event_customer_id: String,
    val event_type: EventType, // Should be of type TRACK
    val properties: Map<String, Any> = mutableMapOf(),  // Change to Map instead of MutableMap
    
    @JsonDeserialize(using = CustomDateDeserializer::class)
    @JsonSerialize(using = CustomDateSerializer::class)
    val event_timestamp: DateTime,
    
    val session_id: String?,
    val timeuuid: UUID = UUID.randomUUID(),
    val insert_id: String? = null
)
