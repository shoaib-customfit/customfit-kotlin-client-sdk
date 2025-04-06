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

    private val sdkSettingsDeferred: CompletableDeferred<Unit> = CompletableDeferred()

    init {
        println("CFClient initialized with config: $config and user: $user")

        // Run the initial SDK settings check synchronously during init
        runBlocking(Dispatchers.IO) {
            try {
                println("Before calling checkSdkSettings() in init")
                checkSdkSettings() // Fetch SDK settings immediately and block until done
                sdkSettingsDeferred.complete(Unit) // Mark as completed
                println("Initial SDK Settings check completed in init!")
            } catch (e: Exception) {
                println("Error in initial checkSdkSettings: ${e.message}")
                sdkSettingsDeferred.completeExceptionally(e) // Complete with exception if failed
            }
        }

        // Start background periodic checks
        startSdkSettingsCheck()
        startFlushEventCheck()
    }

    suspend fun awaitSdkSettingsCheck() {
        sdkSettingsDeferred.await() // Ensure that SDK settings check is completed before proceeding
    }

    private fun startSdkSettingsCheck() {
        fixedRateTimer("SdkSettingsCheck", daemon = true, period = 300_000) {
            CoroutineScope(Dispatchers.IO).launch {
                println("Periodic SDK settings check triggered")
                checkSdkSettings()
            }
        }
    }

    suspend fun checkSdkSettings() {
        try {
            println("Fetching SDK settings...")
            val metadata = fetchSdkSettingsMetadata() // This should now be called
            println("Metadata fetched: $metadata")
            if (metadata != null) {
                val currentLastModified = metadata["Last-Modified"]
                if (currentLastModified != previousLastModified) {
                    println("SDK Settings have changed, re-fetching configurations.")
                    fetchConfigs() // Fetch the settings immediately
                    previousLastModified = currentLastModified
                } else {
                    println("No change in Last-Modified header, skipping fetch.")
                }
            } else {
                println("Metadata is null, something went wrong during fetching.")
            }
        } catch (e: Exception) {
            println("Error during SDK settings check: ${e.message}")
        }
    }

    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? {
        return try {
            println("Attempting to fetch SDK settings metadata...")
            val url = URL("https://sdk.customfit.ai/${config.dimensionId}/cf-sdk-settings.json")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "HEAD"
            connection.connect()

            if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                val headers = connection.headerFields
                val lastModified = headers["Last-Modified"]?.firstOrNull() ?: ""
                val eTag = headers["ETag"]?.firstOrNull() ?: ""
                println("Headers fetched: Last-Modified = $lastModified, ETag = $eTag")
                mapOf("Last-Modified" to lastModified, "ETag" to eTag)
            } else {
                println("Error fetching SDK Settings metadata: ${connection.responseCode}")
                null
            }
        } catch (e: Exception) {
            println("Error in fetchSdkSettingsMetadata: ${e.message}")
            null
        } finally {
            // Ensure connection is closed if needed (optional based on your needs)
        }
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
            CoroutineScope(Dispatchers.Default).launch { flushEvents() }
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

    private suspend fun fetchSdkSettings(): SdkSettings? {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://sdk.customfit.ai/${config.dimensionId}/cf-sdk-settings.json")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connect()

                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().readText()
                    val jsonResponse = JSONObject(response)
                    val sdkSettings = SdkSettings.fromJson(jsonResponse)

                    if (sdkSettings != null &&
                                    (!sdkSettings.cf_account_enabled || sdkSettings.cf_skip_sdk)
                    ) {
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
                val url = URL("https://api.customfit.ai/v1/users/configs?cfenc=${config.clientKey}")
                println(url)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                val userJson = JSONObject(user).toString()
                val jsonInputString =
                        """{
                "user": $userJson,
                "include_only_features_flags": true
            }"""

                println(jsonInputString)

                connection.outputStream.use { os ->
                    val input = jsonInputString.toByteArray(Charsets.UTF_8)
                    os.write(input, 0, input.size)
                }

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().readText()
                    val jsonResponse = JSONObject(response)
                    val configs = jsonResponse.getJSONObject("configs")

                    val configMap = mutableMapOf<String, Any>()
                    configs.keys().forEach { key ->
                        val config = configs.getJSONObject(key)
                        val experience = config.getJSONObject("experience_behaviour_response")
                        val experienceKey = experience.getString("experience")
                        val variationDataType = config.getString("variation_data_type")
                        val variation: Any =
                                when (variationDataType.uppercase()) {
                                    "STRING" -> config.getString("variation")
                                    "BOOLEAN" -> config.getBoolean("variation")
                                    "NUMBER" ->
                                            config.getDouble(
                                                    "variation"
                                            ) // Use Double to handle both int and float
                                    "JSON" -> config.getJSONObject("variation").toMap()
                                    else -> {
                                        println(
                                                "Unknown variation_data_type: $variationDataType for config $key"
                                        )
                                        config.get("variation") // Fallback to raw value
                                    }
                                }
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

    @Suppress("UNCHECKED_CAST")
    private fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        val config = configMap[key]
        return if (config != null && typeCheck(config)) {
            @Suppress("UNCHECKED_CAST") config as? T ?: fallbackValue
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
                            user_customer_id = user.user_customer_id,
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
                val url = URL("https://example.com/v1/config/request/summary")
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
