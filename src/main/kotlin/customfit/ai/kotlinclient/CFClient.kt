package customfit.ai.kotlinclient

import java.net.HttpURLConnection
import java.net.URL
import java.util.*
import java.util.concurrent.LinkedBlockingQueue
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.joda.time.DateTime
import org.json.JSONObject

class CFClient private constructor(private val config: CFConfig, private val user: CFUser) {

    private var previousSdkSettingsHash: String? = null
    private var previousLastModified: String? = null
    private var configMap: Map<String, Any> = emptyMap()

    private val eventQueue: LinkedBlockingQueue<EventData> = LinkedBlockingQueue()
    private val maxQueueSize = 100
    private val maxTimeInSeconds = 60

    private val sessionId: String = UUID.randomUUID().toString()
    private val summaries: LinkedBlockingQueue<CFConfigRequestSummary> = LinkedBlockingQueue()
    private val summaryTrackMap = mutableMapOf<String, Boolean>()

    init {
        println("CFClient initialized with config: $config and user: $user")
        startSdkSettingsCheck()
        startFlushEventCheck()
    }

    fun trackEvent(eventName: String, properties: Map<String, Any>) {
        val finalEvent =
                EventData(
                        event_customer_id = eventName,
                        event_type = EventType.TRACK,
                        properties = properties.toMutableMap(),
                        event_timestamp = DateTime.now(),
                        session_id = sessionId,
                        timeuuid = UUID.randomUUID(),
                        insert_id = UUID.randomUUID().toString()
                )

        eventQueue.offer(finalEvent)
        println("Event added to the queue: $finalEvent")

        if (eventQueue.size >= maxQueueSize) {
            CoroutineScope(Dispatchers.Default).launch {
                flushEvents()
            }
        }
    }

    private fun startFlushEventCheck() {
        fixedRateTimer("EventFlushCheck", daemon = true, period = 1000) {
            CoroutineScope(Dispatchers.Default).launch {
                val lastEvent = eventQueue.peek()
                val currentTime = DateTime.now()
                if (lastEvent != null &&
                                currentTime
                                        .minusSeconds(maxTimeInSeconds)
                                        .isAfter(lastEvent.event_timestamp)
                ) {
                    this@CFClient.flushEvents()
                }
            }
        }
    }

    private suspend fun flushEvents() {
        flushSummaries()
        if (eventQueue.isEmpty()) {
            println("No events to flush.")
            return
        }

        val eventsToFlush = mutableListOf<EventData>()
        eventQueue.drainTo(eventsToFlush)
        sendTrackEvents(eventsToFlush)
        println("Flushed ${eventsToFlush.size} events.")
    }

    private suspend fun sendTrackEvents(events: List<EventData>) {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/v1/cfe") // Replace with actual URL
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                val eventsJson =
                        events.map { event ->
                            mapOf(
                                    "event_customer_id" to event.event_customer_id,
                                    "event_type" to event.event_type.toString(),
                                    "properties" to event.properties,
                                    "event_timestamp" to event.event_timestamp.toString(),
                                    "session_id" to event.session_id,
                                    "insert_id" to event.insert_id
                            )
                        }

                val jsonPayload =
                        JSONObject(
                                mapOf(
                                        "user" to user,
                                        "events" to eventsJson,
                                        "cf_client_sdk_version" to "1.0.0" // Use actual version
                                )
                        )

                connection.outputStream.use { os ->
                    val input = jsonPayload.toString().toByteArray(Charsets.UTF_8)
                    os.write(input, 0, input.size)
                }

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    println("Events successfully sent to the server.")
                } else {
                    println("Error sending events. Response code: $responseCode")
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun startSdkSettingsCheck() {
        fixedRateTimer("SdkSettingsCheck", daemon = true, period = 300_000) {
            CoroutineScope(Dispatchers.IO).launch { checkSdkSettings() }
        }
    }

    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/sdk-settings")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "HEAD"
                connection.connect()

                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val headers = connection.headerFields

                    val lastModified = headers["Last-Modified"]?.firstOrNull() ?: ""
                    val eTag = headers["ETag"]?.firstOrNull() ?: ""

                    return@withContext mapOf("Last-Modified" to lastModified, "ETag" to eTag)
                } else {
                    println("Error fetching SDK Settings metadata: ${connection.responseCode}")
                    return@withContext null
                }
            } catch (e: Exception) {
                e.printStackTrace()
                return@withContext null
            }
        }
    }

    private suspend fun checkSdkSettings() {
        val metadata = fetchSdkSettingsMetadata()
        if (metadata != null) {
            val currentLastModified = metadata["Last-Modified"]
            if (currentLastModified != previousLastModified) {
                println("SDK Settings have changed, re-fetching configurations.")
                fetchConfigs()
                previousLastModified = currentLastModified
            }
        }
    }

    private suspend fun fetchSdkSettings(): SdkSettings? {
        return withContext(Dispatchers.IO) {
            try {
                val url =
                        URL(
                                "https://example.com/sdk-settings"
                        )
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connect()

                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().readText()
                    val jsonResponse = JSONObject(response)
                    val dateTimeString = jsonResponse.optString("date", null)
                    val date =
                            if (dateTimeString != null) {
                                DateTime.parse(dateTimeString) // Parse the string into DateTime
                            } else {
                                null
                            }

                    val sdkSettings =
                            SdkSettings(
                                    cf_key = jsonResponse.getString("cf_key"),
                                    cf_account_enabled =
                                            jsonResponse.getBoolean("cf_account_enabled"),
                                    cf_page_elements_path_type =
                                            jsonResponse.optString(
                                                    "cf_page_elements_path_type",
                                                    null
                                            ),
                                    cf_latest_sdk_version =
                                            jsonResponse.optString("cf_latest_sdk_version", null),
                                    cf_whitelabel_company_display_name =
                                            jsonResponse.optString(
                                                    "cf_whitelabel_company_display_name",
                                                    null
                                            ),
                                    cf_domain_url = jsonResponse.optString("cf_domain_url", null),
                                    cf_jsevl_type = jsonResponse.optString("cf_jsevl_type", null),
                                    cf_config_reapply_timers =
                                            jsonResponse.optString(
                                                    "cf_config_reapply_timers",
                                                    null
                                            ),
                                    cf_ga4_setup_mode =
                                            jsonResponse.optString("cf_ga4_setup_mode", null),
                                    cf_gtm_data_variable_name =
                                            jsonResponse.optString(
                                                    "cf_gtm_data_variable_name",
                                                    null
                                            ),
                                    cf_account_source =
                                            jsonResponse.optString("cf_account_source", null),
                                    cf_event_merge_config =
                                            jsonResponse.optString("cf_event_merge_config", null),
                                    cf_dimension_id =
                                            jsonResponse.optString("cf_dimension_id", null),
                                    cf_intelligent_code_enabled =
                                            jsonResponse.getBoolean("cf_intelligent_code_enabled"),
                                    cf_personalize_post_sdk_timeout =
                                            jsonResponse.getBoolean(
                                                    "cf_personalize_post_sdk_timeout"
                                            ),
                                    is_inbound = jsonResponse.getBoolean("is_inbound"),
                                    is_outbound = jsonResponse.getBoolean("is_outbound"),
                                    cfspa = jsonResponse.getBoolean("cfspa"),
                                    cfspa_auto_detect_page_url_change =
                                            jsonResponse.getBoolean(
                                                    "cfspa_auto_detect_page_url_change"
                                            ),
                                    is_auto_form_capture =
                                            jsonResponse.getBoolean("is_auto_form_capture"),
                                    is_auto_email_capture =
                                            jsonResponse.getBoolean("is_auto_email_capture"),
                                    cf_is_page_update_enabled =
                                            jsonResponse.getBoolean("cf_is_page_update_enabled"),
                                    cf_retain_text_value =
                                            jsonResponse.getBoolean("cf_retain_text_value"),
                                    cf_is_whitelabel_account =
                                            jsonResponse.getBoolean("cf_is_whitelabel_account"),
                                    cf_skip_sdk = jsonResponse.getBoolean("cf_skip_sdk"),
                                    enable_event_analyzer =
                                            jsonResponse.getBoolean("enable_event_analyzer"),
                                    cf_skip_dfs = jsonResponse.getBoolean("cf_skip_dfs"),
                                    cf_is_ms_clarity_enabled =
                                            jsonResponse.getBoolean("cf_is_ms_clarity_enabled"),
                                    cf_is_hotjar_enabled =
                                            jsonResponse.getBoolean("cf_is_hotjar_enabled"),
                                    cf_is_shopify_integrated =
                                            jsonResponse.getBoolean("cf_is_shopify_integrated"),
                                    cf_is_ga_enabled = jsonResponse.getBoolean("cf_is_ga_enabled"),
                                    cf_is_segment_enabled =
                                            jsonResponse.getBoolean("cf_is_segment_enabled"),
                                    cf_is_mixpanel_enabled =
                                            jsonResponse.getBoolean("cf_is_mixpanel_enabled"),
                                    cf_is_moengage_enabled =
                                            jsonResponse.getBoolean("cf_is_moengage_enabled"),
                                    cf_is_clevertap_enabled =
                                            jsonResponse.getBoolean("cf_is_clevertap_enabled"),
                                    cf_is_webengage_enabled =
                                            jsonResponse.getBoolean("cf_is_webengage_enabled"),
                                    cf_is_netcore_enabled =
                                            jsonResponse.getBoolean("cf_is_netcore_enabled"),
                                    cf_is_amplitude_enabled =
                                            jsonResponse.getBoolean("cf_is_amplitude_enabled"),
                                    cf_is_heap_enabled =
                                            jsonResponse.getBoolean("cf_is_heap_enabled"),
                                    cf_is_gokwik_enabled =
                                            jsonResponse.getBoolean("cf_is_gokwik_enabled"),
                                    cf_is_shopflo_enabled =
                                            jsonResponse.getBoolean("cf_is_shopflo_enabled"),
                                    cf_send_error_report =
                                            jsonResponse.getBoolean("cf_send_error_report"),
                                    personalized_users_limit_exceeded =
                                            jsonResponse.getBoolean(
                                                    "personalized_users_limit_exceeded"
                                            ),
                                    cf_sdk_timeout_in_seconds =
                                            jsonResponse.getInt("cf_sdk_timeout_in_seconds"),
                                    cf_initial_delay_in_ms =
                                            jsonResponse.getInt("cf_initial_delay_in_ms"),
                                    cf_last_visited_product_url =
                                            jsonResponse.getInt("cf_last_visited_product_url"),
                                    blacklisted_page_paths =
                                            jsonResponse.optJSONArray("blacklisted_page_paths")
                                                    ?.let {
                                                        List(it.length()) { index ->
                                                            it.getString(index)
                                                        }
                                                    }
                                                    ?: emptyList(),
                                    blacklisted_referrers =
                                            jsonResponse.optJSONArray("blacklisted_referrers")
                                                    ?.let {
                                                        List(it.length()) { index ->
                                                            it.getString(index)
                                                        }
                                                    }
                                                    ?: emptyList(),
                                    cf_subdomains =
                                            jsonResponse.optJSONArray("cf_subdomains")?.let {
                                                List(it.length()) { index ->
                                                    it.getString(index)
                                                }
                                            }
                                                    ?: emptyList(),
                                    cf_configs_json =
                                            jsonResponse.optJSONObject("cf_configs_json")?.let {
                                                it.toMap()
                                            }
                                                    ?: emptyMap(),
                                    cf_active_pages =
                                            jsonResponse.optJSONObject("cf_active_pages")?.let {
                                                it.toMap()
                                            }
                                                    ?: emptyMap(),
                                    cf_revenue_pages =
                                            jsonResponse.optJSONObject("cf_revenue_pages")?.let {
                                                it.toMap()
                                            }
                                                    ?: emptyMap(),
                                    cf_browser_variables =
                                            jsonResponse.optJSONObject("cf_browser_variables")
                                                    ?.let { it.toMap() }
                                                    ?: emptyMap(),
                                    date = date
                            )

                    if (!sdkSettings.cf_account_enabled || sdkSettings.cf_skip_sdk) {
                        println("Account is disabled or SDK is skipped. No further processing.")
                        return@withContext null
                    }

                    return@withContext sdkSettings
                } else {
                    println("Error fetching SDK Settings: ${connection.responseCode}")
                    return@withContext null
                }
            } catch (e: Exception) {
                e.printStackTrace()
                return@withContext null
            }
        }
    }

    private suspend fun fetchConfigs(): Map<String, Any>? {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/v1/users/configs?cfenc=${config.clientKey}")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                val userJson = JSONObject(user.properties).toString()
                val jsonInputString =
                        """{
                    "user": $userJson
                }"""

                connection.outputStream.use { os ->
                    val input = jsonInputString.toByteArray(Charsets.UTF_8)
                    os.write(input, 0, input.size)
                }

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().readText()
                    println("Response: $response")

                    val jsonResponse = JSONObject(response)
                    val configs = jsonResponse.getJSONObject("configs")

                    val configMap = mutableMapOf<String, Any>()
                    configs.keys().forEach { key ->
                        val config = configs.getJSONObject(key)
                        val experience = config.getJSONObject("experience_behaviour_response")
                        val experienceKey = experience.getString("experience")
                        val variation = config.getJSONObject("variation")
                        configMap[experienceKey] = variation
                    }
                    this@CFClient.configMap = configMap
                    return@withContext configMap
                } else {
                    println("Error response code: $responseCode")
                    return@withContext null
                }
            } catch (e: Exception) {
                e.printStackTrace()
                return@withContext null
            }
        }
    }

    fun getString(key: String, fallbackValue: String): String {
        return getConfigValue(key, fallbackValue) { value -> value is String }.also {
            val configValue = configMap[key]
            if (configValue != null && configValue is Map<*, *>) {
                this.pushSummary(configValue)
            }
        }
    }

    fun getNumber(key: String, fallbackValue: Number): Number {
        return getConfigValue(key, fallbackValue) { value -> value is Number }.also {
            val configValue = configMap[key]
            if (configValue != null && configValue is Map<*, *>) {
                this.pushSummary(configValue)
            }
        }
    }

    fun getBoolean(key: String, fallbackValue: Boolean): Boolean {
        return getConfigValue(key, fallbackValue) { value -> value is Boolean }.also {
            val configValue = configMap[key]
            if (configValue != null && configValue is Map<*, *>) {
                this.pushSummary(configValue)
            }
        }
    }

    fun getJson(key: String, fallbackValue: Map<String, Any>): Map<String, Any> {
        return getConfigValue(key, fallbackValue) { value ->
            value is Map<*, *> && value.keys.all { it is String }
        }
                .also {
                    val configValue = configMap[key]
                    if (configValue != null && configValue is Map<*, *>) {
                        this.pushSummary(configValue)
                    }
                }
    }

    private fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        val config = configMap[key]
        return if (config != null && typeCheck(config)) {
            @Suppress("UNCHECKED_CAST")
            config as? T ?: fallbackValue
        } else {
            fallbackValue
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun pushSummary(config: Any) {
        if (config is Map<*, *>) {
            val configMap = config as Map<String, Any>

            val experienceBehaviourResponse =
                    configMap["experience_behaviour_response"] as? Map<String, Any>
            val experienceId = experienceBehaviourResponse?.get("experience_id") as? String

            if (experienceId != null && summaryTrackMap.containsKey(experienceId)) {
                println("Experience already processed, skipping summary addition.")
                return
            }

            val configSummary =
                    CFConfigRequestSummary(
                            config_id = configMap["config_id"] as? String,
                            version = configMap["version"] as? String,
                            user_id = configMap["user_id"] as? String,
                            requested_time = DateTime.now().toString("yyyy-MM-dd HH:mm:ss"),
                            variation_id = configMap["variation_id"] as? String,
                            user_customer_id = user.userCustomerId,
                            session_id = sessionId,
                            behaviour_id =
                                    experienceBehaviourResponse?.get("behaviour_id") as? String,
                            experience_id = experienceId,
                            rule_id = experienceBehaviourResponse?.get("rule_id") as? String,
                            is_template_config = configMap["template_info"] != null
                    )

            this.summaries.offer(configSummary)
            experienceId?.let { summaryTrackMap[it] = true }

            println("Summary added to the queue: $configSummary")
        } else {
            println("Config is not a valid map")
        }
    }

    private suspend fun flushSummaries() {
        if (summaries.isEmpty()) {
            println("No summaries to flush.")
            return
        }

        val summariesToFlush = mutableListOf<CFConfigRequestSummary>()
        summaries.drainTo(summariesToFlush)

        sendSummaryToServer(summariesToFlush)
        println("Flushed ${summariesToFlush.size} summaries.")
    }

    private suspend fun sendSummaryToServer(summaries: List<CFConfigRequestSummary>) {
        return withContext(Dispatchers.IO) {
            try {
                val url =
                        URL(
                                "https://example.com/v1/config/request/summary"
                        )
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                val jsonPayload =
                        JSONObject(
                                mapOf(
                                        "user" to user,
                                        "summaries" to summaries,
                                        "cf_client_sdk_version" to "1.0.0" // Use actual version
                                )
                        )

                connection.outputStream.use { os ->
                    val input = jsonPayload.toString().toByteArray(Charsets.UTF_8)
                    os.write(input, 0, input.size)
                }

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    println("Summaries successfully sent to the server.")
                } else {
                    println("Error sending summaries. Response code: $responseCode")
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    companion object {
        fun init(config: CFConfig, user: CFUser): CFClient {
            return CFClient(config, user)
        }
    }
}
