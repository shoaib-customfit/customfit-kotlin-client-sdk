package customfit.ai.kotlinclient.core.util

abstract class PropertiesBuilder {
    private val properties = mutableMapOf<String, Any>()

    fun addProperty(key: String, value: Any) {
        properties[key] = value
    }

    fun addStringProperty(key: String, value: String) {
        require(value.isNotBlank()) { "String value for '$key' cannot be blank" }
        addProperty(key, value)
    }

    fun addNumberProperty(key: String, value: Number) {
        addProperty(key, value)
    }

    fun addBooleanProperty(key: String, value: Boolean) {
        addProperty(key, value)
    }

    fun addJsonProperty(key: String, value: Map<String, Any>) {
        addProperty(key, value)
    }

    open fun build(): Map<String, Any> = properties.toMap()
}
