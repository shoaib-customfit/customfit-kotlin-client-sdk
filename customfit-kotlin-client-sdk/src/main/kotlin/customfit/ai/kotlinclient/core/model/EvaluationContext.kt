package customfit.ai.kotlinclient.core.model

import customfit.ai.kotlinclient.serialization.MapSerializer
import kotlinx.serialization.Contextual
import kotlinx.serialization.Serializable

/** Represents a context type for evaluation */
enum class ContextType {
    USER,
    DEVICE,
    SESSION,
    ORGANIZATION,
    CUSTOM
}

/** An evaluation context that can be used for targeting */
@Serializable
data class EvaluationContext(
        /** The context type */
        val type: ContextType,

        /** Key identifying this context */
        val key: String,

        /** Name of this context (optional) */
        val name: String? = null,

        /** Properties associated with this context */
        @Contextual
        @Serializable(with = MapSerializer::class) 
        val properties: Map<String, @Contextual Any> = emptyMap(),

        /** Private attributes that should not be sent to analytics */
        val privateAttributes: List<String> = emptyList()
) {
    /** Convert to a map for API requests */
    fun toMap(): Map<String, Any?> =
            mapOf(
                            "type" to type.name.lowercase(),
                            "key" to key,
                            "name" to name,
                            "properties" to properties,
                            "private_attributes" to privateAttributes.takeIf { it.isNotEmpty() }
                    )
                    .filterValues { it != null }

    /** Builder for EvaluationContext */
    class Builder(private val type: ContextType, private val key: String) {
        private var name: String? = null
        private val properties = mutableMapOf<String, Any>()
        private val privateAttributes = mutableListOf<String>()

        fun withName(name: String) = apply { this.name = name }

        fun withProperties(properties: Map<String, Any>) = apply {
            this.properties.putAll(properties)
        }

        fun withProperty(key: String, value: Any) = apply { this.properties[key] = value }

        fun withPrivateAttributes(attributes: List<String>) = apply {
            this.privateAttributes.addAll(attributes)
        }

        fun addPrivateAttribute(attribute: String) = apply { this.privateAttributes.add(attribute) }

        fun build(): EvaluationContext =
                EvaluationContext(
                        type = type,
                        key = key,
                        name = name,
                        properties = properties.toMap(),
                        privateAttributes = privateAttributes.toList()
                )
    }
}
