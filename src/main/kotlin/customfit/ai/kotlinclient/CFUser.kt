package customfit.ai.kotlinclient

import java.util.*

data class CFUser(
        val userCustomerId: String?,
        val anonymous: Boolean,
        val privateFields: PrivateAttributesRequest?,
        val sessionFields: PrivateAttributesRequest?,
        val properties: Map<String, Any>
) {

    companion object {
        @JvmStatic fun builder(userCustomerId: String) = Builder(userCustomerId)
    }

    class Builder(private val userCustomerId: String) {
        private var anonymous: Boolean = false
        private var privateFields: PrivateAttributesRequest? = null
        private var sessionFields: PrivateAttributesRequest? = null
        private var properties: MutableMap<String, Any> = mutableMapOf()

        fun makeAnonymous(anonymous: Boolean) = apply { this.anonymous = anonymous }
        fun withPrivateFields(privateFields: PrivateAttributesRequest) = apply {
            this.privateFields = privateFields
        }
        fun withSessionFields(sessionFields: PrivateAttributesRequest) = apply {
            this.sessionFields = sessionFields
        }
        fun withProperties(properties: Map<String, Any>) = apply {
            this.properties.putAll(properties)
        }

        fun withNumberProperty(key: String, value: Number) = apply {
            validateType(key, value)
            this.properties[key] = value
        }

        fun withStringProperty(key: String, value: String) = apply {
            validateType(key, value)
            this.properties[key] = value
        }

        fun withBooleanProperty(key: String, value: Boolean) = apply {
            validateType(key, value)
            this.properties[key] = value
        }

        fun withDateProperty(key: String, value: Date) = apply {
            validateType(key, value)
            this.properties[key] = value
        }

        fun withGeoPointProperty(key: String, lat: Double, lon: Double) = apply {
            this.properties[key] = mapOf("lat" to lat, "lon" to lon)
        }

        fun withProperty(key: String) = apply { this.properties[key] = Any() }
        fun withPrivateProperty(key: String) = apply {
            this.properties[key] = Any()
            this.privateFields?.properties?.add(key)
        }
        fun withSessionProperty(key: String) = apply {
            this.properties[key] = Any()
            this.sessionFields?.properties?.add(key)
        }

        fun withJsonProperty(key: String, value: Map<String, Any?>) = apply {
            require(value.values.all { it.isJsonCompatible() }) {
                "Value for $key contains non-JSON-serializable types"
            }
            this.properties[key] = value
        }

        private fun Any?.isJsonCompatible(): Boolean =
                when (this) {
                    null -> true
                    is String, is Number, is Boolean -> true
                    is Map<*, *> -> this.values.all { it.isJsonCompatible() }
                    is Collection<*> -> this.all { it.isJsonCompatible() }
                    else -> false
                }

        fun withPrivateJsonProperty(key: String, value: Map<String, Any>) = apply {
            require(value.values.all { it.isJsonCompatible() }) {
                "Value for $key contains non-JSON-serializable types"
            }
            this.properties[key] = value
            this.privateFields?.properties?.add(key)
        }

        fun withSessionJsonProperty(key: String, value: Map<String, Any>) = apply {
            require(value.values.all { it.isJsonCompatible() }) {
                "Value for $key contains non-JSON-serializable types"
            }
            this.properties[key] = value
            this.sessionFields?.properties?.add(key)
        }

        private fun validateType(key: String, value: Any) {
            when (value) {
                is Number -> {
                    /* Allow any number (Integer, Double, etc.) */
                }
                is String -> {
                    if (value.isBlank())
                            throw IllegalArgumentException(
                                    "String value for property '$key' cannot be blank"
                            )
                }
                is Boolean -> {
                    /* Allow boolean values */
                }
                is Date -> {
                    /* Allow Date objects */
                }
                is Map<*, *> -> {
                    if (value.keys.any { it !is String })
                            throw IllegalArgumentException(
                                    "JSON for property '$key' must have String keys"
                            )
                }
                else -> {
                    throw IllegalArgumentException(
                            "Unsupported type for property '$key': ${value::class.simpleName}"
                    )
                }
            }
        }

        fun build(): CFUser {
            return CFUser(userCustomerId, anonymous, privateFields, sessionFields, properties)
        }
    }
}

data class PrivateAttributesRequest(
        val userFields: List<String> = mutableListOf(),
        val properties: MutableList<String> = mutableListOf(),
        val tags: List<String> = mutableListOf()
)
