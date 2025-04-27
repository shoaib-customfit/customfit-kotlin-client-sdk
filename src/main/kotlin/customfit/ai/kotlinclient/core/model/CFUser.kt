package customfit.ai.kotlinclient.core.model

import customfit.ai.kotlinclient.serialization.MapSerializer
import java.util.*
import kotlinx.serialization.Contextual
import kotlinx.serialization.Serializable

/**
 * Represents a user for CustomFit.ai with dynamic properties, contexts, device, and application
 * info.
 */
@Serializable
data class CFUser(
        val user_customer_id: String? = null,
        val anonymous: Boolean = false,
        val private_fields: PrivateAttributesRequest? = PrivateAttributesRequest(),
        val session_fields: PrivateAttributesRequest? = PrivateAttributesRequest(),
        @Contextual
        @Serializable(with = MapSerializer::class)
        val properties: Map<String, @Contextual Any> = emptyMap(),
        val contexts: List<EvaluationContext> = emptyList(),
        val device: DeviceContext? = null,
        val application: ApplicationInfo? = null
) {
    /** Converts user data to a map for API requests. */
    fun toUserMap(): Map<String, Any?> {
        val updatedProperties = properties.toMutableMap()

        // Inject contexts, device, application into properties
        if (contexts.isNotEmpty()) {
            updatedProperties["contexts"] = contexts.map { it.toMap() }
        }
        device?.let { updatedProperties["device"] = it.toMap() }
        application?.let { updatedProperties["application"] = it.toMap() }

        return mapOf(
                        "user_customer_id" to user_customer_id,
                        "anonymous" to anonymous,
                        "private_fields" to private_fields?.properties?.takeIf { it.isNotEmpty() },
                        "session_fields" to session_fields?.properties?.takeIf { it.isNotEmpty() },
                        "properties" to updatedProperties
                )
                .filterValues { it != null }
    }

    companion object {
        @JvmStatic fun builder(user_customer_id: String) = Builder(user_customer_id)
    }

    /** Gets the device context if set */
    fun getDeviceContext(): DeviceContext? = device

    /** Sets the device context and returns a new CFUser instance */
    fun setDeviceContext(deviceContext: DeviceContext): CFUser {
        return copy(device = deviceContext)
    }

    /** Gets the application info if set */
    fun getApplicationInfo(): ApplicationInfo? = application

    /** Sets the application info and returns a new CFUser instance */
    fun setApplicationInfo(appInfo: ApplicationInfo): CFUser {
        return copy(application = appInfo)
    }

    /** Gets all current contexts */
    fun getAllContexts(): List<EvaluationContext> = contexts

    /** Adds a context and returns a new CFUser instance */
    fun addContext(context: EvaluationContext): CFUser {
        val updatedContexts = contexts.toMutableList()
        updatedContexts.add(context)
        return copy(contexts = updatedContexts)
    }

    /** Gets all current properties */
    fun getCurrentProperties(): Map<String, Any> = properties

    /** Adds a property and returns a new CFUser instance */
    fun addProperty(key: String, value: Any): CFUser {
        val updatedProperties = properties.toMutableMap()
        updatedProperties[key] = value
        return copy(properties = updatedProperties)
    }

    /** Adds multiple properties and returns a new CFUser instance */
    fun addProperties(newProperties: Map<String, Any>): CFUser {
        val updatedProperties = properties.toMutableMap()
        updatedProperties.putAll(newProperties)
        return copy(properties = updatedProperties)
    }

    /** Builder for constructing a CFUser with fluent API. */
    class Builder(private val user_customer_id: String) {
        private var anonymous: Boolean = false
        private var private_fields: PrivateAttributesRequest? = PrivateAttributesRequest()
        private var session_fields: PrivateAttributesRequest? = PrivateAttributesRequest()
        private val properties: MutableMap<String, Any> = mutableMapOf()
        private val contexts: MutableList<EvaluationContext> = mutableListOf()
        private var device: DeviceContext? = null
        private var application: ApplicationInfo? = null

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
            properties[key] = value.filterValues { it.isJsonCompatible() }
        }
        fun withContext(context: EvaluationContext) = apply { contexts += context }
        fun withDeviceContext(device: DeviceContext) = apply { this.device = device }
        fun withApplicationInfo(application: ApplicationInfo) = apply {
            this.application = application
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
                        user_customer_id = user_customer_id,
                        anonymous = anonymous,
                        private_fields = private_fields,
                        session_fields = session_fields,
                        properties = properties.toMap(),
                        contexts = contexts.toList(),
                        device = device,
                        application = application
                )
    }
}
