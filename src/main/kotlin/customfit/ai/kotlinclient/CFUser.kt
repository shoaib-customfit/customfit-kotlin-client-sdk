package customfit.ai.kotlinclient

import java.util.*

data class CFUser private constructor(
    val userCustomerId: String?,
    val anonymous: Boolean,
    val privateFields: PrivateAttributesRequest?,
    val sessionFields: PrivateAttributesRequest?,
    val properties: Map<String, Any>
) {
    companion object {
        @JvmStatic
        fun builder(userCustomerId: String) = Builder(userCustomerId)
    }

    // Initialize properties from the builder in the constructor
    init {
        // Logic to initialize any required fields
    }

    class Builder(private val userCustomerId: String) {
        private var anonymous: Boolean = false
        private var privateFields: PrivateAttributesRequest? = null
        private var sessionFields: PrivateAttributesRequest? = null
        private var properties: MutableMap<String, Any> = mutableMapOf()

        // Method to set anonymity flag
        fun makeAnonymous(anonymous: Boolean) = apply { this.anonymous = anonymous }

        // Method to set private fields
        fun withPrivateFields(privateFields: PrivateAttributesRequest) = apply {
            this.privateFields = privateFields
        }

        // Method to set session fields
        fun withSessionFields(sessionFields: PrivateAttributesRequest) = apply {
            this.sessionFields = sessionFields
        }

        // Method to add properties
        fun withProperties(properties: Map<String, Any>) = apply { this.properties.putAll(properties) }

        // -- Type-Specific Methods --
        // Add number properties
        fun withNumberProperty(key: String, value: Number) = apply {
            validateType(key, value)
            this.properties[key] = value
        }

        // Add string properties
        fun withStringProperty(key: String, value: String) = apply {
            validateType(key, value)
            this.properties[key] = value
        }

        // Add boolean properties
        fun withBooleanProperty(key: String, value: Boolean) = apply {
            validateType(key, value)
            this.properties[key] = value
        }

        // Add date properties
        fun withDateProperty(key: String, value: Date) = apply {
            validateType(key, value)
            this.properties[key] = value
        }

        // Add geo point properties (latitude and longitude)
        fun withGeoPointProperty(key: String, lat: Double, lon: Double) = apply {
            this.properties[key] = mapOf("lat" to lat, "lon" to lon)
        }

        // -- Type-Agnostic Methods (No value parameter) --
        // Add property with type-agnostic validation
        fun withProperty(key: String) = apply {
            this.properties[key] = Any()
        }

        // Add private property with type-agnostic validation (no value parameter)
        fun withPrivateProperty(key: String) = apply {
            this.properties[key] = Any()
            this.privateFields?.properties?.add(key)
        }

        // Add session property with type-agnostic validation (no value parameter)
        fun withSessionProperty(key: String) = apply {
            this.properties[key] = Any()
            this.sessionFields?.properties?.add(key)
        }

         fun withJsonProperty(key: String, value: Map<String, Any>) = apply {
            if (value !is Map<*, *>) {
                throw IllegalArgumentException("Value for $key must be a Map<String, Any>")
            }
            this.properties[key] = value
        }

        // Add private JSON property (Map<String, Any>) to private fields
        fun withPrivateJsonProperty(key: String, value: Map<String, Any>) = apply {
            if (value !is Map<*, *>) {
                throw IllegalArgumentException("Value for $key must be a Map<String, Any>")
            }
            this.properties[key] = value
            this.privateFields?.properties?.add(key)
        }

        // Add session JSON property (Map<String, Any>) to session fields
        fun withSessionJsonProperty(key: String, value: Map<String, Any>) = apply {
            if (value !is Map<*, *>) {
                throw IllegalArgumentException("Value for $key must be a Map<String, Any>")
            }
            this.properties[key] = value
            this.sessionFields?.properties?.add(key)
        }

        // Helper function to validate type for type-specific properties
        private fun validateType(key: String, value: Any) {
            
            when (value) {
                    is Number -> {
                        // Allow any number (Integer, Double, etc.)
                    }
                    is String -> {
                        // Allow non-blank strings
                        if (value.isBlank()) {
                            throw IllegalArgumentException("String value for property '$key' cannot be blank")
                        }
                    }
                    is Boolean -> {
                        // Allow boolean values
                    }
                    is Date -> {
                        // Allow Date objects
                    }
                    is Map<*, *> -> {
                        // Check if it's a valid JSON object (Map<String, Any>)
                        if (value.keys.any { it !is String }) {
                            throw IllegalArgumentException("JSON for property '$key' must have String keys")
                        }
                    }
                    else -> {
                        // Catch any unsupported types
                        throw IllegalArgumentException("Unsupported type for property '$key': ${value::class.simpleName}")
                    }
                }
        }

        fun build(): CFUser {
            return CFUser(
                userCustomerId,
                anonymous,
                privateFields,
                sessionFields,
                properties
            )
        }
    }
}

data class PrivateAttributesRequest(
    val userFields: List<String> = mutableListOf(),
    val properties: MutableList<String> = mutableListOf(),
    val tags: List<String> = mutableListOf()
)