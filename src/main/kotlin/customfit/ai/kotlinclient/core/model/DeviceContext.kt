package customfit.ai.kotlinclient.core.model

import java.util.*
import kotlinx.serialization.Contextual
import kotlinx.serialization.Serializable
import customfit.ai.kotlinclient.serialization.MapSerializer

/** Represents device and operating system information for context-aware evaluation. */
@Serializable
data class DeviceContext(
        /** Device manufacturer */
        val manufacturer: String? = null,

        /** Device model */
        val model: String? = null,

        /** Operating system name (e.g., "Android", "iOS") */
        val osName: String? = null,

        /** Operating system version */
        val osVersion: String? = null,

        /** SDK version */
        val sdkVersion: String = "1.0.0",

        /** Application identifier */
        val appId: String? = null,

        /** Application version */
        val appVersion: String? = null,

        /** Device locale */
        val locale: String? = Locale.getDefault().toString(),

        /** Device timezone */
        val timezone: String? = TimeZone.getDefault().id,

        /** Device screen width in pixels */
        val screenWidth: Int? = null,

        /** Device screen height in pixels */
        val screenHeight: Int? = null,

        /** Device screen density (DPI) */
        val screenDensity: Float? = null,

        /** Network type (e.g., "wifi", "cellular") */
        val networkType: String? = null,

        /** Network carrier */
        val networkCarrier: String? = null,

        /** Additional custom attributes */
        @Contextual
        @Serializable(with = MapSerializer::class)
        val customAttributes: Map<String, @Contextual Any> = emptyMap()
) {
    companion object {
        /** Creates a basic device context with system properties */
        fun createBasic(): DeviceContext {
            val systemProps = System.getProperties()

            return DeviceContext(
                    osName = systemProps.getProperty("os.name"),
                    osVersion = systemProps.getProperty("os.version"),
                    locale = Locale.getDefault().toString(),
                    timezone = TimeZone.getDefault().id
            )
        }

        /** Creates a DeviceContext from a map representation */
        fun fromMap(map: Map<String, Any>): DeviceContext {
            return DeviceContext(
                    manufacturer = map["manufacturer"] as? String,
                    model = map["model"] as? String,
                    osName = map["os_name"] as? String,
                    osVersion = map["os_version"] as? String,
                    sdkVersion = (map["sdk_version"] as? String) ?: "1.0.0",
                    appId = map["app_id"] as? String,
                    appVersion = map["app_version"] as? String,
                    locale = map["locale"] as? String,
                    timezone = map["timezone"] as? String,
                    screenWidth = (map["screen_width"] as? Number)?.toInt(),
                    screenHeight = (map["screen_height"] as? Number)?.toInt(),
                    screenDensity = (map["screen_density"] as? Number)?.toFloat(),
                    networkType = map["network_type"] as? String,
                    networkCarrier = map["network_carrier"] as? String,
                    customAttributes = (map["custom_attributes"] as? Map<*, *>)?.mapNotNull { (key, value) ->
                        if (key is String && value != null) key to value
                        else null
                    }?.toMap() ?: emptyMap()
            )
        }
    }

    /** Converts the device context to a map for sending to the API */
    fun toMap(): Map<String, Any?> =
            mapOf(
                            "manufacturer" to manufacturer,
                            "model" to model,
                            "os_name" to osName,
                            "os_version" to osVersion,
                            "sdk_version" to sdkVersion,
                            "app_id" to appId,
                            "app_version" to appVersion,
                            "locale" to locale,
                            "timezone" to timezone,
                            "screen_width" to screenWidth,
                            "screen_height" to screenHeight,
                            "screen_density" to screenDensity,
                            "network_type" to networkType,
                            "network_carrier" to networkCarrier,
                            "custom_attributes" to customAttributes
                    )
                    .filterValues { it != null }

    /** Builder for creating DeviceContext instances */
    class Builder {
        private var manufacturer: String? = null
        private var model: String? = null
        private var osName: String? = System.getProperty("os.name")
        private var osVersion: String? = System.getProperty("os.version")
        private var sdkVersion: String = "1.0.0"
        private var appId: String? = null
        private var appVersion: String? = null
        private var locale: String? = Locale.getDefault().toString()
        private var timezone: String? = TimeZone.getDefault().id
        private var screenWidth: Int? = null
        private var screenHeight: Int? = null
        private var screenDensity: Float? = null
        private var networkType: String? = null
        private var networkCarrier: String? = null
        private val customAttributes = mutableMapOf<String, Any>()

        fun manufacturer(manufacturer: String) = apply { this.manufacturer = manufacturer }
        fun model(model: String) = apply { this.model = model }
        fun osName(osName: String) = apply { this.osName = osName }
        fun osVersion(osVersion: String) = apply { this.osVersion = osVersion }
        fun sdkVersion(sdkVersion: String) = apply { this.sdkVersion = sdkVersion }
        fun appId(appId: String) = apply { this.appId = appId }
        fun appVersion(appVersion: String) = apply { this.appVersion = appVersion }
        fun locale(locale: String) = apply { this.locale = locale }
        fun timezone(timezone: String) = apply { this.timezone = timezone }
        fun screenWidth(screenWidth: Int) = apply { this.screenWidth = screenWidth }
        fun screenHeight(screenHeight: Int) = apply { this.screenHeight = screenHeight }
        fun screenDensity(screenDensity: Float) = apply { this.screenDensity = screenDensity }
        fun networkType(networkType: String) = apply { this.networkType = networkType }
        fun networkCarrier(networkCarrier: String) = apply { this.networkCarrier = networkCarrier }

        /** Add a custom attribute */
        fun addCustomAttribute(key: String, value: Any) = apply {
            this.customAttributes[key] = value
        }

        /** Add multiple custom attributes */
        fun addCustomAttributes(attributes: Map<String, String>) = apply {
            this.customAttributes.putAll(attributes)
        }

        /** Build the DeviceContext */
        fun build(): DeviceContext =
                DeviceContext(
                        manufacturer = manufacturer,
                        model = model,
                        osName = osName,
                        osVersion = osVersion,
                        sdkVersion = sdkVersion,
                        appId = appId,
                        appVersion = appVersion,
                        locale = locale,
                        timezone = timezone,
                        screenWidth = screenWidth,
                        screenHeight = screenHeight,
                        screenDensity = screenDensity,
                        networkType = networkType,
                        networkCarrier = networkCarrier,
                        customAttributes = customAttributes.toMap()
                )
    }
}
