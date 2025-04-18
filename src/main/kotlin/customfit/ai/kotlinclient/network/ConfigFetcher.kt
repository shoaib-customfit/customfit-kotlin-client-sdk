package customfit.ai.kotlinclient.network

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import mu.KotlinLogging
import kotlinx.serialization.json.*
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.encodeToString

private val logger = KotlinLogging.logger {}

// --- NEW Helper function to serialize Any --- 
private fun anyToJsonElement(value: Any?): JsonElement = when (value) {
    null -> JsonNull
    is JsonElement -> value // If it's already a JsonElement, return it directly
    is String -> JsonPrimitive(value)
    is Number -> JsonPrimitive(value)
    is Boolean -> JsonPrimitive(value)
    is Map<*, *> -> buildJsonObject { // Recursively handle maps
        value.forEach { (k, v) ->
            if (k is String) {
                put(k, anyToJsonElement(v)) // Recursive call
            } else {
                // Handle non-string keys if necessary, e.g., convert toString or throw error
                logger.warn { "Skipping non-string key in map during serialization: $k" }
            }
        }
    }
    is Iterable<*> -> buildJsonArray { // Recursively handle lists/collections
        value.forEach { 
            add(anyToJsonElement(it)) // Recursive call
        }
    }
    // Add other specific types if needed (e.g., Date -> JsonPrimitive(date.toString()))
    else -> throw kotlinx.serialization.SerializationException("Serializer for class '${value::class.simpleName}' is not found. Cannot serialize value of type Any.")
}
// --- End Helper function --- 

/**
 * Handles fetching configuration from the CustomFit API with support for offline mode
 */
class ConfigFetcher(
    private val httpClient: HttpClient,
    private val cfConfig: CFConfig,
    private val user: CFUser
) {
    private val offlineMode = AtomicBoolean(false)
    private val fetchMutex = Mutex()
    
    /**
     * Returns whether the client is in offline mode
     */
    fun isOffline(): Boolean = offlineMode.get()
    
    /**
     * Sets the offline mode status
     * 
     * @param offline true to enable offline mode, false to disable
     */
    fun setOffline(offline: Boolean) {
        offlineMode.set(offline)
        logger.info { "ConfigFetcher offline mode set to: $offline" }
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
            logger.debug { "Not fetching config because client is in offline mode" }
            return null
        }
        
        return fetchMutex.withLock {
            try {
                val url = "https://api.customfit.ai/v1/users/configs?cfenc=${cfConfig.clientKey}"
                // Build payload using kotlinx.serialization and the new helper
                val payload = Json.encodeToString(buildJsonObject {
                    put("user", buildJsonObject { 
                        // Use helper function for values in user map
                        user.toUserMap().forEach { (k, v) ->
                            put(k, anyToJsonElement(v))
                        }
                    })
                    put("include_only_features_flags", JsonPrimitive(true))
                })

                println("payload: $payload")
                    
                val headers = mutableMapOf<String, String>(
                    "Content-Type" to "application/json"
                )
                lastModified?.let { headers["If-Modified-Since"] = it } // Keep If-Modified-Since for request optimization
                
                val responseBody = httpClient.performRequest(url, "POST", headers, payload) { conn ->
                    val responseCode = conn.responseCode
                    if (responseCode == java.net.HttpURLConnection.HTTP_OK) {
                        conn.inputStream.bufferedReader().readText()
                    } else {
                        logger.warn { "Failed to fetch config from $url: $responseCode" }
                        null
                    }
                }
                
                if (responseBody == null) {
                    logger.warn { "Failed to fetch configuration body" }
                    return@withLock null
                }
                
                processConfigResponse(responseBody)
            } catch (e: Exception) {
                // Catch specific SerializationException from helper if needed
                 if (e is kotlinx.serialization.SerializationException) {
                    logger.error(e) { "Serialization error creating config payload: ${e.message}" }
                 } else {
                    logger.error(e) { "Error fetching configuration: ${e.message}" }
                 }
                null
            }
        }
    }
    
    /**
     * Process the configuration response, flattening nested experience data using kotlinx.serialization.
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
                logger.warn { "Response is not a JSON object." }
                return null
            }
            val responseJson = responseElement.jsonObject // Access as JsonObject
            
            val configsJson = responseJson["configs"]?.jsonObject
            
            if (configsJson == null) {
                logger.warn { "No 'configs' object found in the response." }
                return emptyMap()
            }

            // Iterate through each config entry (e.g., "shoaib-1")
            configsJson.entries.forEach { (key, configElement) ->
                try {
                    if (configElement !is JsonObject) {
                         logger.warn { "Config entry for '$key' is not a JSON object" }
                         return@forEach
                    }
                    val configObject = configElement.jsonObject
                    val experienceObject = configObject["experience_behaviour_response"]?.jsonObject

                    // Convert the config JsonObject to a mutable map
                    val flattenedMap = jsonObjectToMap(configObject).toMutableMap()
                    
                    // Remove the nested object itself (it will be merged)
                    flattenedMap.remove("experience_behaviour_response") 

                    // Merge fields from the nested experience object if it exists
                    experienceObject?.let {
                        flattenedMap.putAll(jsonObjectToMap(it))
                    }

                    // Store the flattened map, ensuring Any? values are handled or filtered if needed
                    // We need Map<String, Any> as the return type, so filter out nulls if they can occur
                    finalConfigMap[key] = flattenedMap.filterValues { it != null } as Map<String, Any>
                    
                } catch (e: Exception) {
                    logger.error(e) { "Error processing individual config key '$key': ${e.message}" }
                }
            }
            
            return finalConfigMap
            
        } catch (e: Exception) {
            logger.error(e) { "Error parsing configuration response: ${e.message}" }
            return null // Return null on parsing error
        }
    }
    
    // --- kotlinx.serialization based helpers ---
    
    /**
     * Converts a JsonObject to a Map<String, Any?>.
     */
    private fun jsonObjectToMap(jsonObject: JsonObject): Map<String, Any?> {
        return jsonObject.mapValues { jsonElementToValue(it.value) }
    }

    /**
     * Converts a JsonArray to a List<Any?>.
     */
    private fun jsonArrayToList(jsonArray: JsonArray): List<Any?> {
        return jsonArray.map { jsonElementToValue(it) }
    }

    /**
     * Recursively converts a JsonElement to a Kotlin primitive, Map, or List.
     */
     private fun jsonElementToValue(element: JsonElement?): Any? {
        return when (element) {
            is JsonNull -> null
            is JsonPrimitive -> when {
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
            logger.debug { "Not fetching metadata because client is in offline mode" }
            return null
        }
        
        return try {
            httpClient.fetchMetadata(url)
        } catch (e: Exception) {
            logger.error(e) { "Error fetching metadata: ${e.message}" }
            null
        }
    }
    
    /**
     * Helper method to convert the user to a map
     */
    private fun CFUser.toUserMap(): Map<String, Any?> = mapOf(
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
        // Include current properties from the user object
        "properties" to this.getCurrentProperties() 
    ).filterValues { it != null } // Ensure nulls are filtered if not desired in payload
} 