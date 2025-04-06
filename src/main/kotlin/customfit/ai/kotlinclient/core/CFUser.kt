package customfit.ai.kotlinclient.core

import java.util.*

data class CFUser(
        val user_customer_id: String?,
        val anonymous: Boolean,
        val private_fields: PrivateAttributesRequest?,
        val session_fields: PrivateAttributesRequest?,
        val properties: Map<String, Any>
) {
    companion object {
        @JvmStatic fun builder(user_customer_id: String) = Builder(user_customer_id)
    }

    class Builder(private val user_customer_id: String) {
        private var anonymous: Boolean = false
        private var private_fields: PrivateAttributesRequest? = null
        private var session_fields: PrivateAttributesRequest? = null
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
        fun withJsonProperty(key: String, value: Map<String, Any?>) = apply {
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

data class PrivateAttributesRequest(
        val userFields: List<String> = emptyList(), // Immutable
        val properties: List<String> = emptyList(), // Immutable
        val tags: List<String> = emptyList() // Immutable
)
