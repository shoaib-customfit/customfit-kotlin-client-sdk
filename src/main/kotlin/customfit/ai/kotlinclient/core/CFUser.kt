// Fixed CFUser.kt
package customfit.ai.kotlinclient.core

import customfit.ai.kotlinclient.serialization.MapSerializer
import java.util.*
import kotlinx.serialization.Serializable

@Serializable
data class CFUser(
        val user_customer_id: String?,
        val anonymous: Boolean,
        val private_fields: PrivateAttributesRequest?= PrivateAttributesRequest(),
        val session_fields: PrivateAttributesRequest?= PrivateAttributesRequest(),
        @Serializable(with = MapSerializer::class) val properties: Map<String, Any>
) {
    // Mutable properties map to allow updates after creation
    @kotlinx.serialization.Transient
    private val _properties: MutableMap<String, Any> = properties.toMutableMap()
    
    // Update a single property
    fun addProperty(key: String, value: Any) {
        _properties[key] = value
    }
    
    // Update multiple properties at once
    fun addProperties(properties: Map<String, Any>) {
        _properties.putAll(properties)
    }
    
    // Get the latest properties including any updates
    fun getCurrentProperties(): Map<String, Any> = _properties.toMap()

    companion object {
        @JvmStatic fun builder(user_customer_id: String) = Builder(user_customer_id)
    }

    class Builder(private val user_customer_id: String) {
        private var anonymous: Boolean = false
        private var private_fields: PrivateAttributesRequest? = PrivateAttributesRequest()
        private var session_fields: PrivateAttributesRequest? = PrivateAttributesRequest()
        private val properties: MutableMap<String, Any> = mutableMapOf()

        fun makeAnonymous(anonymous: Boolean) = apply { this.anonymous = anonymous }

        fun withPrivateFields(private_fields: PrivateAttributesRequest) = apply {
            this.private_fields = private_fields
        }

        fun withSessionFields(session_fields: PrivateAttributesRequest) = apply {
            this.session_fields = session_fields
        }

        fun withProperties(properties: Map<String, Any>) = apply {
            this.properties.putAll(properties)
        }

        fun withNumberProperty(key: String, value: Number) = apply { properties[key] = value }

        fun withStringProperty(key: String, value: String) = apply {
            require(value.isNotBlank()) { "String value for '$key' cannot be blank" }
            properties[key] = value
        }

        fun withBooleanProperty(key: String, value: Boolean) = apply { properties[key] = value }

        fun withDateProperty(key: String, value: Date) = apply { properties[key] = value }

        fun withGeoPointProperty(key: String, lat: Double, lon: Double) = apply {
            properties[key] = mapOf("lat" to lat, "lon" to lon)
        }

        fun withJsonProperty(key: String, value: Map<String, Any>) = apply {
            require(value.keys.all { it is String }) { "JSON for '$key' must have String keys" }
            properties[key] = value.filterValues { it.isJsonCompatible() }
        }

        private fun Any?.isJsonCompatible(): Boolean =
                when (this) {
                    null -> true
                    is String, is Number, is Boolean -> true
                    is Map<*, *> ->
                            keys.all { it is String } && values.all { it.isJsonCompatible() }
                    is Collection<*> -> all { it.isJsonCompatible() }
                    else -> false
                }

        fun build(): CFUser =
                CFUser(
                        user_customer_id,
                        anonymous,
                        private_fields,
                        session_fields,
                        properties.toMap()
                )
    }
}

@Serializable
data class PrivateAttributesRequest(
        val userFields: List<String> = emptyList(),
        val properties: List<String> = emptyList(),
)
