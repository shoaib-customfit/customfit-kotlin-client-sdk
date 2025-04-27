package customfit.ai.kotlinclient.core.model

import java.text.SimpleDateFormat
import java.util.*
import kotlinx.serialization.Serializable

/** Collects and stores information about the application for use in targeting and analytics. */
@Serializable
data class ApplicationInfo(
        /** Application name */
        val appName: String? = null,

        /** Application package name/identifier */
        val packageName: String? = null,

        /** Application version name (e.g., "1.2.3") */
        val versionName: String? = null,

        /** Application version code (numeric) */
        val versionCode: Int? = null,

        /** When the app was first installed */
        val installDate: String? = null,

        /** When the app was last updated */
        val lastUpdateDate: String? = null,

        /** Build type (e.g., "debug", "release") */
        val buildType: String? = null,

        /** How many times the app has been launched */
        val launchCount: Int = 1,

        /** Additional custom attributes */
        val customAttributes: Map<String, String> = emptyMap()
) {
    /** Converts the application info to a map for serialization */
    fun toMap(): Map<String, Any?> =
            mapOf(
                            "app_name" to appName,
                            "package_name" to packageName,
                            "version_name" to versionName,
                            "version_code" to versionCode,
                            "install_date" to installDate,
                            "last_update_date" to lastUpdateDate,
                            "build_type" to buildType,
                            "launch_count" to launchCount,
                            "custom_attributes" to customAttributes
                    )
                    .filterValues { it != null }

    companion object {
        /** Creates an ApplicationInfo from a map representation */
        fun fromMap(map: Map<String, Any>): ApplicationInfo {
            val rawCustomAttributes = map["custom_attributes"]
            val customAttributes =
                    when (rawCustomAttributes) {
                        is Map<*, *> -> {
                            rawCustomAttributes
                                    .entries
                                    .mapNotNull { (k, v) ->
                                        val key = k as? String
                                        val value = v as? String
                                        if (key != null && value != null) key to value else null
                                    }
                                    .toMap()
                        }
                        else -> emptyMap()
                    }

            return ApplicationInfo(
                    appName = map["app_name"] as? String,
                    packageName = map["package_name"] as? String,
                    versionName = map["version_name"] as? String,
                    versionCode = (map["version_code"] as? Number)?.toInt(),
                    installDate = map["install_date"] as? String,
                    lastUpdateDate = map["last_update_date"] as? String,
                    buildType = map["build_type"] as? String,
                    launchCount = (map["launch_count"] as? Number)?.toInt() ?: 0,
                    customAttributes = customAttributes
            )
        }
    }

    /** Builder for ApplicationInfo */
    class Builder {
        private var appName: String? = null
        private var packageName: String? = null
        private var versionName: String? = null
        private var versionCode: Int? = null
        private var installDate: String? = null
        private var lastUpdateDate: String? = null
        private var buildType: String? = null
        private var launchCount: Int = 1
        private val customAttributes = mutableMapOf<String, String>()

        fun appName(appName: String) = apply { this.appName = appName }
        fun packageName(packageName: String) = apply { this.packageName = packageName }
        fun versionName(versionName: String) = apply { this.versionName = versionName }
        fun versionCode(versionCode: Int) = apply { this.versionCode = versionCode }
        fun installDate(installDate: Date) = apply {
            this.installDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(installDate)
        }
        fun lastUpdateDate(lastUpdateDate: Date) = apply {
            this.lastUpdateDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(lastUpdateDate)
        }
        fun buildType(buildType: String) = apply { this.buildType = buildType }
        fun launchCount(launchCount: Int) = apply { this.launchCount = launchCount }

        /** Add a custom attribute */
        fun addCustomAttribute(key: String, value: String) = apply {
            this.customAttributes[key] = value
        }

        /** Add multiple custom attributes */
        fun addCustomAttributes(attributes: Map<String, String>) = apply {
            this.customAttributes.putAll(attributes)
        }

        /** Build the ApplicationInfo */
        fun build(): ApplicationInfo =
                ApplicationInfo(
                        appName = appName,
                        packageName = packageName,
                        versionName = versionName,
                        versionCode = versionCode,
                        installDate = installDate,
                        lastUpdateDate = lastUpdateDate,
                        buildType = buildType,
                        launchCount = launchCount,
                        customAttributes = customAttributes.toMap()
                )
    }
}
