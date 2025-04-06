package customfit.ai.kotlinclient.client

import customfit.ai.kotlinclient.core.*
import customfit.ai.kotlinclient.events.EventTracker
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.summaries.SummaryManager
import java.net.HttpURLConnection
import java.util.*
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
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
        val configJson = Json { prettyPrint = true }.encodeToString(config)
        val userJson = Json { prettyPrint = true }.encodeToString(user)

        // Log the config and user as JSON
        logger.info("CFClient initialized with config: \n$configJson\nand user: \n$userJson")

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

        // Process each config object in the "configs" map
        configs.keys().forEach { key ->
            val config = configs.getJSONObject(key)
            val experience = config.getJSONObject("experience_behaviour_response")

            // Collect all relevant fields
            val experienceId = experience.getString("experience_id")
            val behaviour = experience.getString("behaviour")
            val behaviourId = experience.getString("behaviour_id")
            val variationId = experience.getString("variation_id")
            val version = config.getNumber("version")
            val configId = config.getString("config_id")
            val userId = json.getString("user_id")

            val priority = experience.getInt("priority")
            val experienceCreatedTime = experience.getLong("experience_created_time")
            val ruleId = experience.getString("rule_id")
            val experienceKey = experience.getString("experience")

            // Extract variation-related fields
            val variationName = experience.getString("behaviour")
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

            // Create a map of the full experience data
            val experienceData =
                    mapOf(
                            "version" to version,
                            "config_id" to configId,
                            "user_id" to userId,
                            "experience_id" to experienceId,
                            "behaviour" to behaviour,
                            "behaviour_id" to behaviourId,
                            "variation_name" to variationName,
                            "variation_id" to variationId,
                            "priority" to priority,
                            "experience_created_time" to experienceCreatedTime,
                            "rule_id" to ruleId,
                            "experience" to experienceKey,
                            "audience_name" to experience.optString("audience_name", null),
                            "ga_measurement_id" to experience.optString("ga_measurement_id", null),
                            "type" to experience.optString("type", null),
                            "config_modifications" to
                                    experience.optString("config_modifications", null),
                            "variation_data_type" to variationDataType,
                            "variation" to variation
                    )

            // Add the full experience data to the map under the experienceKey
            newConfigMap[experienceKey] = experienceData
        }

        // Update the configMap with the new structured config
        configMap = newConfigMap
        return configMap
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        // Get the value of configMap[key]
        val config = configMap[key]

        // Check if the config value is valid and if it is a map (to be able to access .variation)
        val result =
                if (config is Map<*, *> && config.containsKey("variation")) {
                    // Now, access the 'variation' field from the map
                    val variation = config["variation"]
                    if (variation != null && typeCheck(variation)) {
                        variation as? T ?: fallbackValue
                    } else {
                        // If variation is null or doesn't match the expected type, use the fallback
                        fallbackValue
                    }
                } else {
                    // If config is not a map or doesn't contain "variation", return fallback
                    logger.warn("Key '$key' does not have a 'variation' field or is not a map")
                    fallbackValue
                }

        // Ensure that the value is either a Map or emptyMap to avoid type inference issues
        // Here, the configMap[key] value is being passed to pushSummary, with nested map handling
        summaryManager.pushSummary(config as? Map<String, Any> ?: emptyMap<String, Any>())

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
