package customfit.ai.kotlinclient.platform

import customfit.ai.kotlinclient.core.model.ApplicationInfo
import customfit.ai.kotlinclient.logging.Timber
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/** Utility class to detect application information from the runtime environment */
object ApplicationInfoDetector {

    private var cachedAppInfo: ApplicationInfo? = null
    private var lastUpdateCheck: Long = 0L
    private const val UPDATE_CHECK_INTERVAL = 5 * 60 * 1000L // 5 minutes

    /**
     * Try to detect application information from the runtime environment
     *
     * @param forceRefresh Whether to force a refresh of the cached info
     * @return ApplicationInfo or null if detection fails
     */
    fun detectApplicationInfo(forceRefresh: Boolean = false): ApplicationInfo? {
        val now = System.currentTimeMillis()

        // Return cached value if not forcing refresh and cache is recent
        if (!forceRefresh && cachedAppInfo != null && now - lastUpdateCheck < UPDATE_CHECK_INTERVAL
        ) {
            return cachedAppInfo
        }

        try {
            // Try to get application name
            val appName = getApplicationName()

            // Try to get package name
            val packageName = getPackageName()

            // Try to get version information
            val (versionName, versionCode) = getVersionInfo()

            // Get system properties for build type
            val buildType =
                    System.getProperty("java.vm.version")?.let {
                        if (it.contains("debug", ignoreCase = true)) "debug" else "release"
                    }

            // Create ApplicationInfo
            val appInfo =
                    ApplicationInfo(
                            appName = appName,
                            packageName = packageName,
                            versionName = versionName,
                            versionCode = versionCode,
                            buildType = buildType,
                            installDate = getCurrentDate(),
                            lastUpdateDate = getCurrentDate(),
                            launchCount = 1
                    )

            // Cache the result
            cachedAppInfo = appInfo
            lastUpdateCheck = now

            return appInfo
        } catch (e: Exception) {
            Timber.e(e, "Failed to detect application info: ${e.message}")
            return null
        }
    }

    /** Try to get application name from runtime properties */
    private fun getApplicationName(): String? {
        // Try application.name system property
        System.getProperty("application.name")?.let {
            return it
        }

        // Try sun.java.command for main class name
        System.getProperty("sun.java.command")?.let { command ->
            val mainClass = command.split(" ").firstOrNull()
            if (!mainClass.isNullOrEmpty()) {
                return mainClass.split(".").lastOrNull()
            }
        }

        // Try to get it from stacktrace
        return try {
            val mainClassName =
                    StackWalker.getInstance(StackWalker.Option.RETAIN_CLASS_REFERENCE)
                            .walk { frames -> frames.findFirst() }
                            .map { it.declaringClass.name }
                            .orElse(null)

            mainClassName?.split(".")?.lastOrNull()
        } catch (e: Exception) {
            null
        }
    }

    /** Try to get package name from runtime properties */
    private fun getPackageName(): String? {
        // Try to get from main class
        System.getProperty("sun.java.command")?.let { command ->
            val mainClass = command.split(" ").firstOrNull()
            if (!mainClass.isNullOrEmpty() && mainClass.contains(".")) {
                return mainClass.substring(0, mainClass.lastIndexOf("."))
            }
        }

        // Try to get from classpath packages
        return try {
            val packages = Package.getPackages()
            packages.firstOrNull()?.name
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Try to get version information
     *
     * @return Pair of (versionName, versionCode)
     */
    private fun getVersionInfo(): Pair<String?, Int?> {
        var versionName: String? = null
        var versionCode: Int? = null

        // Try to read version from properties file
        try {
            val versionProps = ResourceLoader.loadProperties("version.properties")
            versionName = versionProps.getProperty("version.name")
            versionCode = versionProps.getProperty("version.code")?.toIntOrNull()
        } catch (e: Exception) {
            // Ignore
        }

        // If not found, check system properties
        if (versionName == null) {
            versionName = System.getProperty("application.version")
        }

        // If still not found, use Java version
        if (versionName == null) {
            versionName = System.getProperty("java.version")
        }

        return Pair(versionName, versionCode)
    }

    /** Get current date in ISO 8601 format */
    private fun getCurrentDate(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }
}

/** Utility to load resources */
private object ResourceLoader {
    fun loadProperties(resourceName: String): Properties {
        val props = Properties()
        val resource = this.javaClass.classLoader.getResourceAsStream(resourceName)
        if (resource != null) {
            props.load(resource)
        } else {
            // Try as file
            val file = File(resourceName)
            if (file.exists()) {
                file.inputStream().use { props.load(it) }
            }
        }
        return props
    }
}
