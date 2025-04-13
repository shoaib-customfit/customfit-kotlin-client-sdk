// Fixed CFUser.kt
package customfit.ai.kotlinclient.core

import customfit.ai.kotlinclient.serialization.MapSerializer
import java.util.*
import kotlinx.serialization.Serializable

/**
 * Represents a context type for evaluation
 */
enum class ContextType {
    USER,
    DEVICE,
    SESSION,
    ORGANIZATION,
    CUSTOM
}

/**
 * An evaluation context that can be used for targeting
 */
@Serializable
data class EvaluationContext(
    /**
     * The context type
     */
    val type: ContextType,
    
    /**
     * Key identifying this context
     */
    val key: String,
    
    /**
     * Name of this context (optional)
     */
    val name: String? = null,
    
    /**
     * Properties associated with this context
     */
    @Serializable(with = MapSerializer::class)
    val properties: Map<String, Any> = emptyMap(),
    
    /**
     * Private attributes that should not be sent to analytics
     */
    val privateAttributes: List<String> = emptyList()
) {
    /**
     * Convert to a map for API requests
     */
    fun toMap(): Map<String, Any?> = mapOf(
        "type" to type.name.lowercase(),
        "key" to key,
        "name" to name,
        "properties" to properties,
        "private_attributes" to privateAttributes.takeIf { it.isNotEmpty() }
    ).filterValues { it != null }
    
    /**
     * Builder for EvaluationContext
     */
    class Builder(private val type: ContextType, private val key: String) {
        private var name: String? = null
        private val properties = mutableMapOf<String, Any>()
        private val privateAttributes = mutableListOf<String>()
        
        fun withName(name: String) = apply { this.name = name }
        
        fun withProperties(properties: Map<String, Any>) = apply {
            this.properties.putAll(properties)
        }
        
        fun withProperty(key: String, value: Any) = apply { 
            this.properties[key] = value 
        }
        
        fun withPrivateAttributes(attributes: List<String>) = apply {
            this.privateAttributes.addAll(attributes)
        }
        
        fun addPrivateAttribute(attribute: String) = apply {
            this.privateAttributes.add(attribute)
        }
        
        fun build(): EvaluationContext = EvaluationContext(
            type = type,
            key = key,
            name = name,
            properties = properties.toMap(),
            privateAttributes = privateAttributes.toList()
        )
    }
}

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

    /**
     * Add an evaluation context to the properties
     */
    fun addContext(context: EvaluationContext) {
        val contextsMap = (_properties["contexts"] as? MutableList<Map<String, Any?>>) ?: mutableListOf()
        contextsMap.add(context.toMap())
        _properties["contexts"] = contextsMap
    }

    /**
     * Get all evaluation contexts
     */
    fun getContexts(): List<EvaluationContext> {
        val contextsMap = _properties["contexts"] as? List<Map<String, Any?>> ?: return emptyList()
        return contextsMap.mapNotNull { contextMap -> 
            try {
                val type = contextMap["type"] as? String ?: return@mapNotNull null
                val key = contextMap["key"] as? String ?: return@mapNotNull null
                val name = contextMap["name"] as? String
                val properties = contextMap["properties"] as? Map<String, Any> ?: emptyMap()
                val privateAttributes = (contextMap["private_attributes"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                
                EvaluationContext(
                    type = ContextType.valueOf(type.uppercase()),
                    key = key,
                    name = name,
                    properties = properties,
                    privateAttributes = privateAttributes
                )
            } catch (e: Exception) {
                null
            }
        }
    }
    
    /**
     * Add device context to the properties
     */
    fun setDeviceContext(device: DeviceContext) {
        _properties["device"] = device.toMap()
    }
    
    /**
     * Get device context from properties
     */
    fun getDeviceContext(): DeviceContext? {
        val deviceMap = _properties["device"] as? Map<String, Any> ?: return null
        return DeviceContext.fromMap(deviceMap)
    }

    /**
     * Converts user data to a map for API requests
     */
    fun toUserMap(): Map<String, Any?> = mapOf(
        "user_customer_id" to user_customer_id,
        "anonymous" to anonymous,
        "private_fields" to
                private_fields?.let {
                    mapOf(
                            "userFields" to it.userFields,
                            "properties" to it.properties,
                    )
                },
        "session_fields" to
                session_fields?.let {
                    mapOf(
                            "userFields" to it.userFields,
                            "properties" to it.properties,
                    )
                },
        "properties" to properties
    ).filterValues { it != null }

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
        
        /**
         * Add an evaluation context for targeting
         */
        fun withContext(context: EvaluationContext) = apply {
            val contextsMap = (properties["contexts"] as? MutableList<Map<String, Any?>>) ?: mutableListOf()
            contextsMap.add(context.toMap())
            properties["contexts"] = contextsMap
        }
        
        /**
         * Add device context for targeting
         */
        fun withDeviceContext(device: DeviceContext) = apply {
            properties["device"] = device.toMap()
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
