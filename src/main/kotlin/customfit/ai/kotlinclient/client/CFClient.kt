package customfit.ai.kotlinclient.client

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import customfit.ai.kotlinclient.core.ContextType
import customfit.ai.kotlinclient.core.DeviceContext
import customfit.ai.kotlinclient.core.EvaluationContext
import customfit.ai.kotlinclient.core.MutableCFConfig
import customfit.ai.kotlinclient.core.SdkSettings
import customfit.ai.kotlinclient.events.EventPropertiesBuilder
import customfit.ai.kotlinclient.events.EventTracker
import customfit.ai.kotlinclient.network.ConfigFetcher
import customfit.ai.kotlinclient.network.ConnectionInformation
import customfit.ai.kotlinclient.network.ConnectionManager
import customfit.ai.kotlinclient.network.ConnectionStatus
import customfit.ai.kotlinclient.network.ConnectionStatusListener
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.summaries.SummaryManager
import java.net.HttpURLConnection
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import mu.KotlinLogging
import org.json.JSONObject
import org.joda.time.DateTime

private val logger = KotlinLogging.logger {}

class CFClient private constructor(cfConfig: CFConfig, private val user: CFUser) {
    private val sessionId: String = UUID.randomUUID().toString()
    private val mutableConfig = MutableCFConfig(cfConfig)
    private val httpClient = HttpClient(cfConfig)
    val summaryManager = SummaryManager(sessionId, httpClient, user, cfConfig)
    val eventTracker = EventTracker(sessionId, httpClient, user, summaryManager, cfConfig)
    val configFetcher = ConfigFetcher(httpClient, cfConfig, user)
    
    // Connection and background state management
    private val connectionManager = ConnectionManager(cfConfig) { 
        CoroutineScope(Dispatchers.IO).launch { 
            checkSdkSettings() 
        }
    }
    private val backgroundStateMonitor = DefaultBackgroundStateMonitor()
    private val connectionStatusListeners = CopyOnWriteArrayList<ConnectionStatusListener>()

    // Device context for context-aware evaluation
    private var deviceContext = DeviceContext.createBasic()
    private val contexts = ConcurrentHashMap<String, EvaluationContext>()

    @Volatile private var previousLastModified: String? = null
    private val configMap: MutableMap<String, Any> =
            Collections.synchronizedMap(mutableMapOf()) // Thread-safe
    private val configMutex = Mutex() // For atomic updates
    private val sdkSettingsDeferred: CompletableDeferred<Unit> = CompletableDeferred()

    // Timer for SDK settings check
    private var sdkSettingsTimer: Timer? = null
    private val timerMutex = Mutex()

    // Add listener methods for continuous updates
    private val configListeners = ConcurrentHashMap<String, MutableList<(Any) -> Unit>>()
    private val featureFlagListeners = ConcurrentHashMap<String, MutableList<FeatureFlagChangeListener>>()
    private val allFlagsListeners = ConcurrentHashMap.newKeySet<AllFlagsListener>()
    
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

    // Listen for config changes to update components
    init {
        // Set initial offline mode from the config
        if (mutableConfig.offlineMode) {
            configFetcher.setOffline(true)
            connectionManager.setOfflineMode(true)
            logger.info { "CF client initialized in offline mode" }
        }
        
        // Initialize device context if it's not already set
        if (user.device == null) {
            deviceContext = DeviceContext.createBasic()
            // Update user with device context
            updateUserWithDeviceContext()
        } else {
            // Use the device context from the user if available
            deviceContext = user.device
        }
        
        // Set up connection status monitoring
        setupConnectionStatusMonitoring()
        
        // Set up background state monitoring
        setupBackgroundStateMonitoring()
        
        // Add user context from the main user object
        addMainUserContext()
        
        // Set up config change listener
        mutableConfig.addConfigChangeListener(object : MutableCFConfig.ConfigChangeListener {
            override fun onConfigChanged(oldConfig: CFConfig, newConfig: CFConfig) {
                handleConfigChange(oldConfig, newConfig)
            }
        })
        
        // Start periodic SDK settings check
        startPeriodicSdkSettingsCheck()
        
        // Initial fetch of SDK settings
        CoroutineScope(Dispatchers.IO).launch {
            try {
                checkSdkSettings()
                sdkSettingsDeferred.complete(Unit)
            } catch (e: Exception) {
                logger.error(e) { "Error in initial SDK settings check: ${e.message}" }
                sdkSettingsDeferred.complete(Unit) // Complete anyway to avoid blocking
            }
        }
    }

    /**
     * Set up connection status monitoring
     */
    private fun setupConnectionStatusMonitoring() {
        connectionManager.addConnectionStatusListener(object : ConnectionStatusListener {
            override fun onConnectionStatusChanged(newStatus: ConnectionStatus, info: ConnectionInformation) {
                logger.debug { "Connection status changed: $newStatus" }
                
                // Notify all listeners
                for (listener in connectionStatusListeners) {
                    try {
                        listener.onConnectionStatusChanged(newStatus, info)
                    } catch (e: Exception) {
                        logger.error(e) { "Error notifying connection status listener: ${e.message}" }
                    }
                }
                
                // If we're connected and we were previously disconnected, try to sync
                if (newStatus == ConnectionStatus.CONNECTED && 
                    (info.lastSuccessfulConnectionTimeMs == 0L || 
                     System.currentTimeMillis() - info.lastSuccessfulConnectionTimeMs > 60000)) {
                    CoroutineScope(Dispatchers.IO).launch {
                        checkSdkSettings()
                    }
                }
            }
        })
    }
    
    /**
     * Set up background state monitoring
     */
    private fun setupBackgroundStateMonitoring() {
        backgroundStateMonitor.addAppStateListener(object : AppStateListener {
            override fun onAppStateChange(state: AppState) {
                logger.debug { "App state changed: $state" }
                
                if (state == AppState.BACKGROUND && mutableConfig.disableBackgroundPolling) {
                    // Pause polling in background if configured to do so
                    pausePolling()
                } else if (state == AppState.FOREGROUND) {
                    // Resume polling when app comes to foreground
                    resumePolling()
                    
                    // Check for updates immediately when coming to foreground
                    CoroutineScope(Dispatchers.IO).launch {
                        checkSdkSettings()
                    }
                }
            }
        })
        
        backgroundStateMonitor.addBatteryStateListener(object : BatteryStateListener {
            override fun onBatteryStateChange(state: BatteryState) {
                logger.debug { "Battery state changed: low=${state.isLow}, charging=${state.isCharging}, level=${state.level}" }
                
                if (mutableConfig.useReducedPollingWhenBatteryLow && state.isLow && !state.isCharging) {
                    // Use reduced polling on low battery
                    adjustPollingForBatteryState(true)
                } else {
                    // Use normal polling
                    adjustPollingForBatteryState(false)
                }
            }
        })
    }
    
    /**
     * Add the main user to the contexts collection
     */
    private fun addMainUserContext() {
        // Create a user context from the main user object
        val userContext = EvaluationContext(
            type = ContextType.USER,
            key = user.user_customer_id ?: UUID.randomUUID().toString(),
            properties = user.properties
        )
        contexts["user"] = userContext
        
        // Add user context to user properties
        user.addContext(userContext)
        
        // Add device context to user properties
        updateUserWithDeviceContext()
    }

    /**
     * Handle configuration changes and update components as needed
     */
    private fun handleConfigChange(oldConfig: CFConfig, newConfig: CFConfig) {
        logger.debug { "Config changed: $oldConfig -> $newConfig" }
        
        // Check for offline mode change
        if (oldConfig.offlineMode != newConfig.offlineMode) {
            configFetcher.setOffline(newConfig.offlineMode)
            connectionManager.setOfflineMode(newConfig.offlineMode)
            logger.info { "Updated offline mode to: ${newConfig.offlineMode}" }
        }
        
        // Check for SDK settings check interval change
        if (oldConfig.sdkSettingsCheckIntervalMs != newConfig.sdkSettingsCheckIntervalMs) {
            CoroutineScope(Dispatchers.IO).launch {
                restartPeriodicSdkSettingsCheck()
            }
            logger.info { "Updated SDK settings check interval to ${newConfig.sdkSettingsCheckIntervalMs} ms" }
        }
        
        // Check for network timeout changes - would require HttpClient to expose update methods
        if (oldConfig.networkConnectionTimeoutMs != newConfig.networkConnectionTimeoutMs ||
            oldConfig.networkReadTimeoutMs != newConfig.networkReadTimeoutMs) {
            httpClient.updateConnectionTimeout(newConfig.networkConnectionTimeoutMs)
            httpClient.updateReadTimeout(newConfig.networkReadTimeoutMs)
            logger.info { "Updated network timeout settings" }
        }
        
        // Check for background polling changes
        if (oldConfig.disableBackgroundPolling != newConfig.disableBackgroundPolling ||
            oldConfig.backgroundPollingIntervalMs != newConfig.backgroundPollingIntervalMs ||
            oldConfig.reducedPollingIntervalMs != newConfig.reducedPollingIntervalMs) {
            logger.info { "Updated background polling settings" }
            
            if (backgroundStateMonitor.getCurrentAppState() == AppState.BACKGROUND && 
                newConfig.disableBackgroundPolling) {
                pausePolling()
            } else {
                resumePolling()
                
                // Adjust for battery state
                val batteryState = backgroundStateMonitor.getCurrentBatteryState()
                if (newConfig.useReducedPollingWhenBatteryLow && batteryState.isLow && !batteryState.isCharging) {
                    adjustPollingForBatteryState(true)
                }
            }
        }
    }
    
    /**
     * Pause polling when in background if configured
     */
    private fun pausePolling() {
        if (mutableConfig.disableBackgroundPolling) {
            logger.debug { "Pausing polling in background" }
            CoroutineScope(Dispatchers.IO).launch {
                timerMutex.withLock {
                    sdkSettingsTimer?.cancel()
                    sdkSettingsTimer = null
                }
            }
        }
    }
    
    /**
     * Resume polling when returning to foreground
     */
    private fun resumePolling() {
        logger.debug { "Resuming polling" }
        CoroutineScope(Dispatchers.IO).launch {
            restartPeriodicSdkSettingsCheck()
        }
    }
    
    /**
     * Adjust polling intervals based on battery state
     */
    private fun adjustPollingForBatteryState(useLowBatteryInterval: Boolean) {
        if (backgroundStateMonitor.getCurrentAppState() == AppState.BACKGROUND) {
            CoroutineScope(Dispatchers.IO).launch {
                val interval = if (useLowBatteryInterval) {
                    mutableConfig.reducedPollingIntervalMs
                } else {
                    mutableConfig.backgroundPollingIntervalMs
                }
                
                logger.debug { "Adjusting background polling interval to $interval ms due to battery state" }
                
                restartPeriodicSdkSettingsCheck(interval)
            }
        }
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

    /**
     * Returns whether the client is in offline mode
     * 
     * @return true if the client is in offline mode
     */
    fun isOffline(): Boolean = configFetcher.isOffline()
    
    /**
     * Puts the client in offline mode, preventing network requests.
     * This method is thread-safe.
     */
    fun setOffline() {
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setOfflineMode(true)
        }
        // Direct update for immediate effect
        configFetcher.setOffline(true)
        connectionManager.setOfflineMode(true)
        logger.info { "CF client is now in offline mode" }
    }
    
    /**
     * Restores the client to online mode, allowing network requests.
     * This method is thread-safe.
     */
    fun setOnline() {
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setOfflineMode(false)
        }
        // Direct update for immediate effect
        configFetcher.setOffline(false)
        connectionManager.setOfflineMode(false)
        logger.info { "CF client is now in online mode" }
    }

    /**
     * Updates the SDK settings check interval. This will restart the timer with the new interval.
     * 
     * @param intervalMs the new interval in milliseconds
     */
    fun updateSdkSettingsCheckInterval(intervalMs: Long) {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setSdkSettingsCheckIntervalMs(intervalMs)
        }
    }
    
    /**
     * Updates the events flush interval.
     * 
     * @param intervalMs the new interval in milliseconds
     */
    fun updateEventsFlushInterval(intervalMs: Long) {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setEventsFlushIntervalMs(intervalMs)
        }
    }
    
    /**
     * Updates the summaries flush interval.
     * 
     * @param intervalMs the new interval in milliseconds
     */
    fun updateSummariesFlushInterval(intervalMs: Long) {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setSummariesFlushIntervalMs(intervalMs)
        }
    }
    
    /**
     * Updates the network connection timeout.
     * 
     * @param timeoutMs the new timeout in milliseconds
     */
    fun updateNetworkConnectionTimeout(timeoutMs: Int) {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setNetworkConnectionTimeoutMs(timeoutMs)
        }
    }
    
    /**
     * Updates the network read timeout.
     * 
     * @param timeoutMs the new timeout in milliseconds
     */
    fun updateNetworkReadTimeout(timeoutMs: Int) {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setNetworkReadTimeoutMs(timeoutMs)
        }
    }
    
    /**
     * Updates the debug logging setting.
     * 
     * @param enabled true to enable debug logging, false to disable
     */
    fun setDebugLoggingEnabled(enabled: Boolean) {
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setDebugLoggingEnabled(enabled)
        }
    }

    private fun startPeriodicSdkSettingsCheck() {
        startPeriodicSdkSettingsCheck(mutableConfig.sdkSettingsCheckIntervalMs)
    }
    
    private fun startPeriodicSdkSettingsCheck(intervalMs: Long) {
        CoroutineScope(Dispatchers.IO).launch {
            timerMutex.withLock {
                // Cancel existing timer if any
                sdkSettingsTimer?.cancel()
                
                // Create a new timer
                sdkSettingsTimer = fixedRateTimer("SdkSettingsCheck", daemon = true, 
                        period = intervalMs) {
                    CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                        logger.debug { "Periodic SDK settings check triggered" }
                        checkSdkSettings()
                    }
                }
                
                logger.debug { "Started SDK settings check timer with interval $intervalMs ms" }
            }
        }
    }
    
    private suspend fun restartPeriodicSdkSettingsCheck() {
        restartPeriodicSdkSettingsCheck(mutableConfig.sdkSettingsCheckIntervalMs)
    }
    
    private suspend fun restartPeriodicSdkSettingsCheck(intervalMs: Long) {
        timerMutex.withLock {
            // Cancel existing timer if any
            sdkSettingsTimer?.cancel()
            
            // Create a new timer with updated interval
            sdkSettingsTimer = fixedRateTimer("SdkSettingsCheck", daemon = true, 
                    period = intervalMs) {
                CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                    logger.debug { "Periodic SDK settings check triggered" }
                    checkSdkSettings()
                }
            }
            logger.debug { "Restarted periodic SDK settings check with interval $intervalMs ms" }
        }
    }

    private suspend fun checkSdkSettings() {
        try {
            val metadata =
                    configFetcher.fetchMetadata("https://sdk.customfit.ai/${mutableConfig.dimensionId}/cf-sdk-settings.json")
                            ?: run {
                                logger.warn { "Failed to fetch SDK settings metadata" }
                                return
                            }
            val currentLastModified = metadata["Last-Modified"] ?: return
            
            if (currentLastModified != previousLastModified) {
                logger.info { "SDK settings changed: Previous=$previousLastModified, Current=$currentLastModified" }
                val configResult = configFetcher.fetchConfig(currentLastModified)
                if (configResult == null) {
                    logger.warn { "Failed to fetch config with last-modified: $currentLastModified" }
                    return
                }
                
                val newConfigs = configResult.first
                
                // Keep track of updated keys to notify listeners
                val updatedKeys = mutableSetOf<String>()
                
                configMutex.withLock {
                    // Find keys that have changed
                    for (key in newConfigs.keys) {
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
                for (key in updatedKeys) {
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
            configFetcher.fetchMetadata("https://sdk.customfit.ai/${mutableConfig.dimensionId}/cf-sdk-settings.json")

    private suspend fun fetchSdkSettings(): SdkSettings? {
        val json =
                httpClient.fetchJson(
                        "https://sdk.customfit.ai/${mutableConfig.dimensionId}/cf-sdk-settings.json"
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
        val url = "https://api.customfit.ai/v1/users/configs?cfenc=${mutableConfig.clientKey}"
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
        // Notify value listeners
        val listeners = configListeners[key]
        if (listeners != null) {
            for (listener in listeners) {
                listener(variation)
            }
        }
        
        // Notify feature flag listeners
        val flagListeners = featureFlagListeners[key]
        if (flagListeners != null) {
            for (listener in flagListeners) {
                try {
                    listener.onFeatureFlagChange(key, variation)
                } catch (e: Exception) {
                    logger.error(e) { "Error notifying feature flag listener: ${e.message}" }
                }
            }
        }
        
        // Notify all flags listeners
        if (allFlagsListeners.isNotEmpty()) {
            val allFlags = getAllFlags()
            for (listener in allFlagsListeners) {
                try {
                    listener.onFlagsChange(allFlags)
                } catch (e: Exception) {
                    logger.error(e) { "Error notifying all flags listener: ${e.message}" }
                }
            }
        }
    }
    
    /**
     * Returns a map of all feature flags with their current values
     */
    fun getAllFlags(): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        configMap.forEach { (key, configData) ->
            val data = configData as? Map<*, *>
            val variation = data?.get("variation")
            if (variation != null) {
                result[key] = variation
            }
        }
        return result
    }
    
    /**
     * Registers a listener to be notified when the specified feature flag's value changes
     *
     * @param flagKey the flag to listen for
     * @param listener the listener to register
     */
    fun registerFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        featureFlagListeners.computeIfAbsent(flagKey) { mutableListOf() }.add(listener)
        logger.debug { "Registered feature flag listener for key: $flagKey" }
    }
    
    /**
     * Unregisters a previously registered feature flag listener
     *
     * @param flagKey the flag being listened to
     * @param listener the listener to unregister
     */
    fun unregisterFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        featureFlagListeners[flagKey]?.remove(listener)
        logger.debug { "Unregistered feature flag listener for key: $flagKey" }
    }
    
    /**
     * Registers a listener to be notified when any feature flag changes
     *
     * @param listener the listener to register
     */
    fun registerAllFlagsListener(listener: AllFlagsListener) {
        allFlagsListeners.add(listener)
        logger.debug { "Registered all flags listener" }
    }
    
    /**
     * Unregisters a previously registered all flags listener
     *
     * @param listener the listener to unregister
     */
    fun unregisterAllFlagsListener(listener: AllFlagsListener) {
        allFlagsListeners.remove(listener)
        logger.debug { "Unregistered all flags listener" }
    }

    /**
     * Gets the current connection information
     */
    fun getConnectionInformation(): ConnectionInformation {
        return connectionManager.getConnectionInformation()
    }
    
    /**
     * Registers a connection status listener
     * 
     * @param listener the listener to register
     */
    fun addConnectionStatusListener(listener: ConnectionStatusListener) {
        connectionStatusListeners.add(listener)
        // Notify immediately with current state
        val info = connectionManager.getConnectionInformation()
        listener.onConnectionStatusChanged(info.status, info)
    }
    
    /**
     * Unregisters a connection status listener
     * 
     * @param listener the listener to unregister
     */
    fun removeConnectionStatusListener(listener: ConnectionStatusListener) {
        connectionStatusListeners.remove(listener)
    }
    
    /**
     * Sets the device context for context-aware evaluation
     * 
     * @param deviceContext the device context
     */
    fun setDeviceContext(deviceContext: DeviceContext) {
        this.deviceContext = deviceContext
        // Update user properties with the new device context
        updateUserWithDeviceContext()
        logger.debug { "Device context updated: $deviceContext" }
    }
    
    /**
     * Updates user properties with the current device context as a sub-JSON
     * under the key 'mobile_device_context'
     */
    private fun updateUserWithDeviceContext() {
        val deviceContextMap = deviceContext.toMap()
        // Only add non-empty device context
        if (deviceContextMap.isNotEmpty()) {
            user.addProperty("mobile_device_context", deviceContextMap)
            logger.debug { "Updated user properties with mobile_device_context" }
        }
    }
    
    /**
     * Adds an evaluation context for more targeted evaluation
     * 
     * @param context the evaluation context to add
     */
    fun addContext(context: EvaluationContext) {
        contexts[context.type.name.lowercase() + ":" + context.key] = context
        // Also add to user properties
        user.addContext(context)
        logger.debug { "Added evaluation context: ${context.type}:${context.key}" }
    }
    
    /**
     * Removes an evaluation context
     * 
     * @param type the context type
     * @param key the context key
     */
    fun removeContext(type: ContextType, key: String) {
        val contextKey = type.name.lowercase() + ":" + key
        contexts.remove(contextKey)
        // Update the contexts in user properties
        // This requires re-adding all contexts except the one being removed
        val userContexts = user.getContexts().filter { 
            !(it.type == type && it.key == key) 
        }
        val contextsList = mutableListOf<Map<String, Any?>>()
        userContexts.forEach { contextsList.add(it.toMap()) }
        user.addProperty("contexts", contextsList)
        
        logger.debug { "Removed evaluation context: $type:$key" }
    }
    
    /**
     * Gets all current evaluation contexts
     */
    fun getContexts(): List<EvaluationContext> = contexts.values.toList()

    /**
     * Clean up resources when the client is no longer needed
     */
    fun shutdown() {
        logger.info { "Shutting down CF client" }
        
        // Cancel timers
        sdkSettingsTimer?.cancel()
        
        // Shutdown connection manager
        connectionManager.shutdown()
        
        // Shutdown background monitor
        backgroundStateMonitor.shutdown()
        
        // Clear listeners
        configListeners.clear()
        featureFlagListeners.clear()
        allFlagsListeners.clear()
        connectionStatusListeners.clear()
        
        // Flush any pending events and summaries
        CoroutineScope(Dispatchers.IO).launch {
            try {
                eventTracker.flushEvents()
                summaryManager.flushSummaries()
            } catch (e: Exception) {
                logger.error(e) { "Error flushing events during shutdown: ${e.message}" }
            }
        }
    }

    companion object {
        fun init(cfConfig: CFConfig, user: CFUser): CFClient = CFClient(cfConfig, user)
    }
}
