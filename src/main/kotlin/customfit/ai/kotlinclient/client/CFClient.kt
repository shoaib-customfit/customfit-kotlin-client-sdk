package customfit.ai.kotlinclient.client

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import customfit.ai.kotlinclient.core.SdkSettings
import customfit.ai.kotlinclient.events.EventPropertiesBuilder
import customfit.ai.kotlinclient.events.EventTracker
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.summaries.SummaryManager
import java.net.HttpURLConnection
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import mu.KotlinLogging
import org.json.JSONObject
import org.joda.time.DateTime

private val logger = KotlinLogging.logger {}

class CFClient private constructor(private val cfConfig: CFConfig, private val user: CFUser) {
    private val sessionId: String = UUID.randomUUID().toString()
    private val httpClient = HttpClient(cfConfig)
    val summaryManager = SummaryManager(sessionId, httpClient, user, cfConfig)
    val eventTracker = EventTracker(sessionId, httpClient, user, summaryManager, cfConfig)

    @Volatile private var previousLastModified: String? = null
    private val configMap: MutableMap<String, Any> =
            Collections.synchronizedMap(mutableMapOf()) // Thread-safe
    private val configMutex = Mutex() // For atomic updates
    private val sdkSettingsDeferred: CompletableDeferred<Unit> = CompletableDeferred()

    // Add listener methods for continuous updates
    private val configListeners = ConcurrentHashMap<String, MutableList<(Any) -> Unit>>()
    
    /**
     * Register a listener for a specific feature flag
     * @param key The feature flag key
     * @param listener Callback function invoked whenever the flag value changes
     */
    fun <T : Any> addConfigListener(key: String, listener: (T) -> Unit) {
        @Suppress("UNCHECKED_CAST")
        configListeners.getOrPut(key) { mutableListOf() }.add(listener as (Any) -> Unit)
        logger.debug { "Added listener for key: $key" }
    }
    
    /**
     * Remove a listener for a specific feature flag
     * @param key The feature flag key
     * @param listener The listener to remove
     */
    fun <T : Any> removeConfigListener(key: String, listener: (T) -> Unit) {
        @Suppress("UNCHECKED_CAST")
        configListeners[key]?.remove(listener as (Any) -> Unit)
        logger.debug { "Removed listener for key: $key" }
    }
    
    /**
     * Remove all listeners for a specific feature flag
     * @param key The feature flag key
     */
    fun clearConfigListeners(key: String) {
        configListeners.remove(key)
        logger.debug { "Cleared all listeners for key: $key" }
    }

    init {
        logger.info { "CFClient initialized with config: $cfConfig and user: $user" }
        initializeSdkSettings()
        startPeriodicSdkSettingsCheck()
    }

    private fun initializeSdkSettings() {
        runBlocking(Dispatchers.IO) {
            try {
                logger.info { "Initializing SDK settings" }
                checkSdkSettings()
                sdkSettingsDeferred.complete(Unit)
                logger.info { "SDK settings initialized successfully" }
            } catch (e: Exception) {
                logger.error(e) { "Failed to initialize SDK settings: ${e.message}" }
                sdkSettingsDeferred.completeExceptionally(e)
            }
        }
    }

    suspend fun awaitSdkSettingsCheck() = sdkSettingsDeferred.await()

    fun getString(key: String, fallbackValue: String): String =
            getConfigValue(key, fallbackValue) { it is String }
            
    fun getString(key: String, fallbackValue: String, callback: ((String) -> Unit)? = null): String {
        val value = getString(key, fallbackValue)
        callback?.invoke(value)
        return value
    }
    
    fun getNumber(key: String, fallbackValue: Number): Number =
            getConfigValue(key, fallbackValue) { it is Number }
            
    fun getNumber(key: String, fallbackValue: Number, callback: ((Number) -> Unit)? = null): Number {
        val value = getNumber(key, fallbackValue)
        callback?.invoke(value)
        return value
    }
    
    fun getBoolean(key: String, fallbackValue: Boolean): Boolean =
            getConfigValue(key, fallbackValue) { it is Boolean }
            
    fun getBoolean(key: String, fallbackValue: Boolean, callback: ((Boolean) -> Unit)? = null): Boolean {
        val value = getBoolean(key, fallbackValue) 
        callback?.invoke(value)
        return value
    }
    
    fun getJson(key: String, fallbackValue: Map<String, Any>): Map<String, Any> =
            getConfigValue(key, fallbackValue) {
                it is Map<*, *> && it.keys.all { k -> k is String }
            }
            
    fun getJson(key: String, fallbackValue: Map<String, Any>, callback: ((Map<String, Any>) -> Unit)? = null): Map<String, Any> {
        val value = getJson(key, fallbackValue)
        callback?.invoke(value)
        return value
    }

    fun trackEvent(eventName: String, properties: Map<String, Any> = emptyMap()) {
        eventTracker.trackEvent(eventName, properties)
    }

    fun trackEvent(eventName: String, propertiesBuilder: EventPropertiesBuilder.() -> Unit) {
        val properties = EventPropertiesBuilder().apply(propertiesBuilder).build()
        eventTracker.trackEvent(eventName, properties)
    }

    // Add a single property to the user
    fun addUserProperty(key: String, value: Any) {
        user.addProperty(key, value)
        logger.debug { "Added user property: $key = $value" }
    }
    
    // Type-specific property methods
    fun addStringProperty(key: String, value: String) {
        require(value.isNotBlank()) { "String value for '$key' cannot be blank" }
        addUserProperty(key, value)
    }
    
    fun addNumberProperty(key: String, value: Number) {
        addUserProperty(key, value)
    }
    
    fun addBooleanProperty(key: String, value: Boolean) {
        addUserProperty(key, value)
    }
    
    fun addDateProperty(key: String, value: Date) {
        addUserProperty(key, value)
    }
    
    fun addGeoPointProperty(key: String, lat: Double, lon: Double) {
        addUserProperty(key, mapOf("lat" to lat, "lon" to lon))
    }
    
    fun addJsonProperty(key: String, value: Map<String, Any>) {
        require(value.keys.all { it is String }) { "JSON for '$key' must have String keys" }
        val jsonCompatible = value.filterValues { isJsonCompatible(it) }
        addUserProperty(key, jsonCompatible)
    }
    
    private fun isJsonCompatible(value: Any?): Boolean =
        when (value) {
            null -> true
            is String, is Number, is Boolean -> true
            is Map<*, *> -> value.keys.all { it is String } && value.values.all { isJsonCompatible(it) }
            is Collection<*> -> value.all { isJsonCompatible(it) }
            else -> false
        }
    
    // Add multiple properties to the user at once
    fun addUserProperties(properties: Map<String, Any>) {
        user.addProperties(properties)
        logger.debug { "Added ${properties.size} user properties" }
    }
    
    // Get the current user properties including any updates
    fun getUserProperties(): Map<String, Any> = user.getCurrentProperties()

    private fun startPeriodicSdkSettingsCheck() {
        fixedRateTimer("SdkSettingsCheck", daemon = true, period = cfConfig.sdkSettingsCheckIntervalMs) {
            CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                logger.debug { "Periodic SDK settings check triggered" }
                checkSdkSettings()
            }
        }
    }

    private suspend fun checkSdkSettings() {
        try {
            val metadata =
                    fetchSdkSettingsMetadata()
                            ?: run {
                                logger.warn { "Failed to fetch SDK settings metadata" }
                                return
                            }
            val currentLastModified = metadata["Last-Modified"] ?: return
            if (currentLastModified != previousLastModified) {
                logger.info { "SDK settings changed: Previous=$previousLastModified, Current=$currentLastModified" }
                val newConfigs = fetchConfigs() ?: emptyMap()
                
                // Keep track of updated keys to notify listeners
                val updatedKeys = mutableSetOf<String>()
                
                configMutex.withLock {
                    // Find keys that have changed
                    newConfigs.keys.forEach { key ->
                        if (!configMap.containsKey(key) || configMap[key] != newConfigs[key]) {
                            updatedKeys.add(key)
                        }
                    }
                    
                    // Update the config map
                    configMap.clear()
                    configMap.putAll(newConfigs)
                    previousLastModified = currentLastModified
                }
                
                // Notify listeners for each changed key
                updatedKeys.forEach { key ->
                    val config = configMap[key] as? Map<*, *>
                    val variation = config?.get("variation")
                    if (variation != null) {
                        notifyListeners(key, variation)
                    }
                }
                
                logger.info { "Configs updated successfully with ${newConfigs.size} entries" }
            } else {
                logger.debug { "No change in SDK settings" }
            }
        } catch (e: Exception) {
            logger.error(e) { "Error checking SDK settings: ${e.message}" }
        }
    }

    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? =
            httpClient.fetchMetadata(
                            "https://sdk.customfit.ai/${cfConfig.dimensionId}/cf-sdk-settings.json"
                    )
                    ?.also { logger.debug { "Fetched metadata: $it" } }

    private suspend fun fetchSdkSettings(): SdkSettings? {
        val json =
                httpClient.fetchJson(
                        "https://sdk.customfit.ai/${cfConfig.dimensionId}/cf-sdk-settings.json"
                )
                        ?: run {
                            logger.warn { "Failed to fetch SDK settings JSON" }
                            return null
                        }

        return try {
            val settings = SdkSettings.fromJson(json)
            if (settings == null) {
                logger.warn { "SdkSettings.fromJson returned null for JSON: $json" }
                return null
            }
            if (!settings.cf_account_enabled || settings.cf_skip_sdk) {
                logger.debug { "SDK settings skipped: cf_account_enabled=${settings.cf_account_enabled}, cf_skip_sdk=${settings.cf_skip_sdk}" }
                null
            } else {
                logger.debug { "Fetched SDK settings: $settings" }
                settings
            }
        } catch (e: Exception) {
            logger.error(e) { "Error parsing SDK settings: ${e.message}" }
            null
        }
    }

    private suspend fun fetchConfigs(): Map<String, Any>? {
        val url = "https://api.customfit.ai/v1/users/configs?cfenc=${cfConfig.clientKey}"
        val payload =
                try {
                    JSONObject()
                            .apply {
                                put("user", JSONObject(user.toMap()))
                                put("include_only_features_flags", true)
                            }
                            .toString()
                } catch (e: Exception) {
                    logger.error(e) { "Error creating config payload: ${e.message}" }
                    return null
                }

        val json =
                httpClient.performRequest(
                        url,
                        "POST",
                        mapOf("Content-Type" to "application/json"),
                        payload
                ) { conn ->
                    when (conn.responseCode) {
                        HttpURLConnection.HTTP_OK ->
                                JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
                        else -> {
                            logger.warn { "Config fetch failed with code: ${conn.responseCode}" }
                            null
                        }
                    }
                }
                        ?: return null

        val configs =
                json.optJSONObject("configs")
                        ?: run {
                            logger.warn { "No 'configs' object in response" }
                            return null
                        }
        val newConfigMap = mutableMapOf<String, Any>()

        configs.keys().forEach { key ->
            try {
                val config = configs.getJSONObject(key)
                val experience =
                        config.optJSONObject("experience_behaviour_response")
                                ?: run {
                                    logger.warn { "Missing 'experience_behaviour_response' for key: $key" }
                                    return@forEach
                                }

                val experienceKey =
                        experience.optString("experience", null)
                                ?: run {
                                    logger.warn { "Missing 'experience' field for key: $key" }
                                    return@forEach
                                }
                val variationDataType = config.optString("variation_data_type", "UNKNOWN")
                val variation: Any =
                        when (variationDataType.uppercase()) {
                            "STRING" -> config.optString("variation", "")
                            "BOOLEAN" -> config.optBoolean("variation", false)
                            "NUMBER" -> config.optDouble("variation", 0.0)
                            "JSON" -> config.optJSONObject("variation")?.toMap()
                                            ?: emptyMap<String, Any>()
                            else ->
                                    config.opt("variation")?.also {
                                        logger.warn { "Unknown variation type: $variationDataType for $key" }
                                    }
                                            ?: ""
                        }

                val experienceData =
                        mapOf(
                                "version" to config.optNumber("version"),
                                "config_id" to config.optString("config_id", null),
                                "user_id" to json.optString("user_id", null),
                                "experience_id" to experience.optString("experience_id", null),
                                "behaviour" to experience.optString("behaviour", null),
                                "behaviour_id" to experience.optString("behaviour_id", null),
                                "variation_name" to experience.optString("behaviour", null),
                                "variation_id" to experience.optString("variation_id", null),
                                "priority" to experience.optInt("priority", 0),
                                "experience_created_time" to
                                        experience.optLong("experience_created_time", 0L),
                                "rule_id" to experience.optString("rule_id", null),
                                "experience" to experienceKey,
                                "audience_name" to experience.optString("audience_name", null),
                                "ga_measurement_id" to
                                        experience.optString("ga_measurement_id", null),
                                "type" to experience.optString("type", null),
                                "config_modifications" to
                                        experience.optString("config_modifications", null),
                                "variation_data_type" to variationDataType,
                                "variation" to variation
                        )

                newConfigMap[experienceKey] = experienceData
            } catch (e: Exception) {
                logger.error(e) { "Error processing config key '$key': ${e.message}" }
            }
        }

        return newConfigMap
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        val config = configMap[key]
        if (config == null) {
            logger.warn { "No config found for key '$key'" }
            return fallbackValue
        }
        if (config !is Map<*, *>) {
            logger.warn { "Config for '$key' is not a map: $config" }
            return fallbackValue
        }
        val variation = config["variation"]
        val result =
                if (variation != null && typeCheck(variation)) {
                    try {
                        variation as T
                    } catch (e: ClassCastException) {
                        logger.warn { "Type mismatch for '$key': expected ${fallbackValue!!::class.simpleName}, got ${variation::class.simpleName}" }
                        fallbackValue
                    }
                } else {
                    logger.warn { "No valid variation for '$key': $variation" }
                    fallbackValue
                }
        summaryManager.pushSummary(config as Map<String, Any>)
        return result
    }

    private fun CFUser.toMap(): Map<String, Any?> =
            mapOf(
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

    private fun notifyListeners(key: String, variation: Any) {
        val listeners = configListeners[key]
        if (listeners != null) {
            for (listener in listeners) {
                listener(variation)
            }
        }
    }

    companion object {
        fun init(cfConfig: CFConfig, user: CFUser): CFClient = CFClient(cfConfig, user)
    }
}
