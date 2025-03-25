package customfit.ai.kotlinclient

import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL
import java.util.*
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import customfit.ai.kotlinclient.CFConfig
import org.joda.time.DateTime
import java.util.concurrent.LinkedBlockingQueue
import kotlin.concurrent.fixedRateTimer


class CFClient private constructor(
    private val config: CFConfig,
    private val user: CFUser
) {

    private var previousSdkSettingsHash: String? = null
    private var previousLastModified: String? = null
    private var configMap: Map<String, Any> = emptyMap()

    private val eventQueue: LinkedBlockingQueue<EventData> = LinkedBlockingQueue()
    private val maxQueueSize = 100 
    private val maxTimeInSeconds = 60

    private val sessionId: String = UUID.randomUUID().toString()

    init {
        println("CFClient initialized with config: $config and user: $user")
        // Start periodic check every 5 minutes
        startSdkSettingsCheck()
         startFlushEventCheck()
    }

        // Function to track events
    fun trackEvent(eventName: String, properties: Map<String, Any>) {
        // Create the EventData object internally with necessary fields
        val finalEvent = EventData(
            event_customer_id = UUID.randomUUID().toString(),
            event_type = EventType.TRACK,  // Hardcoded as TRACK
            properties = properties.toMutableMap(),  // Convert Map to MutableMap
            event_timestamp = DateTime.now(),
            session_id = sessionId,  // Using generated session ID
            timeuuid = UUID.randomUUID(),
            insert_id = UUID.randomUUID().toString()  // Automatically generate insert_id
        )

        // Add event to the queue
        eventQueue.offer(finalEvent)
        println("Event added to the queue: $finalEvent")

        // Check if the event queue should be flushed based on size
        if (eventQueue.size >= maxQueueSize) {
            flushEvents()
        }
    }

    // Function to check if the time condition for flushing is met
    private fun startFlushEventCheck() {
        fixedRateTimer("EventFlushCheck", daemon = true, period = 1000) {
            // Launch a coroutine to call the suspend function flushEvents
            CoroutineScope(Dispatchers.Default).launch {
                val lastEvent = eventQueue.peek()
                val currentTime = DateTime.now()
                if (lastEvent != null && currentTime.minusSeconds(maxTimeInSeconds).isAfter(lastEvent.event_timestamp)) {
                    // Call the suspend function flushEvents inside the coroutine
                    flushEvents()
                }
            }
        }
    }


    // Function to flush events to the server
    private suspend fun flushEvents() {
        if (eventQueue.isEmpty()) {
            println("No events to flush.")
            return
        }

        val eventsToFlush = mutableListOf<EventData>()

        // Drain the event queue into a list
        eventQueue.drainTo(eventsToFlush)

        // Send the events to the server through CFClient
        sendTrackEvents(eventsToFlush)
        println("Flushed ${eventsToFlush.size} events.")
    }


    // Function to send events to the server
    private suspend fun sendTrackEvents(events: List<EventData>) {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/v1/cfe")  // Replace with actual URL
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                val eventsJson = events.map { event ->
                    mapOf(
                        "event_customer_id" to event.event_customer_id,
                        "event_type" to event.event_type.toString(),                        
                        "properties" to event.properties,
                        "event_timestamp" to event.event_timestamp.toString(),
                        "session_id" to event.session_id,
                        "insert_id" to event.insert_id
                    )
                }

                val jsonPayload = JSONObject(
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


    // Function to check for updates every 5 minutes
    private fun startSdkSettingsCheck() {
        fixedRateTimer("SdkSettingsCheck", daemon = true, period = 300_000) {
            // Launch coroutine to call the suspend function
            CoroutineScope(Dispatchers.IO).launch {
                checkSdkSettings()
            }
        }
    }

    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/sdk-settings") // Replace with actual URL
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "HEAD"
                connection.connect()

                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val headers = connection.headerFields

                    // Fetch Last-Modified and ETag, which are lists of strings
                    val lastModified = headers["Last-Modified"]?.firstOrNull() ?: ""
                    val eTag = headers["ETag"]?.firstOrNull() ?: ""

                    // Return a map of headers (you can add more as needed)
                    return@withContext mapOf(
                        "Last-Modified" to lastModified,
                        "ETag" to eTag
                    )
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


    // Function to check the SDK settings by calling CloudFront API
    private suspend fun checkSdkSettings() {
        val metadata = fetchSdkSettingsMetadata()
        if (metadata != null) {
            val currentLastModified = metadata?.get("Last-Modified")
            // If the Last-Modified timestamp has changed, re-fetch the settings
            if (currentLastModified != previousLastModified) {
                println("SDK Settings have changed, re-fetching configurations.")
                fetchConfigs() // Re-fetch the configurations if settings have changed
                previousLastModified = currentLastModified
            }
        }
    }

    // Function to fetch the metadata (Last-Modified or ETag) from CloudFront API
    private suspend fun fetchSdkSettings(): SdkSettings? {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/sdk-settings")  // Replace with actual URL to CloudFront API
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connect()

                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().readText()
                    val jsonResponse = JSONObject(response)
                    val dateTimeString = jsonResponse.optString("date", null)
                    val date = if (dateTimeString != null) {
                        DateTime.parse(dateTimeString) // Parse the string into DateTime
                    } else {
                        null
                    }

                    val sdkSettings = SdkSettings(
                        cf_key = jsonResponse.getString("cf_key"),
                        cf_account_enabled = jsonResponse.getBoolean("cf_account_enabled"),
                        cf_page_elements_path_type = jsonResponse.optString("cf_page_elements_path_type", null),
                        cf_latest_sdk_version = jsonResponse.optString("cf_latest_sdk_version", null),
                        cf_whitelabel_company_display_name = jsonResponse.optString("cf_whitelabel_company_display_name", null),
                        cf_domain_url = jsonResponse.optString("cf_domain_url", null),
                        cf_jsevl_type = jsonResponse.optString("cf_jsevl_type", null),
                        cf_config_reapply_timers = jsonResponse.optString("cf_config_reapply_timers", null),
                        cf_ga4_setup_mode = jsonResponse.optString("cf_ga4_setup_mode", null),
                        cf_gtm_data_variable_name = jsonResponse.optString("cf_gtm_data_variable_name", null),
                        cf_account_source = jsonResponse.optString("cf_account_source", null),
                        cf_event_merge_config = jsonResponse.optString("cf_event_merge_config", null),
                        cf_dimension_id = jsonResponse.optString("cf_dimension_id", null),
                        cf_intelligent_code_enabled = jsonResponse.getBoolean("cf_intelligent_code_enabled"),
                        cf_personalize_post_sdk_timeout = jsonResponse.getBoolean("cf_personalize_post_sdk_timeout"),
                        is_inbound = jsonResponse.getBoolean("is_inbound"),
                        is_outbound = jsonResponse.getBoolean("is_outbound"),
                        cfspa = jsonResponse.getBoolean("cfspa"),
                        cfspa_auto_detect_page_url_change = jsonResponse.getBoolean("cfspa_auto_detect_page_url_change"),
                        is_auto_form_capture = jsonResponse.getBoolean("is_auto_form_capture"),
                        is_auto_email_capture = jsonResponse.getBoolean("is_auto_email_capture"),
                        cf_is_page_update_enabled = jsonResponse.getBoolean("cf_is_page_update_enabled"),
                        cf_retain_text_value = jsonResponse.getBoolean("cf_retain_text_value"),
                        cf_is_whitelabel_account = jsonResponse.getBoolean("cf_is_whitelabel_account"),
                        cf_skip_sdk = jsonResponse.getBoolean("cf_skip_sdk"),
                        enable_event_analyzer = jsonResponse.getBoolean("enable_event_analyzer"),
                        cf_skip_dfs = jsonResponse.getBoolean("cf_skip_dfs"),
                        cf_is_ms_clarity_enabled = jsonResponse.getBoolean("cf_is_ms_clarity_enabled"),
                        cf_is_hotjar_enabled = jsonResponse.getBoolean("cf_is_hotjar_enabled"),
                        cf_is_shopify_integrated = jsonResponse.getBoolean("cf_is_shopify_integrated"),
                        cf_is_ga_enabled = jsonResponse.getBoolean("cf_is_ga_enabled"),
                        cf_is_segment_enabled = jsonResponse.getBoolean("cf_is_segment_enabled"),
                        cf_is_mixpanel_enabled = jsonResponse.getBoolean("cf_is_mixpanel_enabled"),
                        cf_is_moengage_enabled = jsonResponse.getBoolean("cf_is_moengage_enabled"),
                        cf_is_clevertap_enabled = jsonResponse.getBoolean("cf_is_clevertap_enabled"),
                        cf_is_webengage_enabled = jsonResponse.getBoolean("cf_is_webengage_enabled"),
                        cf_is_netcore_enabled = jsonResponse.getBoolean("cf_is_netcore_enabled"),
                        cf_is_amplitude_enabled = jsonResponse.getBoolean("cf_is_amplitude_enabled"),
                        cf_is_heap_enabled = jsonResponse.getBoolean("cf_is_heap_enabled"),
                        cf_is_gokwik_enabled = jsonResponse.getBoolean("cf_is_gokwik_enabled"),
                        cf_is_shopflo_enabled = jsonResponse.getBoolean("cf_is_shopflo_enabled"),
                        cf_send_error_report = jsonResponse.getBoolean("cf_send_error_report"),
                        personalized_users_limit_exceeded = jsonResponse.getBoolean("personalized_users_limit_exceeded"),
                        cf_sdk_timeout_in_seconds = jsonResponse.getInt("cf_sdk_timeout_in_seconds"),
                        cf_initial_delay_in_ms = jsonResponse.getInt("cf_initial_delay_in_ms"),
                        cf_last_visited_product_url = jsonResponse.getInt("cf_last_visited_product_url"),
                        blacklisted_page_paths = jsonResponse.optJSONArray("blacklisted_page_paths")?.let {
                        List(it.length()) { index -> it.getString(index) }  // Corrected line
                        } ?: emptyList(),
                        blacklisted_referrers = jsonResponse.optJSONArray("blacklisted_referrers")?.let {
                            List(it.length()) { index -> it.getString(index) }  // Corrected line
                        } ?: emptyList(),
                        cf_subdomains = jsonResponse.optJSONArray("cf_subdomains")?.let {
                            List(it.length()) { index -> it.getString(index) }  // Corrected line
                        } ?: emptyList(),
                        cf_configs_json = jsonResponse.optJSONObject("cf_configs_json")?.let {
                            it.toMap() // You will need a custom extension to convert JSONObject to Map<String, Any>
                        } ?: emptyMap(),
                        cf_active_pages = jsonResponse.optJSONObject("cf_active_pages")?.let {
                            it.toMap() 
                        } ?: emptyMap(),
                        cf_revenue_pages = jsonResponse.optJSONObject("cf_revenue_pages")?.let {
                            it.toMap() 
                        } ?: emptyMap(),
                        cf_browser_variables = jsonResponse.optJSONObject("cf_browser_variables")?.let {
                            it.toMap()
                        } ?: emptyMap(),
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

    // Function to make the API request to fetch configurations
    private suspend fun fetchConfigs(): Map<String, Any>? {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/v1/users/configs?cfenc=${config.clientKey}")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                val userJson = JSONObject(user.properties).toString()
                val jsonInputString = """{
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

                    // Parse the JSON response
                    val jsonResponse = JSONObject(response)
                    val configs = jsonResponse.getJSONObject("configs")

                    // Map the configurations as key-value pairs
                    val configMap = mutableMapOf<String, Any>()
                    configs.keys().forEach { key ->
                        val config = configs.getJSONObject(key)
                        val experience = config.getJSONObject("experience_behaviour_response")
                        val experienceKey = experience.getString("experience")
                        val variation = config.getJSONObject("variation")
                        configMap[experienceKey] = variation 
                    }
                    this@CFClient.configMap = configMap // Store the configurations in the configMap
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

    // Get Methods for each type (String, Boolean, Number, Json)
    fun getString(key: String, fallbackValue: String): String {
        return getConfigValue(key, fallbackValue) { value -> value is String }
    }

    fun getNumber(key: String, fallbackValue: Number): Number {
        return getConfigValue(key, fallbackValue) { value -> value is Number }
    }

    fun getBoolean(key: String, fallbackValue: Boolean): Boolean {
        return getConfigValue(key, fallbackValue) { value -> value is Boolean }
    }

    fun getJson(key: String, fallbackValue: Map<String, Any>): Map<String, Any> {
        return getConfigValue(key, fallbackValue) { value -> value is Map<*, *> && value.keys.all { it is String } }
    }

    // Generic function to get config value based on type check
    private fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        val config = configMap[key] // Now reading from the configMap
        return if (config != null && typeCheck(config)) {
            config as T
        } else {
            fallbackValue
        }
    }

    companion object {
        fun init(config: CFConfig, user: CFUser): CFClient {
            return CFClient(config, user)
        }
    }
}
