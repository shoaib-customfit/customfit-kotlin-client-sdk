package customfit.ai.kotlinclient.network

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import mu.KotlinLogging
import org.json.JSONObject

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
     * @return A pair containing the configuration map and metadata map, or null if fetching failed
     */
    suspend fun fetchConfig(lastModified: String? = null): Pair<Map<String, Any>, Map<String, String>>? {
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
                    
                val headers = mutableMapOf<String, String>(
                    "Content-Type" to "application/json"
                )
                lastModified?.let { headers["If-Modified-Since"] = it }
                
                val jsonResult = httpClient.performRequest(url, "POST", headers, payload) { conn ->
                    val responseCode = conn.responseCode
                    if (responseCode == java.net.HttpURLConnection.HTTP_OK) {
                        val responseBody = conn.inputStream.bufferedReader().readText()
                        val metadata = mapOf(
                            "Last-Modified" to (conn.getHeaderField("Last-Modified") ?: ""),
                            "ETag" to (conn.getHeaderField("ETag") ?: "")
                        )
                        Pair(responseBody, metadata)
                    } else {
                        logger.warn { "Failed to fetch config from $url: $responseCode" }
                        null
                    }
                }
                
                if (jsonResult == null) {
                    logger.warn { "Failed to fetch configuration" }
                    return@withLock null
                }
                
                val configMap = processConfigResponse(jsonResult.first)
                val metadata = jsonResult.second
                
                Pair(configMap, metadata)
            } catch (e: Exception) {
                logger.error(e) { "Error fetching configuration: ${e.message}" }
                null
            }
        }
    }
    
    /**
     * Process the configuration response
     * 
     * @param jsonResponse The JSON response from the API
     * @return A map of configurations
     */
    private fun processConfigResponse(jsonResponse: String): Map<String, Any> {
        val newConfigMap = mutableMapOf<String, Any>()
        
        try {
            val responseJson = JSONObject(jsonResponse)
            val configsJson = responseJson.optJSONObject("configs") ?: return emptyMap()
            
            for (key in configsJson.keys()) {
                try {
                    val experienceJson = configsJson.getJSONObject(key)
                    val experience = experienceJson.optJSONObject("experience") ?: continue
                    
                    val experienceKey = experience.optString("key", key)
                    val variationType = experience.optString("variation_type", "string")
                    val variationValue = experience.opt("variation") ?: continue
                    
                    val variation = when (variationType) {
                        "number" -> variationValue.toString().toDoubleOrNull() ?: 0.0
                        "boolean" -> variationValue.toString().toBoolean()
                        "json" -> try { 
                            val jsonObj = JSONObject(variationValue.toString())
                            val result = mutableMapOf<String, Any>()
                            for (jsonKey in jsonObj.keys()) {
                                result[jsonKey] = jsonObj.get(jsonKey)
                            }
                            result
                        } catch (e: Exception) {
                            mapOf<String, Any>()
                        }
                        else -> variationValue.toString()
                    }
                    
                    // Create the experience data map
                    val experienceData = mapOf(
                        "config_id" to experience.optString("config_id", null),
                        "variation_id" to experience.optString("variation_id", null),
                        "priority" to experience.optInt("priority", 0),
                        "experience_created_time" to experience.optLong("experience_created_time", 0L),
                        "rule_id" to experience.optString("rule_id", null),
                        "experience" to experienceKey,
                        "audience_name" to experience.optString("audience_name", null),
                        "ga_measurement_id" to experience.optString("ga_measurement_id", null),
                        "type" to experience.optString("type", null),
                        "config_modifications" to experience.optString("config_modifications", null),
                        "variation_data_type" to variationType,
                        "variation" to variation
                    )
                    
                    newConfigMap[experienceKey] = experienceData
                } catch (e: Exception) {
                    logger.error(e) { "Error processing config key '$key': ${e.message}" }
                }
            }
        } catch (e: Exception) {
            logger.error(e) { "Error parsing configuration response: ${e.message}" }
            return emptyMap()
        }
        
        return newConfigMap
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