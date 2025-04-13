package customfit.ai.kotlinclient.client

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import customfit.ai.kotlinclient.core.SdkSettings
import customfit.ai.kotlinclient.events.EventTracker
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.summaries.SummaryManager
import java.net.HttpURLConnection
import java.util.*
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import timber.log.Timber

class CFClient private constructor(private val config: CFConfig, private val user: CFUser) {
    private val sessionId: String = UUID.randomUUID().toString()
    private val httpClient = HttpClient()
    val summaryManager = SummaryManager(sessionId, user, httpClient)
    val eventTracker = EventTracker(sessionId, httpClient, user, summaryManager)

    @Volatile private var previousLastModified: String? = null
    private val configMap: MutableMap<String, Any> =
            Collections.synchronizedMap(mutableMapOf()) // Thread-safe
    private val configMutex = Mutex() // For atomic updates
    private val sdkSettingsDeferred: CompletableDeferred<Unit> = CompletableDeferred()

    init {
        Timber.i("CFClient initialized with config: $config and user: $user")
        initializeSdkSettings()
        startPeriodicSdkSettingsCheck()
    }

    private fun initializeSdkSettings() {
        runBlocking(Dispatchers.IO) {
            try {
                Timber.i("Initializing SDK settings")
                checkSdkSettings()
                sdkSettingsDeferred.complete(Unit)
                Timber.i("SDK settings initialized successfully")
            } catch (e: Exception) {
                Timber.e(e, "Failed to initialize SDK settings: ${e.message}")
                sdkSettingsDeferred.completeExceptionally(e)
            }
        }
    }

    suspend fun awaitSdkSettingsCheck() = sdkSettingsDeferred.await()

    fun getString(key: String, fallbackValue: String): String =
            getConfigValue(key, fallbackValue) { it is String }
    fun getNumber(key: String, fallbackValue: Number): Number =
            getConfigValue(key, fallbackValue) { it is Number }
    fun getBoolean(key: String, fallbackValue: Boolean): Boolean =
            getConfigValue(key, fallbackValue) { it is Boolean }
    fun getJson(key: String, fallbackValue: Map<String, Any>): Map<String, Any> =
            getConfigValue(key, fallbackValue) {
                it is Map<*, *> && it.keys.all { k -> k is String }
            }

    fun trackEvent(eventName: String, properties: Map<String, Any>) =
            eventTracker.trackEvent(eventName, properties)

    private fun startPeriodicSdkSettingsCheck() {
        fixedRateTimer("SdkSettingsCheck", daemon = true, period = 300_000) {
            CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                Timber.d("Periodic SDK settings check triggered")
                checkSdkSettings()
            }
        }
    }

    private suspend fun checkSdkSettings() {
        try {
            val metadata =
                    fetchSdkSettingsMetadata()
                            ?: run {
                                Timber.w("Failed to fetch SDK settings metadata")
                                return
                            }
            val currentLastModified = metadata["Last-Modified"] ?: return
            if (currentLastModified != previousLastModified) {
                Timber.i(
                        "SDK settings changed: Previous=$previousLastModified, Current=$currentLastModified"
                )
                val newConfigs = fetchConfigs() ?: emptyMap()
                configMutex.withLock {
                    configMap.clear()
                    configMap.putAll(newConfigs)
                    previousLastModified = currentLastModified
                }
                Timber.i("Configs updated successfully with ${newConfigs.size} entries")
            } else {
                Timber.d("No change in SDK settings")
            }
        } catch (e: Exception) {
            Timber.e(e, "Error checking SDK settings: ${e.message}")
        }
    }

    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? =
            httpClient.fetchMetadata(
                            "https://sdk.customfit.ai/${config.dimensionId}/cf-sdk-settings.json"
                    )
                    ?.also { Timber.d("Fetched metadata: $it") }

    private suspend fun fetchSdkSettings(): SdkSettings? {
        val json =
                httpClient.fetchJson(
                        "https://sdk.customfit.ai/${config.dimensionId}/cf-sdk-settings.json"
                )
                        ?: run {
                            Timber.w("Failed to fetch SDK settings JSON")
                            return null
                        }

        return try {
            val settings = SdkSettings.fromJson(json)
            if (settings == null) {
                Timber.w("SdkSettings.fromJson returned null for JSON: $json")
                return null
            }
            if (!settings.cf_account_enabled || settings.cf_skip_sdk) {
                Timber.d(
                        "SDK settings skipped: cf_account_enabled=${settings.cf_account_enabled}, cf_skip_sdk=${settings.cf_skip_sdk}"
                )
                null
            } else {
                Timber.d("Fetched SDK settings: $settings")
                settings
            }
        } catch (e: Exception) {
            Timber.e(e, "Error parsing SDK settings: ${e.message}")
            null
        }
    }

    private suspend fun fetchConfigs(): Map<String, Any>? {
        val url = "https://api.customfit.ai/v1/users/configs?cfenc=${config.clientKey}"
        val payload =
                try {
                    JSONObject()
                            .apply {
                                put("user", JSONObject(user.toMap()))
                                put("include_only_features_flags", true)
                            }
                            .toString()
                } catch (e: Exception) {
                    Timber.e(e, "Error creating config payload: ${e.message}")
                    return null
                }

        val json =
                httpClient.performRequest(
                        url,
                        "POST",
                        mapOf("Content-Type" to "application/json"),
                        payload
                ) { conn ->
                    when (conn.responseCode) {
                        HttpURLConnection.HTTP_OK ->
                                JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
                        else -> {
                            Timber.w("Config fetch failed with code: ${conn.responseCode}")
                            null
                        }
                    }
                }
                        ?: return null

        val configs =
                json.optJSONObject("configs")
                        ?: run {
                            Timber.w("No 'configs' object in response")
                            return null
                        }
        val newConfigMap = mutableMapOf<String, Any>()

        configs.keys().forEach { key ->
            try {
                val config = configs.getJSONObject(key)
                val experience =
                        config.optJSONObject("experience_behaviour_response")
                                ?: run {
                                    Timber.w(
                                            "Missing 'experience_behaviour_response' for key: $key"
                                    )
                                    return@forEach
                                }

                val experienceKey =
                        experience.optString("experience", null)
                                ?: run {
                                    Timber.w("Missing 'experience' field for key: $key")
                                    return@forEach
                                }
                val variationDataType = config.optString("variation_data_type", "UNKNOWN")
                val variation: Any =
                        when (variationDataType.uppercase()) {
                            "STRING" -> config.optString("variation", "")
                            "BOOLEAN" -> config.optBoolean("variation", false)
                            "NUMBER" -> config.optDouble("variation", 0.0)
                            "JSON" -> config.optJSONObject("variation")?.toMap()
                                            ?: emptyMap<String, Any>()
                            else ->
                                    config.opt("variation")?.also {
                                        Timber.w(
                                                "Unknown variation type: $variationDataType for $key"
                                        )
                                    }
                                            ?: ""
                        }

                val experienceData =
                        mapOf(
                                "version" to config.optNumber("version"),
                                "config_id" to config.optString("config_id", null),
                                "user_id" to json.optString("user_id", null),
                                "experience_id" to experience.optString("experience_id", null),
                                "behaviour" to experience.optString("behaviour", null),
                                "behaviour_id" to experience.optString("behaviour_id", null),
                                "variation_name" to experience.optString("behaviour", null),
                                "variation_id" to experience.optString("variation_id", null),
                                "priority" to experience.optInt("priority", 0),
                                "experience_created_time" to
                                        experience.optLong("experience_created_time", 0L),
                                "rule_id" to experience.optString("rule_id", null),
                                "experience" to experienceKey,
                                "audience_name" to experience.optString("audience_name", null),
                                "ga_measurement_id" to
                                        experience.optString("ga_measurement_id", null),
                                "type" to experience.optString("type", null),
                                "config_modifications" to
                                        experience.optString("config_modifications", null),
                                "variation_data_type" to variationDataType,
                                "variation" to variation
                        )

                newConfigMap[experienceKey] = experienceData
            } catch (e: Exception) {
                Timber.e(e, "Error processing config key '$key': ${e.message}")
            }
        }

        return newConfigMap
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        val config = configMap[key]
        if (config == null) {
            Timber.w("No config found for key '$key'")
            return fallbackValue
        }
        if (config !is Map<*, *>) {
            Timber.w("Config for '$key' is not a map: $config")
            return fallbackValue
        }
        val variation = config["variation"]
        val result =
                if (variation != null && typeCheck(variation)) {
                    try {
                        variation as T
                    } catch (e: ClassCastException) {
                        Timber.w(
                                "Type mismatch for '$key': expected ${fallbackValue!!::class.simpleName}, got ${variation::class.simpleName}"
                        )
                        fallbackValue
                    }
                } else {
                    Timber.w("No valid variation for '$key': $variation")
                    fallbackValue
                }
        summaryManager.pushSummary(config as Map<String, Any>)
        return result
    }

    private fun CFUser.toMap(): Map<String, Any?> =
            mapOf(
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
            )

    companion object {
        fun init(config: CFConfig, user: CFUser): CFClient = CFClient(config, user)
    }
}
