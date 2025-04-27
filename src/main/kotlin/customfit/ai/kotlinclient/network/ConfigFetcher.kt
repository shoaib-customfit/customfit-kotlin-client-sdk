package customfit.ai.kotlinclient.network

import customfit.ai.kotlinclient.core.config.CFConfig
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.core.util.RetryUtil.withRetry
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.config.CFConfigChangeManager
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*

/** Handles fetching configuration from the CustomFit API with support for offline mode */
class ConfigFetcher(
        private val httpClient: HttpClient,
        private val cfConfig: CFConfig,
        private val user: CFUser
) {
    private val offlineMode = AtomicBoolean(false)
    private val fetchMutex = Mutex()
    private var lastConfigMap: Map<String, Any>? = null
    private val mutex = Mutex()
    private var lastFetchTime: Long = 0

    /** Returns whether the client is in offline mode */
    fun isOffline(): Boolean = offlineMode.get()

    /**
     * Sets the offline mode status
     *
     * @param offline true to enable offline mode, false to disable
     */
    fun setOffline(offline: Boolean) {
        offlineMode.set(offline)
        Timber.i("ConfigFetcher offline mode set to: $offline")
    }

    /**
     * Fetches configuration from the API
     *
     * @param lastModified Optional last-modified header value for conditional requests
     * @return The configuration map, or null if fetching failed
     */
    suspend fun fetchConfig(lastModified: String? = null): Map<String, Any>? {
        // Don't fetch if in offline mode
        if (isOffline()) {
            Timber.d("Not fetching config because client is in offline mode")
            return null
        }

        return fetchMutex.withLock {
            try {
                val url = "https://api.customfit.ai/v1/users/configs?cfenc=${cfConfig.clientKey}"
                // Build payload using kotlinx.serialization and the helper
                val jsonObject = buildJsonObject {
                    put(
                            "user",
                            buildJsonObject {
                                user.toUserMap().forEach { (k, v) -> put(k, anyToJsonElement(v)) }
                            }
                    )
                    put("include_only_features_flags", JsonPrimitive(true))
                }
                val payload = Json.encodeToString(jsonObject)

                Timber.d("Config fetch payload: $payload")

                val headers = mutableMapOf<String, String>("Content-Type" to "application/json")
                lastModified?.let {
                    headers["If-Modified-Since"] = it
                } // Keep If-Modified-Since for request optimization

                val responseBody =
                        httpClient.performRequest(url, "POST", headers, payload) { conn ->
                            val responseCode = conn.responseCode
                            if (responseCode == java.net.HttpURLConnection.HTTP_OK) {
                                conn.inputStream.bufferedReader().readText()
                            } else {
                                Timber.warn { "Failed to fetch config from $url: $responseCode" }
                                null
                            }
                        }

                if (responseBody == null) {
                    Timber.warn { "Failed to fetch configuration body" }
                    return@withLock null
                }

                processConfigResponse(responseBody)
            } catch (e: Exception) {
                if (e is kotlinx.serialization.SerializationException) {
                    Timber.e(e, "Serialization error creating config payload: ${e.message}")
                } else {
                    Timber.e(e, "Error fetching configuration: ${e.message}")
                }
                null
            }
        }
    }

    /**
     * Process the configuration response, flattening nested experience data using
     * kotlinx.serialization.
     *
     * @param jsonResponse The JSON response string from the API
     * @return A map containing flattened configurations.
     */
    private fun processConfigResponse(jsonResponse: String): Map<String, Any>? {
        val finalConfigMap = mutableMapOf<String, Any>()

        try {
            // Parse the entire response string into a JsonElement
            val responseElement = Json.parseToJsonElement(jsonResponse)
            if (responseElement !is JsonObject) {
                Timber.warn { "Response is not a JSON object." }
                return null
            }
            val responseJson = responseElement.jsonObject // Access as JsonObject

            val configsJson = responseJson["configs"]?.jsonObject

            if (configsJson == null) {
                Timber.warn { "No 'configs' object found in the response." }
                return emptyMap()
            }

            // Iterate through each config entry
            configsJson.entries.forEach { (key, configElement) ->
                try {
                    if (configElement !is JsonObject) {
                        Timber.warn { "Config entry for '$key' is not a JSON object" }
                        return@forEach
                    }
                    val configObject = configElement.jsonObject
                    val experienceObject = configObject["experience_behaviour_response"]?.jsonObject

                    // Convert the config JsonObject to a mutable map
                    val flattenedMap = jsonObjectToMap(configObject).toMutableMap()

                    // Remove the nested object itself (it will be merged)
                    flattenedMap.remove("experience_behaviour_response")

                    // Merge fields from the nested experience object if it exists
                    experienceObject?.let { flattenedMap.putAll(jsonObjectToMap(it)) }

                    // Store the flattened map, ensuring Any? values are handled or filtered if
                    // needed
                    @Suppress("UNCHECKED_CAST")
                    finalConfigMap[key] =
                            flattenedMap.filterValues { it != null } as Map<String, Any>
                } catch (e: Exception) {
                    Timber.e(e, "Error processing individual config key '$key': ${e.message}")
                }
            }

            // Notify observers of config changes
            if (finalConfigMap != lastConfigMap) {
                CFConfigChangeManager.notifyObservers(finalConfigMap, lastConfigMap)
                lastConfigMap = finalConfigMap
            }
            
            return finalConfigMap
        } catch (e: Exception) {
            Timber.e(e, "Error parsing configuration response: ${e.message}")
            return null // Return null on parsing error
        }
    }

    // --- kotlinx.serialization based helpers ---

    /** Converts a JsonObject to a Map<String, Any?>. */
    private fun jsonObjectToMap(jsonObject: JsonObject): Map<String, Any?> {
        return jsonObject.mapValues { jsonElementToValue(it.value) }
    }

    /** Converts a JsonArray to a List<Any?>. */
    private fun jsonArrayToList(jsonArray: JsonArray): List<Any?> {
        return jsonArray.map { jsonElementToValue(it) }
    }

    /** Recursively converts a JsonElement to a Kotlin primitive, Map, or List. */
    private fun jsonElementToValue(element: JsonElement?): Any? {
        return when (element) {
            is JsonNull -> null
            is JsonPrimitive ->
                    when {
                        element.isString -> element.content
                        element.booleanOrNull != null -> element.boolean
                        element.longOrNull != null -> element.long // Prioritize Long
                        element.doubleOrNull != null -> element.double // Then Double
                        else -> element.content // Fallback
                    }
            is JsonObject -> jsonObjectToMap(element)
            is JsonArray -> jsonArrayToList(element)
            null -> null
        }
    }

    /**
     * Fetches metadata from a URL
     *
     * @param url The URL to fetch metadata from
     * @return A map of metadata headers, or null if fetching failed
     */
    suspend fun fetchMetadata(url: String): Map<String, String>? {
        if (isOffline()) {
            Timber.d("Not fetching metadata because client is in offline mode")
            return null
        }

        return try {
            httpClient.fetchMetadata(url)
        } catch (e: Exception) {
            Timber.e(e, "Error fetching metadata: ${e.message}")
            null
        }
    }

    /** Helper function to convert Any to JsonElement */
    private fun anyToJsonElement(value: Any?): JsonElement =
            when (value) {
                null -> JsonNull
                is String -> JsonPrimitive(value)
                is Number -> JsonPrimitive(value)
                is Boolean -> JsonPrimitive(value)
                is Map<*, *> -> {
                    buildJsonObject {
                        value.entries.forEach { (k, v) ->
                            if (k is String) {
                                put(k, anyToJsonElement(v))
                            }
                        }
                    }
                }
                is List<*> -> {
                    buildJsonArray { value.forEach { item -> add(anyToJsonElement(item)) } }
                }
                else -> JsonPrimitive(value.toString())
            }
}