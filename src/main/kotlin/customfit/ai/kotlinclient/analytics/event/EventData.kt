package customfit.ai.kotlinclient.analytics.event

import com.fasterxml.jackson.databind.annotation.JsonDeserialize
import com.fasterxml.jackson.databind.annotation.JsonSerialize
import customfit.ai.kotlinclient.serialization.CustomDateDeserializer
import customfit.ai.kotlinclient.serialization.CustomDateSerializer
import customfit.ai.kotlinclient.analytics.event.EventType
import customfit.ai.kotlinclient.logging.Timber
import java.time.Instant
import java.util.UUID

data class EventData(
        val event_customer_id: String,
        val event_type: EventType,
        val properties: Map<String, Any> = emptyMap(),
        @JsonDeserialize(using = CustomDateDeserializer::class)
        @JsonSerialize(using = CustomDateSerializer::class)
        val event_timestamp: Instant,
        val session_id: String?,
        val insert_id: String? = null
) {
    companion object {
        /**
         * Creates a validated EventData instance with proper error handling
         */
        fun create(
            eventCustomerId: String,
            eventType: EventType = EventType.TRACK,
            properties: Map<String, Any> = emptyMap(),
            timestamp: Instant = Instant.now(),
            sessionId: String? = null,
            insertId: String? = UUID.randomUUID().toString()
        ): EventData {
            // Validate and sanitize properties only
            val validProperties = validateProperties(properties)
            
            return EventData(
                event_customer_id = eventCustomerId,
                event_type = eventType,
                properties = validProperties,
                event_timestamp = timestamp,
                session_id = sessionId,
                insert_id = insertId
            )
        }
        
        /**
         * Validates the properties map, removing invalid entries
         */
        private fun validateProperties(properties: Map<String, Any>): Map<String, Any> {
            val validatedProps = properties.filterValues { it != null }
            
            if (validatedProps.size != properties.size) {
                Timber.w("Removed ${properties.size - validatedProps.size} null property values from event")
            }
            
            // Log warning for very large property maps
            if (validatedProps.size > 50) {
                Timber.w("Large number of properties (${validatedProps.size}) for event. Consider reducing for better performance")
            }
            
            return validatedProps
        }
    }
}
