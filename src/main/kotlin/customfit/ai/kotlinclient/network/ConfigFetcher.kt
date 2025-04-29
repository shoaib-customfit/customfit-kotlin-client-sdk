package customfit.ai.kotlinclient.network

import customfit.ai.kotlinclient.config.change.CFConfigChangeManager
import customfit.ai.kotlinclient.constants.CFConstants
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.core.error.ErrorHandler
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.core.util.RetryUtil.withRetry
import customfit.ai.kotlinclient.logging.Timber
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*

/** Handles fetching configuration from the CustomFit API with support for offline mode */
class ConfigFetcher(
        private val httpClient: HttpClient,
        private val cfConfig: CFConfig,
        private val user: CFUser
) {
    companion object {
        private const val SOURCE = "ConfigFetcher"
    }
    
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
     * Fetches configuration from the API with improved error handling
     *
     * @param lastModified Optional last-modified header value for conditional requests
     * @return CFResult containing configuration map or error details
     */
    suspend fun fetchConfig(lastModified: String? = null): CFResult<Map<String, Any>> {
        // Don't fetch if in offline mode
        if (isOffline()) {
            Timber.d("Not fetching config because client is in offline mode")
            return CFResult.error(
                "Client is in offline mode",
                category = ErrorHandler.ErrorCategory.NETWORK
            )
        }

        return fetchMutex.withLock {
            try {
                val url = "${CFConstants.Api.BASE_API_URL}${CFConstants.Api.USER_CONFIGS_PATH}?cfenc=${cfConfig.clientKey}"
                
                // Build payload using kotlinx.serialization
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

                val headers = mutableMapOf<String, String>(
                    CFConstants.Http.HEADER_CONTENT_TYPE to CFConstants.Http.CONTENT_TYPE_JSON
                )
                lastModified?.let {
                    headers[CFConstants.Http.HEADER_IF_MODIFIED_SINCE] = it
                }

                // Use the updated HttpClient that returns CFResult
                val responseBodyResult = suspendGetResponseBody(url, headers, payload)
                
                if (responseBodyResult.isFailure) {
                    val exception = responseBodyResult.exceptionOrNull()
                    ErrorHandler.handleError(
                        "Failed to fetch configuration body", 
                        SOURCE,
                        ErrorHandler.ErrorCategory.NETWORK,
                        ErrorHandler.ErrorSeverity.HIGH
                    )
                    return@withLock CFResult.error(
                        "Failed to fetch configuration body: ${exception?.message ?: "Unknown error"}",
                        exception,
                        category = ErrorHandler.ErrorCategory.NETWORK
                    )
                }
                
                val responseBody = responseBodyResult.getOrNull()
                if (responseBody == null) {
                    ErrorHandler.handleError(
                        "Failed to fetch configuration body (empty response)", 
                        SOURCE,
                        ErrorHandler.ErrorCategory.NETWORK,
                        ErrorHandler.ErrorSeverity.HIGH
                    )
                    return@withLock CFResult.error(
                        "Failed to fetch configuration body (empty response)",
                        category = ErrorHandler.ErrorCategory.NETWORK
                    )
                }
                
                // Process configuration response
                return@withLock processConfigResponse(responseBody)
            } catch (e: Exception) {
                val category = when (e) {
                    is SerializationException -> ErrorHandler.ErrorCategory.SERIALIZATION
                    else -> ErrorHandler.ErrorCategory.INTERNAL
                }
                
                ErrorHandler.handleException(
                    e,
                    "Error fetching configuration",
                    SOURCE,
                    ErrorHandler.ErrorSeverity.HIGH
                )
                
                CFResult.error(
                    "Error fetching configuration: ${e.message}",
                    e,
                    category = category
                )
            }
        }
    }
    
    /**
     * Helper method to get the response body from a URL
     */
    private suspend fun suspendGetResponseBody(url: String, headers: Map<String, String>, payload: String): Result<String?> {
        return try {
            val result = httpClient.performRequest(url, "POST", headers, payload) { conn ->
                val responseCode = conn.responseCode
                if (responseCode == java.net.HttpURLConnection.HTTP_OK) {
                    conn.inputStream.bufferedReader().readText()
                } else {
                    Timber.w("Failed to fetch config from $url: $responseCode")
                    null
                }
            }
            Result.success(result)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Process the configuration response, with improved error handling
     *
     * @param jsonResponse The JSON response string from the API
     * @return CFResult containing the processed config map or error details
     */
    private fun processConfigResponse(jsonResponse: String): CFResult<Map<String, Any>> {
        val finalConfigMap = mutableMapOf<String, Any>()

        try {
            // Parse the entire response string into a JsonElement
            val responseElement = Json.parseToJsonElement(jsonResponse)
            if (responseElement !is JsonObject) {
                val message = "Response is not a JSON object"
                ErrorHandler.handleError(
                    message,
                    SOURCE,
                    ErrorHandler.ErrorCategory.SERIALIZATION,
                    ErrorHandler.ErrorSeverity.HIGH
                )
                return CFResult.error(
                    message,
                    category = ErrorHandler.ErrorCategory.SERIALIZATION
                )
            }
            
            val responseJson = responseElement.jsonObject
            val configsJson = responseJson["configs"]?.jsonObject

            if (configsJson == null) {
                val message = "No 'configs' object found in the response"
                ErrorHandler.handleError(
                    message,
                    SOURCE,
                    ErrorHandler.ErrorCategory.VALIDATION,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
                return CFResult.success(emptyMap())
            }

            // Iterate through each config entry
            configsJson.entries.forEach { (key, configElement) ->
                try {
                    if (configElement !is JsonObject) {
                        ErrorHandler.handleError(
                            "Config entry for '$key' is not a JSON object",
                            SOURCE,
                            ErrorHandler.ErrorCategory.SERIALIZATION,
                            ErrorHandler.ErrorSeverity.MEDIUM
                        )
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

                    // Store the flattened map, ensuring Any? values are handled or filtered if needed
                    @Suppress("UNCHECKED_CAST")
                    finalConfigMap[key] =
                            flattenedMap.filterValues { it != null } as Map<String, Any>
                } catch (e: Exception) {
                    ErrorHandler.handleException(
                        e,
                        "Error processing individual config key '$key'",
                        SOURCE,
                        ErrorHandler.ErrorSeverity.MEDIUM
                    )
                }
            }

            // Notify observers of config changes
            if (finalConfigMap != lastConfigMap) {
                CFConfigChangeManager.notifyObservers(finalConfigMap, lastConfigMap)
                lastConfigMap = finalConfigMap
                lastFetchTime = System.currentTimeMillis()
            }
            
            return CFResult.success(finalConfigMap)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Error parsing configuration response",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            
            return CFResult.error(
                "Error parsing configuration response: ${e.message}",
                e,
                category = ErrorHandler.ErrorCategory.SERIALIZATION
            )
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
     * Fetches metadata from a URL with improved error handling
     *
     * @param url The URL to fetch metadata from
     * @return CFResult containing metadata headers or error details
     */
    suspend fun fetchMetadata(url: String): CFResult<Map<String, String>> {
        if (isOffline()) {
            Timber.d("Not fetching metadata because client is in offline mode")
            return CFResult.error(
                "Client is in offline mode",
                category = ErrorHandler.ErrorCategory.NETWORK
            )
        }

        try {
            return httpClient.fetchMetadata(url)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Error fetching metadata from $url",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            
            return CFResult.error(
                "Error fetching metadata: ${e.message}",
                e,
                category = ErrorHandler.ErrorCategory.NETWORK
            )
        }
    }

    /** Helper function to convert Any to JsonElement */
    private fun anyToJsonElement(value: Any?): JsonElement = when (value) {
        null -> JsonNull
        is String -> JsonPrimitive(value)
        is Number -> JsonPrimitive(value)
        is Boolean -> JsonPrimitive(value)
        is Map<*, *> -> buildJsonObject {
            value.forEach { (k, v) ->
                if (k is String) {
                    put(k, anyToJsonElement(v))
                }
            }
        }
        is List<*> -> buildJsonArray {
            value.forEach { item ->
                add(anyToJsonElement(item))
            }
        }
        else -> JsonPrimitive(value.toString())
    }
}