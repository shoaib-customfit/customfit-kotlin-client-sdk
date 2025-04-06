package customfit.ai.kotlinclient

import java.net.HttpURLConnection // Added missing import
import java.util.*
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.*
import org.json.JSONObject

class CFClient private constructor(private val config: CFConfig, private val user: CFUser) {
    // Dependencies
    private val sessionId: String = UUID.randomUUID().toString() // Moved before dependencies
    private val httpClient = HttpClient()
    private val eventTracker = EventTracker(sessionId, httpClient, user)
    private val summaryManager = SummaryManager(sessionId, user, httpClient)

    // State
    private var previousLastModified: String? = null
    private var configMap: Map<String, Any> = emptyMap()
    private val sdkSettingsDeferred: CompletableDeferred<Unit> = CompletableDeferred()

    // Initialization
    init {
        println("CFClient initialized with config: $config and user: $user")
        initializeSdkSettings()
        startPeriodicSdkSettingsCheck()
    }

    private fun initializeSdkSettings() {
        runBlocking(Dispatchers.IO) {
            try {
                println("Before calling checkSdkSettings() in init")
                checkSdkSettings()
                sdkSettingsDeferred.complete(Unit)
                println("Initial SDK Settings check completed!")
            } catch (e: Exception) {
                println("Error in initial checkSdkSettings: ${e.message}")
                sdkSettingsDeferred.completeExceptionally(e)
            }
        }
    }

    // Public API for Configuration
    suspend fun awaitSdkSettingsCheck() {
        sdkSettingsDeferred.await()
    }

    fun getString(key: String, fallbackValue: String): String {
        return getConfigValue(key, fallbackValue) { it is String }
    }

    fun getNumber(key: String, fallbackValue: Number): Number {
        return getConfigValue(key, fallbackValue) { it is Number }
    }

    fun getBoolean(key: String, fallbackValue: Boolean): Boolean {
        return getConfigValue(key, fallbackValue) { it is Boolean }
    }

    fun getJson(key: String, fallbackValue: Map<String, Any>): Map<String, Any> {
        return getConfigValue(key, fallbackValue) { value ->
            value is Map<*, *> && value.keys.all { it is String }
        }
    }

    // Public API for Events
    fun trackEvent(eventName: String, properties: Map<String, Any>) {
        eventTracker.trackEvent(eventName, properties)
    }

    // Configuration Fetching
    private fun startPeriodicSdkSettingsCheck() {
        fixedRateTimer("SdkSettingsCheck", daemon = true, period = 300_000) {
            CoroutineScope(Dispatchers.IO).launch {
                println("Periodic SDK settings check triggered")
                checkSdkSettings()
            }
        }
    }

    private suspend fun checkSdkSettings() {
        try {
            println("Fetching SDK settings...")
            val metadata = fetchSdkSettingsMetadata()
            println("Metadata fetched: $metadata")
            if (metadata != null) {
                val currentLastModified = metadata["Last-Modified"]
                if (currentLastModified != previousLastModified) {
                    println("SDK Settings changed, fetching configs.")
                    fetchConfigs()
                    previousLastModified = currentLastModified
                } else {
                    println("No change in Last-Modified, skipping fetch.")
                }
            } else {
                println("Metadata is null, fetch failed.")
            }
        } catch (e: Exception) {
            println("Error during SDK settings check: ${e.message}")
        }
    }

    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? {
        return httpClient.fetchMetadata(
                        "https://sdk.customfit.ai/${config.dimensionId}/cf-sdk-settings.json"
                )
                .also { println("Headers fetched: $it") }
    }

    private suspend fun fetchSdkSettings(): SdkSettings? {
        val json =
                httpClient.fetchJson(
                        "https://sdk.customfit.ai/${config.dimensionId}/cf-sdk-settings.json"
                )
        return json?.let { SdkSettings.fromJson(it) }?.also { settings ->
            if (!settings.cf_account_enabled || settings.cf_skip_sdk) {
                println("Account disabled or SDK skipped.")
                return null
            }
        }
    }

    private suspend fun fetchConfigs(): Map<String, Any>? {
        val url = "https://api.customfit.ai/v1/users/configs?cfenc=${config.clientKey}"
        val payload =
                JSONObject()
                        .apply {
                            put("user", JSONObject(user))
                            put("include_only_features_flags", true)
                        }
                        .toString()

        val json =
                httpClient.performRequest(
                        url,
                        "POST",
                        mapOf("Content-Type" to "application/json"),
                        payload
                ) { conn ->
                    if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                        JSONObject(conn.inputStream.bufferedReader().readText())
                    } else {
                        println("Error response code: ${conn.responseCode}")
                        null
                    }
                }
                        ?: return null

        val configs = json.getJSONObject("configs")
        val newConfigMap = mutableMapOf<String, Any>()
        configs.keys().forEach { key ->
            val config = configs.getJSONObject(key)
            val experience = config.getJSONObject("experience_behaviour_response")
            val experienceKey = experience.getString("experience")
            val variationDataType = config.getString("variation_data_type")
            val variation: Any =
                    when (variationDataType.uppercase()) {
                        "STRING" -> config.getString("variation")
                        "BOOLEAN" -> config.getBoolean("variation")
                        "NUMBER" -> config.getDouble("variation")
                        "JSON" -> config.getJSONObject("variation").toMap()
                        else ->
                                config.get("variation").also {
                                    println(
                                            "Unknown variation_data_type: $variationDataType for $key"
                                    )
                                }
                    }
            newConfigMap[experienceKey] = variation
        }
        configMap = newConfigMap
        return configMap
    }

    // Helper Methods
    @Suppress("UNCHECKED_CAST")
    private fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        val config = configMap[key]
        val result =
                if (config != null && typeCheck(config)) {
                    config as? T ?: fallbackValue
                } else {
                    if (config != null) {
                        println(
                                "Type mismatch for key '$key': expected ${fallbackValue!!::class.simpleName}, got ${config::class.simpleName}"
                        )
                    }
                    fallbackValue
                }
        summaryManager.pushSummary(configMap[key] ?: emptyMap<String, Any>())
        return result
    }

    // Companion Object
    companion object {
        fun init(config: CFConfig, user: CFUser): CFClient = CFClient(config, user)
    }
}
