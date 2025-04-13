package customfit.ai.kotlinclient.core

import java.util.Date

abstract class PropertiesBuilder {
    internal val properties: MutableMap<String, Any> = mutableMapOf()

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

    protected fun Any?.isJsonCompatible(): Boolean =
            when (this) {
                null -> true
                is String, is Number, is Boolean -> true
                is Map<*, *> -> values.all { it.isJsonCompatible() }
                is Collection<*> -> all { it.isJsonCompatible() }
                else -> false
            }

    open fun build(): Map<String, Any> = properties.toMap()
} 