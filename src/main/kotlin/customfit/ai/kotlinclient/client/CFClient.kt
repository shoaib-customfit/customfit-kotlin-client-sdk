package customfit.ai.kotlinclient.client

import customfit.ai.kotlinclient.core.*

import customfit.ai.kotlinclient.events.EventTracker
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.summaries.SummaryManager
import java.net.HttpURLConnection
import java.util.*
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.*
import org.json.JSONObject
import org.slf4j.LoggerFactory

class CFClient private constructor(private val config: CFConfig, private val user: CFUser) {
    private val logger = LoggerFactory.getLogger(CFClient::class.java)
    private val sessionId: String = UUID.randomUUID().toString()
    private val httpClient = HttpClient()
    private val eventTracker = EventTracker(sessionId, httpClient, user)
    private val summaryManager = SummaryManager(sessionId, user, httpClient)

    private var previousLastModified: String? = null
    private var configMap: Map<String, Any> = emptyMap()
    private val sdkSettingsDeferred: CompletableDeferred<Unit> = CompletableDeferred()

    init {
        logger.info("CFClient initialized with config: $config and user: $user")
        initializeSdkSettings()
        startPeriodicSdkSettingsCheck()
    }

    private fun initializeSdkSettings() {
        runBlocking(Dispatchers.IO) {
            try {
                logger.info("Initializing SDK settings")
                checkSdkSettings()
                sdkSettingsDeferred.complete(Unit)
            } catch (e: Exception) {
                logger.error("Error initializing SDK settings: ${e.message}", e)
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
            CoroutineScope(Dispatchers.IO).launch {
                logger.info("Periodic SDK settings check triggered")
                checkSdkSettings()
            }
        }
    }

    private suspend fun checkSdkSettings() {
        try {
            val metadata = fetchSdkSettingsMetadata() ?: return

            val currentLastModified = metadata["Last-Modified"]
            if (currentLastModified != previousLastModified) {
                // Logging the change
                logger.info("SDK settings changed:")
                logger.info("Previous Last-Modified: $previousLastModified")
                logger.info("Current Last-Modified: $currentLastModified")

                // Fetch new configs
                fetchConfigs()

                // Update the previousLastModified
                previousLastModified = currentLastModified

                // Log that the fetch was triggered
                logger.info("Fetching new SDK settings as the last modified value has changed.")
            } else {
                logger.info("SDK settings have not changed. No fetch needed.")
            }
        } catch (e: Exception) {
            logger.error("Error checking SDK settings: ${e.message}", e)
        }
    }

    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? =
            httpClient.fetchMetadata(
                    "https://sdk.customfit.ai/${config.dimensionId}/cf-sdk-settings.json"
            )

    private suspend fun fetchSdkSettings(): SdkSettings? {
        val json =
                httpClient.fetchJson(
                        "https://sdk.customfit.ai/${config.dimensionId}/cf-sdk-settings.json"
                )
        return json?.let { SdkSettings.fromJson(it) }?.takeUnless {
            !it.cf_account_enabled || it.cf_skip_sdk
        }
    }

    private suspend fun fetchConfigs(): Map<String, Any>? {
        val url = "https://api.customfit.ai/v1/users/configs?cfenc=${config.clientKey}"
        val payload =
                JSONObject()
                        .apply {
                            put("user", JSONObject(user.toMap()))
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
                    if (conn.responseCode == HttpURLConnection.HTTP_OK)
                            JSONObject(conn.inputStream.bufferedReader().readText())
                    else null
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
                                    logger.warn(
                                            "Unknown variation_data_type: $variationDataType for $key"
                                    )
                                }
                    }
            newConfigMap[experienceKey] = variation
        }
        configMap = newConfigMap
        return configMap
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        val config = configMap[key]
        val result =
                if (config != null && typeCheck(config)) {
                    config as? T ?: fallbackValue
                } else {
                    if (config != null) {
                        logger.warn(
                                "Type mismatch for '$key': expected ${fallbackValue!!::class.simpleName}, got ${config::class.simpleName}"
                        )
                    }
                    fallbackValue
                }

        // Ensure that the value is either a Map or emptyMap to avoid type inference issues
        summaryManager.pushSummary(configMap[key] as? Map<String, Any> ?: emptyMap<String, Any>())

        return result
    }

    private fun CFUser.toMap(): Map<String, Any?> =
            mapOf(
                    "user_customer_id" to user_customer_id,
                    "anonymous" to anonymous,
                    "private_fields" to private_fields,
                    "session_fields" to session_fields,
                    "properties" to properties
            )

    companion object {
        fun init(config: CFConfig, user: CFUser): CFClient = CFClient(config, user)
    }
}
