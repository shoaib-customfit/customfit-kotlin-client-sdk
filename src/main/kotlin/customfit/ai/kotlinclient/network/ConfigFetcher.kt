package customfit.ai.kotlinclient.network

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import mu.KotlinLogging
import org.json.JSONObject
import org.json.JSONArray

private val logger = KotlinLogging.logger {}

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
                val payload = JSONObject()
                    .apply {
                        put("user", JSONObject(user.toUserMap()))
                        put("include_only_features_flags", true)
                    }
                    .toString()

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
                logger.error(e) { "Error fetching configuration: ${e.message}" }
                null
            }
        }
    }
    
    /**
     * Process the configuration response, flattening nested experience data.
     * 
     * @param jsonResponse The JSON response from the API
     * @return A map containing flattened configurations.
     */
    private fun processConfigResponse(jsonResponse: String): Map<String, Any> {        
        val finalConfigMap = mutableMapOf<String, Any>()
        
        try {
            val responseJson = JSONObject(jsonResponse)
            val configsJson = responseJson.optJSONObject("configs")
            
            if (configsJson == null) {
                logger.warn { "No 'configs' object found in the response." }
                return emptyMap()
            }

            // Iterate through each config entry (e.g., "shoaib-1")
            configsJson.keys().forEach { key ->
                try {
                    val configObject = configsJson.getJSONObject(key)
                    val experienceObject = configObject.optJSONObject("experience_behaviour_response")

                    // Start with top-level fields using the helper function
                    val flattenedMap = jsonObjectToMap(configObject).toMutableMap()
                    
                    // Remove the nested object itself
                    flattenedMap.remove("experience_behaviour_response") 

                    // Merge fields from the nested object if it exists, using the helper function
                    experienceObject?.let {
                        flattenedMap.putAll(jsonObjectToMap(it))
                    }

                    // Store the flattened map
                    finalConfigMap[key] = flattenedMap
                    
                } catch (e: Exception) {
                    logger.error(e) { "Error processing individual config key '$key': ${e.message}" }
                }
            }
            
            return finalConfigMap
            
        } catch (e: Exception) {
            logger.error(e) { "Error parsing configuration response: ${e.message}" }
            return emptyMap()
        }
    }
    
    /**
     * Manually converts a JSONObject to a Map, as JSONObject.toMap() is not available on Android.
     */
    private fun jsonObjectToMap(jsonObject: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = jsonObject.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            var value = jsonObject.get(key)
            
            when (value) {
                is JSONObject -> value = jsonObjectToMap(value)
                is JSONArray -> value = jsonArrayToList(value)
                JSONObject.NULL -> value = null
            }
            map[key] = value
        }
        return map
    }

    /**
     * Manually converts a JSONArray to a List.
     */
    private fun jsonArrayToList(jsonArray: JSONArray): List<Any?> {
        val list = mutableListOf<Any?>()
        for (i in 0 until jsonArray.length()) {
            var value = jsonArray.get(i)
            when (value) {
                is JSONObject -> value = jsonObjectToMap(value)
                is JSONArray -> value = jsonArrayToList(value)
                JSONObject.NULL -> value = null
            }
            list.add(value)
        }
        return list
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
        "properties" to properties
    )
} 