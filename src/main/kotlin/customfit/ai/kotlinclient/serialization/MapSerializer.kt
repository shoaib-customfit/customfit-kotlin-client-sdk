// MapSerializer.kt
package customfit.ai.kotlinclient.serialization

import kotlinx.serialization.*
import kotlinx.serialization.descriptors.*
import kotlinx.serialization.encoding.*
import kotlinx.serialization.json.*

/**
 * Custom serializer for Map<String, Any>
 */
object MapSerializer : KSerializer<Map<String, Any>> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("Map")

    override fun serialize(encoder: Encoder, value: Map<String, Any>) {
        // Convert to JsonObject first
        val jsonObject = JsonObject(
            value.mapValues { (_, v) ->
                when (v) {
                    is String -> JsonPrimitive(v)
                    is Number -> JsonPrimitive(v)
                    is Boolean -> JsonPrimitive(v)
                    is JsonElement -> v // Keep JsonElement as is
                    null -> JsonNull
                    else -> JsonPrimitive(v.toString()) // Convert other types to strings
                }
            }
        )
        
        // Use Json encoder directly when possible
        if (encoder is JsonEncoder) {
            encoder.encodeJsonElement(jsonObject)
        } else {
            // Fallback for non-JSON encoders
            encoder.encodeString(Json.encodeToString(JsonObject.serializer(), jsonObject))
        }
    }

    override fun deserialize(decoder: Decoder): Map<String, Any> {
        // Handle JSON format
        return if (decoder is JsonDecoder) {
            val jsonElement = decoder.decodeJsonElement()
            if (jsonElement !is JsonObject) {
                emptyMap()
            } else {
                jsonElement.mapValues { (_, value) ->
                    when {
                        value is JsonPrimitive && value.isString -> value.content
                        value is JsonPrimitive && value.booleanOrNull != null -> value.boolean
                        value is JsonPrimitive && value.intOrNull != null -> value.int
                        value is JsonPrimitive && value.longOrNull != null -> value.long
                        value is JsonPrimitive && value.doubleOrNull != null -> value.double
                        value is JsonObject -> value.toMap()
                        value is JsonArray -> value.toList()
                        else -> "" as Any // Empty string as a fallback
                    }
                }
            }
        } else {
            try {
                val jsonString = decoder.decodeString()
                val jsonObject = Json.decodeFromString(JsonObject.serializer(), jsonString)
                jsonObject.mapValues { (_, value) ->
                    when {
                        value is JsonPrimitive && value.isString -> value.content
                        value is JsonPrimitive && value.booleanOrNull != null -> value.boolean
                        value is JsonPrimitive && value.intOrNull != null -> value.int
                        value is JsonPrimitive && value.longOrNull != null -> value.long
                        value is JsonPrimitive && value.doubleOrNull != null -> value.double
                        value is JsonObject -> value.toMap()
                        value is JsonArray -> value.toList()
                        else -> "" as Any
                    }
                }
            } catch (e: Exception) {
                emptyMap()
            }
        }
    }
    
    // Helper extension function to convert JsonObject to Map
    private fun JsonObject.toMap(): Map<String, Any> {
        return this.mapValues { (_, value) -> 
            when {
                value is JsonPrimitive && value.isString -> value.content
                value is JsonPrimitive && value.booleanOrNull != null -> value.boolean
                value is JsonPrimitive && value.intOrNull != null -> value.int
                value is JsonPrimitive && value.longOrNull != null -> value.long
                value is JsonPrimitive && value.doubleOrNull != null -> value.double
                value is JsonObject -> value.toMap()
                value is JsonArray -> value.toList()
                else -> "" as Any // Empty string as a fallback
            }
        }
    }
    
    // Helper extension function to convert JsonArray to List
    private fun JsonArray.toList(): List<Any> {
        return this.map { element ->
            when {
                element is JsonPrimitive && element.isString -> element.content
                element is JsonPrimitive && element.booleanOrNull != null -> element.boolean
                element is JsonPrimitive && element.intOrNull != null -> element.int
                element is JsonPrimitive && element.longOrNull != null -> element.long
                element is JsonPrimitive && element.doubleOrNull != null -> element.double
                element is JsonObject -> element.toMap()
                element is JsonArray -> element.toList()
                else -> "" as Any // Empty string as a fallback
            }
        }
    }
}