package customfit.ai.kotlinclient.serialization

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.*

/** Custom serializer for Map<String, Any> */
object MapSerializer : KSerializer<Map<String, Any>> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("Map")

    override fun serialize(encoder: Encoder, value: Map<String, Any>) {
        val jsonObject =
                JsonObject(
                        value.mapValues { (_, v) ->
                            when (v) {
                                is String -> JsonPrimitive(v)
                                is Number -> JsonPrimitive(v)
                                is Boolean -> JsonPrimitive(v)
                                is JsonElement -> v
                                else -> JsonPrimitive(v.toString()) // fallback
                            }
                        }
                )
        if (encoder is JsonEncoder) {
            encoder.encodeJsonElement(jsonObject)
        } else {
            encoder.encodeString(Json.encodeToString(JsonObject.serializer(), jsonObject))
        }
    }

    override fun deserialize(decoder: Decoder): Map<String, Any> {
        val jsonElement =
                if (decoder is JsonDecoder) {
                    decoder.decodeJsonElement()
                } else {
                    Json.decodeFromString(JsonObject.serializer(), decoder.decodeString())
                }

        return if (jsonElement is JsonObject) {
            jsonElement.toMap()
        } else {
            emptyMap()
        }
    }

    private fun JsonObject.toMap(): Map<String, Any> {
        return this.mapValues { (_, value) ->
            when (value) {
                is JsonPrimitive ->
                        when {
                            value.isString -> value.content
                            value.booleanOrNull != null -> value.boolean
                            value.intOrNull != null -> value.int
                            value.longOrNull != null -> value.long
                            value.doubleOrNull != null -> value.double
                            else -> value.content
                        }
                is JsonObject -> value.toMap()
                is JsonArray -> value.toList()
                else -> "" // fallback
            }
        }
    }

    private fun JsonArray.toList(): List<Any> {
        return this.map { element ->
            when (element) {
                is JsonPrimitive ->
                        when {
                            element.isString -> element.content
                            element.booleanOrNull != null -> element.boolean
                            element.intOrNull != null -> element.int
                            element.longOrNull != null -> element.long
                            element.doubleOrNull != null -> element.double
                            else -> element.content
                        }
                is JsonObject -> element.toMap()
                is JsonArray -> element.toList()
                else -> "" // fallback
            }
        }
    }
}
