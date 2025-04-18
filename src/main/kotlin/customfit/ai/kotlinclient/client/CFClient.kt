package customfit.ai.kotlinclient.client

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import customfit.ai.kotlinclient.core.ContextType
import customfit.ai.kotlinclient.core.DeviceContext
import customfit.ai.kotlinclient.core.EvaluationContext
import customfit.ai.kotlinclient.core.MutableCFConfig
import customfit.ai.kotlinclient.core.SdkSettings
import customfit.ai.kotlinclient.core.ApplicationInfo
import customfit.ai.kotlinclient.events.EventPropertiesBuilder
import customfit.ai.kotlinclient.events.EventTracker
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.network.ConfigFetcher
import customfit.ai.kotlinclient.network.ConnectionInformation
import customfit.ai.kotlinclient.network.ConnectionManager
import customfit.ai.kotlinclient.network.ConnectionStatus
import customfit.ai.kotlinclient.network.ConnectionStatusListener
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.summaries.SummaryManager
import customfit.ai.kotlinclient.utils.ApplicationInfoDetector
import java.net.HttpURLConnection
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.*
import kotlinx.serialization.encodeToString

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
    
    // Application info
    private var applicationInfo: ApplicationInfo? = null
    
    /**
     * Register a listener for a specific feature flag
     * @param key The feature flag key
     * @param listener Callback function invoked whenever the flag value changes
     */
    fun <T : Any> addConfigListener(key: String, listener: (T) -> Unit) {
        @Suppress("UNCHECKED_CAST")
        configListeners.getOrPut(key) { mutableListOf() }.add(listener as (Any) -> Unit)
        Timber.d("Added listener for key: $key")
    }
    
    /**
     * Remove a listener for a specific feature flag
     * @param key The feature flag key
     * @param listener The listener to remove
     */
    fun <T : Any> removeConfigListener(key: String, listener: (T) -> Unit) {
        @Suppress("UNCHECKED_CAST")
        configListeners[key]?.remove(listener as (Any) -> Unit)
        Timber.d("Removed listener for key: $key")
    }
    
    /**
     * Remove all listeners for a specific feature flag
     * @param key The feature flag key
     */
    fun clearConfigListeners(key: String) {
        configListeners.remove(key)
        Timber.d("Cleared all listeners for key: $key")
    }

    // Listen for config changes to update components
    init {
        // Set initial offline mode from the config
        if (mutableConfig.offlineMode) {
            configFetcher.setOffline(true)
            connectionManager.setOfflineMode(true)
            Timber.i("CF client initialized in offline mode")
        }
        
        // Initialize environment attributes based on config
        if (mutableConfig.autoEnvAttributesEnabled) {
            Timber.d("Auto environment attributes enabled, detecting device and application info")
            
            // Initialize device context if it's not already set
            val existingDeviceContext = user.getDeviceContext()
            if (existingDeviceContext == null) {
                deviceContext = DeviceContext.createBasic()
                // Update user with device context
                updateUserWithDeviceContext()
            } else {
                // Use the device context from the user if available
                deviceContext = existingDeviceContext
            }
            
            // Get application info from user if available, otherwise detect it
            val existingAppInfo = user.getApplicationInfo()
            if (existingAppInfo != null) {
                applicationInfo = existingAppInfo
                // Increment launch count
                val updatedAppInfo = existingAppInfo.copy(launchCount = existingAppInfo.launchCount + 1)
                updateUserWithApplicationInfo(updatedAppInfo)
            } else {
                // Try to auto-detect application info
                val detectedAppInfo = ApplicationInfoDetector.detectApplicationInfo()
                if (detectedAppInfo != null) {
                    updateUserWithApplicationInfo(detectedAppInfo)
                    Timber.d("Auto-detected application info: $detectedAppInfo")
                }
            }
        } else {
            Timber.d("Auto environment attributes disabled, skipping device and application info detection")
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
                Timber.e(e) { "Error in initial SDK settings check: ${e.message}" }
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
                Timber.d("Connection status changed: $newStatus")
                
                // Notify all listeners
                for (listener in connectionStatusListeners) {
                    try {
                        listener.onConnectionStatusChanged(newStatus, info)
                    } catch (e: Exception) {
                        Timber.e(e) { "Error notifying connection status listener: ${e.message}" }
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
                Timber.d("App state changed: $state")
                
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
                Timber.d("Battery state changed: low=${state.isLow}, charging=${state.isCharging}, level=${state.level}")
                
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
        Timber.d("Config changed: $oldConfig -> $newConfig")
        
        // Check for offline mode change
        if (oldConfig.offlineMode != newConfig.offlineMode) {
            configFetcher.setOffline(newConfig.offlineMode)
            connectionManager.setOfflineMode(newConfig.offlineMode)
            Timber.i("Updated offline mode to: ${newConfig.offlineMode}")
        }
        
        // Check for SDK settings check interval change
        if (oldConfig.sdkSettingsCheckIntervalMs != newConfig.sdkSettingsCheckIntervalMs) {
            CoroutineScope(Dispatchers.IO).launch {
                restartPeriodicSdkSettingsCheck()
            }
            Timber.i("Updated SDK settings check interval to ${newConfig.sdkSettingsCheckIntervalMs} ms")
        }
        
        // Check for network timeout changes - would require HttpClient to expose update methods
        if (oldConfig.networkConnectionTimeoutMs != newConfig.networkConnectionTimeoutMs ||
            oldConfig.networkReadTimeoutMs != newConfig.networkReadTimeoutMs) {
            httpClient.updateConnectionTimeout(newConfig.networkConnectionTimeoutMs)
            httpClient.updateReadTimeout(newConfig.networkReadTimeoutMs)
            Timber.i("Updated network timeout settings")
        }
        
        // Check for background polling changes
        if (oldConfig.disableBackgroundPolling != newConfig.disableBackgroundPolling ||
            oldConfig.backgroundPollingIntervalMs != newConfig.backgroundPollingIntervalMs ||
            oldConfig.reducedPollingIntervalMs != newConfig.reducedPollingIntervalMs) {
            Timber.i("Updated background polling settings")
            
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
            Timber.d("Pausing polling in background")
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
        Timber.d("Resuming polling")
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
                
                Timber.d("Adjusting background polling interval to $interval ms due to battery state")
                
                restartPeriodicSdkSettingsCheck(interval)
            }
        }
    }

    private fun initializeSdkSettings() {
        runBlocking(Dispatchers.IO) {
            try {
                Timber.i("Initializing SDK settings")
                checkSdkSettings()
                sdkSettingsDeferred.complete(Unit)
                Timber.i("SDK settings initialized successfully")
            } catch (e: Exception) {
                Timber.e(e) { "Failed to initialize SDK settings: ${e.message}" }
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
        Timber.d("Added user property: $key = $value")
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
        Timber.d("Added ${properties.size} user properties")
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
        Timber.i("CF client is now in offline mode")
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
        Timber.i("CF client is now in online mode")
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
        startPeriodicSdkSettingsCheck(mutableConfig.sdkSettingsCheckIntervalMs, initialCheck = false)
    }
    
    private fun startPeriodicSdkSettingsCheck(intervalMs: Long, initialCheck: Boolean = true) {
        CoroutineScope(Dispatchers.IO).launch {
            timerMutex.withLock {
                // Cancel existing timer if any
                sdkSettingsTimer?.cancel()
                
                // Create a new timer
                sdkSettingsTimer = fixedRateTimer("SdkSettingsCheck", daemon = true, 
                        initialDelay = intervalMs, 
                        period = intervalMs) {
                    CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                        Timber.d("Periodic SDK settings check triggered by timer")
                        checkSdkSettings()
                    }
                }
                
                Timber.d("Started SDK settings check timer with interval $intervalMs ms")
                
                // Perform immediate check only if requested (used by explicit init call)
                if (initialCheck) {
                   launch { // Launch in a new coroutine to avoid blocking the timer setup
                       Timber.d("Performing initial SDK settings check from startPeriodicSdkSettingsCheck")
                       checkSdkSettings()
                   } 
                }
            }
        }
    }
    
    private suspend fun restartPeriodicSdkSettingsCheck() {
        restartPeriodicSdkSettingsCheck(mutableConfig.sdkSettingsCheckIntervalMs, initialCheck = false)
    }
    
    private suspend fun restartPeriodicSdkSettingsCheck(intervalMs: Long, initialCheck: Boolean = true) {
        timerMutex.withLock {
            // Cancel existing timer if any
            sdkSettingsTimer?.cancel()
            
            // Create a new timer with updated interval
            sdkSettingsTimer = fixedRateTimer("SdkSettingsCheck", daemon = true, 
                    initialDelay = intervalMs, 
                    period = intervalMs) {
                CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                    Timber.d("Periodic SDK settings check triggered by timer")
                    checkSdkSettings()
                }
            }
            Timber.d("Restarted periodic SDK settings check with interval $intervalMs ms")

            // Perform immediate check only if requested
            if (initialCheck) {
                 CoroutineScope(Dispatchers.IO).launch { // Use CoroutineScope here
                   Timber.d("Performing immediate SDK settings check from restartPeriodicSdkSettingsCheck")
                   checkSdkSettings()
               } 
            }
        }
    }

    private suspend fun checkSdkSettings() {
        try {
            val metadata =
                    configFetcher.fetchMetadata("https://sdk.customfit.ai/${mutableConfig.dimensionId}/cf-sdk-settings.json")
                            ?: run {
                                Timber.warn { "Failed to fetch SDK settings metadata" }
                                return
                            }
            val currentLastModified = metadata["Last-Modified"] ?: return
            
            if (currentLastModified != previousLastModified) {
                Timber.i("SDK settings changed: Previous=$previousLastModified, Current=$currentLastModified")
                // Fetch the config map directly (it's nullable)
                val newConfigs = configFetcher.fetchConfig(currentLastModified)
                
                // Check if fetching the config was successful
                if (newConfigs == null) {
                    Timber.warn { "Failed to fetch config with last-modified: $currentLastModified" }
                    return
                }
                
                // Keep track of updated keys to notify listeners
                val updatedKeys = mutableSetOf<String>()
                
                configMutex.withLock {
                    // Find keys that have changed (iterate over the non-null map)
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
                
                Timber.i("Configs updated successfully with ${newConfigs.size} entries")
            } else {
                Timber.d("No change in SDK settings")
            }
        } catch (e: Exception) {
            Timber.e(e) { "Error checking SDK settings: ${e.message}" }
        }
    }

    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? =
            configFetcher.fetchMetadata("https://sdk.customfit.ai/${mutableConfig.dimensionId}/cf-sdk-settings.json")

    private suspend fun fetchSdkSettings(): SdkSettings? {
        // fetchJson now returns kotlinx.serialization.json.JsonObject?
        val jsonObject =
                httpClient.fetchJson(
                        "https://sdk.customfit.ai/${mutableConfig.dimensionId}/cf-sdk-settings.json"
                )
                        ?: run {
                            Timber.warn { "Failed to fetch SDK settings JSON" }
                            return null
                        }

        return try {
            // Use Json.decodeFromJsonElement
            val settings = Json.decodeFromJsonElement<SdkSettings>(jsonObject)
            // The null check for settings might be redundant now if decodeFromJsonElement throws on failure
            // but keeping it for safety based on previous logic.
            /* 
            if (settings == null) { 
                Timber.warn { "SdkSettings.fromJson returned null for JSON: $jsonObject" }
                return null
            }
            */
            if (!settings.cf_account_enabled || settings.cf_skip_sdk) {
                Timber.d("SDK settings skipped: cf_account_enabled=${settings.cf_account_enabled}, cf_skip_sdk=${settings.cf_skip_sdk}")
                null
            } else {
                Timber.d("Fetched SDK settings: $settings")
                settings
            }
        } catch (e: Exception) {
            // Catch SerializationException or other potential errors from decoding
            Timber.e(e) { "Error parsing SDK settings: ${e.message}" }
            null
        }
    }

    private suspend fun fetchConfigs(): Map<String, Any>? {
        val url = "https://api.customfit.ai/v1/users/configs?cfenc=${mutableConfig.clientKey}"
        val payload =
                try {
                    // Use buildJsonObject and Json.encodeToString for payload creation
                    val jsonPayload = buildJsonObject {
                        put("user", Json.encodeToJsonElement(user.toMap()))
                        put("include_only_features_flags", JsonPrimitive(true))
                    }
                    Json.encodeToString(jsonPayload)
                } catch (e: Exception) {
                    Timber.e(e) { "Error creating config payload: ${e.message}" }
                    return null
                }

        val response =
                httpClient.performRequest(
                        url,
                        "POST",
                        mapOf("Content-Type" to "application/json"),
                        payload
                ) { conn ->
                    when (conn.responseCode) {
                        HttpURLConnection.HTTP_OK ->
                                conn.inputStream.bufferedReader().use { it.readText() }
                        else -> {
                            Timber.warn { "Config fetch failed with code: ${conn.responseCode}" }
                            null
                        }
                    }
                }
                        ?: return null
        
        // Parse response using kotlinx.serialization
        val jsonElement = try {
            Json.parseToJsonElement(response)
        } catch (e: Exception) {
             Timber.e(e) { "Error parsing config response JSON: ${e.message}" }
             return null
        }

        if (jsonElement !is JsonObject) {
             Timber.warn { "Config response is not a JSON object" }
             return null
        }
                
        // Print the full response for debugging
        
        try {
            val configs =
                jsonElement["configs"]?.jsonObject
                    ?: run {
                        Timber.warn { "No 'configs' object in response" }
                        return null
                    }

            val newConfigMap = mutableMapOf<String, Any>()
            val userId = jsonElement["user_id"]?.jsonPrimitive?.contentOrNull

            configs.entries.forEach { (key, configElement) ->
                try {
                     if (configElement !is JsonObject) {
                         Timber.warn { "Config entry for '$key' is not a JSON object" }
                         return@forEach
                     }
                    val config = configElement.jsonObject // Use JsonObject directly

                    val experience =
                            config["experience_behaviour_response"]?.jsonObject
                                    ?: run {
                                        Timber.warn { "Missing 'experience_behaviour_response' for key: $key" }
                                        return@forEach
                                    }

                    val experienceKey =
                            experience["experience"]?.jsonPrimitive?.contentOrNull
                                    ?: run {
                                        Timber.warn { "Missing 'experience' field for key: $key" }
                                        return@forEach
                                    }
                    val variationDataType = config["variation_data_type"]?.jsonPrimitive?.contentOrNull ?: "UNKNOWN"
                    
                    // Extract variation using kotlinx.serialization primitives/elements
                    val variationJsonElement = config["variation"]
                    val variation: Any =
                            when (variationDataType.uppercase()) {
                                "STRING" -> variationJsonElement?.jsonPrimitive?.contentOrNull ?: ""
                                "BOOLEAN" -> variationJsonElement?.jsonPrimitive?.booleanOrNull ?: false
                                "NUMBER" -> variationJsonElement?.jsonPrimitive?.doubleOrNull ?: 0.0
                                "JSON" -> variationJsonElement?.jsonObject?.let { this.jsonObjectToMap(it) } ?: emptyMap<String, Any>()
                                else ->
                                        variationJsonElement?.jsonPrimitive?.contentOrNull?.also {
                                            Timber.warn { "Unknown variation type: $variationDataType for $key" }
                                        }
                                                ?: "" // Fallback to string or empty string
                            }

                    val experienceData =
                            // Explicitly define type arguments and use Pair constructor
                            mapOf<String, Any?>(
                                    Pair("version", config["version"]?.jsonPrimitive?.longOrNull),
                                    Pair("config_id", config["config_id"]?.jsonPrimitive?.contentOrNull),
                                    Pair("user_id", userId), // Use userId obtained earlier
                                    Pair("experience_id", experience["experience_id"]?.jsonPrimitive?.contentOrNull),
                                    Pair("behaviour", experience["behaviour"]?.jsonPrimitive?.contentOrNull),
                                    Pair("behaviour_id", experience["behaviour_id"]?.jsonPrimitive?.contentOrNull),
                                    Pair("variation_name", experience["behaviour"]?.jsonPrimitive?.contentOrNull), // Assuming variation_name is same as behaviour
                                    Pair("variation_id", experience["variation_id"]?.jsonPrimitive?.contentOrNull),
                                    Pair("priority", experience["priority"]?.jsonPrimitive?.intOrNull ?: 0),
                                    Pair("experience_created_time", experience["experience_created_time"]?.jsonPrimitive?.longOrNull ?: 0L),
                                    Pair("rule_id", experience["rule_id"]?.jsonPrimitive?.contentOrNull),
                                    Pair("experience", experienceKey),
                                    Pair("audience_name", experience["audience_name"]?.jsonPrimitive?.contentOrNull),
                                    Pair("ga_measurement_id", experience["ga_measurement_id"]?.jsonPrimitive?.contentOrNull),
                                    Pair("type", experience["type"]?.jsonPrimitive?.contentOrNull),
                                    Pair("config_modifications", experience["config_modifications"]?.jsonPrimitive?.contentOrNull),
                                    Pair("variation_data_type", variationDataType),
                                    Pair("variation", variation)
                            ).filterValues { it != null } as Map<String, Any> // Cast to Map<String, Any> after filtering nulls


                    newConfigMap[experienceKey] = experienceData
                } catch (e: Exception) {
                    Timber.e(e) { "Error processing config key '$key': ${e.message}" }
                }
            }

            return newConfigMap
        } catch (e: Exception) {
            Timber.e(e) { "Error processing config fetch: ${e.message}" }
            return null
        }
    }

    // --- Add Helper functions as private methods of the class --- 
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
            is JsonObject -> jsonObjectToMap(element) // Recursive call
            is JsonArray -> jsonArrayToList(element) // Recursive call
            null -> null
        }
    }
    
    private fun jsonObjectToMap(jsonObject: JsonObject): Map<String, Any?> {
        return jsonObject.mapValues { jsonElementToValue(it.value) }
    }

    private fun jsonArrayToList(jsonArray: JsonArray): List<Any?> {
        return jsonArray.map { jsonElementToValue(it) }
    }
    // --- End Helper functions --- 

    @Suppress("UNCHECKED_CAST")
    private fun <T> getConfigValue(key: String, fallbackValue: T, typeCheck: (Any) -> Boolean): T {
        val config = configMap[key]
        if (config == null) {
            Timber.warn { "No config found for key '$key'" }
            return fallbackValue
        }
        if (config !is Map<*, *>) {
            Timber.warn { "Config for '$key' is not a map: $config" }
            return fallbackValue
        }
        val variation = config["variation"]
        val result =
                if (variation != null && typeCheck(variation)) {
                    try {
                        variation as T
                    } catch (e: ClassCastException) {
                        Timber.warn { "Type mismatch for '$key': expected ${fallbackValue!!::class.simpleName}, got ${variation::class.simpleName}" }
                        fallbackValue
                    }
                } else {
                    Timber.warn { "No valid variation for '$key': $variation" }
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
                    Timber.e(e) { "Error notifying feature flag listener: ${e.message}" }
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
                    Timber.e(e) { "Error notifying all flags listener: ${e.message}" }
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
        Timber.d("Registered feature flag listener for key: $flagKey")
    }
    
    /**
     * Unregisters a previously registered feature flag listener
     *
     * @param flagKey the flag being listened to
     * @param listener the listener to unregister
     */
    fun unregisterFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        featureFlagListeners[flagKey]?.remove(listener)
        Timber.d("Unregistered feature flag listener for key: $flagKey")
    }
    
    /**
     * Registers a listener to be notified when any feature flag changes
     *
     * @param listener the listener to register
     */
    fun registerAllFlagsListener(listener: AllFlagsListener) {
        allFlagsListeners.add(listener)
        Timber.d("Registered all flags listener")
    }
    
    /**
     * Unregisters a previously registered all flags listener
     *
     * @param listener the listener to unregister
     */
    fun unregisterAllFlagsListener(listener: AllFlagsListener) {
        allFlagsListeners.remove(listener)
        Timber.d("Unregistered all flags listener")
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
        Timber.d("Device context updated: $deviceContext")
    }
    
    /**
     * Updates user properties with the current device context
     */
    private fun updateUserWithDeviceContext() {
        val deviceContextMap = deviceContext.toMap()
        // Only add non-empty device context
        if (deviceContextMap.isNotEmpty()) {
            // Update the device context in the properties map
            user.setDeviceContext(deviceContext)
            
            // Also keep the legacy mobile_device_context for backward compatibility
            user.addProperty("mobile_device_context", deviceContextMap)
            
            Timber.d("Updated user properties with device context")
        }
    }
    
    /**
     * Updates user properties with the current application info
     */
    private fun updateUserWithApplicationInfo(appInfo: ApplicationInfo) {
        val appInfoMap = appInfo.toMap()
        if (appInfoMap.isNotEmpty()) {
            user.setApplicationInfo(appInfo)
            this.applicationInfo = appInfo
            Timber.d("Updated user properties with application info")
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
        Timber.d("Added evaluation context: ${context.type}:${context.key}")
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
        
        Timber.d("Removed evaluation context: $type:$key")
    }
    
    /**
     * Gets all current evaluation contexts
     */
    fun getContexts(): List<EvaluationContext> = contexts.values.toList()

    /**
     * Clean up resources when the client is no longer needed
     */
    fun shutdown() {
        Timber.i("Shutting down CF client")
        
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
                Timber.e(e) { "Error flushing events during shutdown: ${e.message}" }
            }
        }
    }

    /**
     * Sets application information for targeting and analytics
     * 
     * @param appInfo the application info to set
     */
    fun setApplicationInfo(appInfo: ApplicationInfo) {
        this.applicationInfo = appInfo
        updateUserWithApplicationInfo(appInfo)
        Timber.d("Application info updated: $appInfo")
    }
    
    /**
     * Gets the current application info
     */
    fun getApplicationInfo(): ApplicationInfo? {
        return applicationInfo
    }
    
    /**
     * Increments the application launch count
     */
    fun incrementAppLaunchCount() {
        val currentAppInfo = applicationInfo ?: return
        val updatedAppInfo = currentAppInfo.copy(launchCount = currentAppInfo.launchCount + 1)
        updateUserWithApplicationInfo(updatedAppInfo)
        Timber.d("Application launch count incremented to: ${updatedAppInfo.launchCount}")
    }
    
    /**
     * Checks if automatic environment attributes collection is enabled
     */
    fun isAutoEnvAttributesEnabled(): Boolean {
        return mutableConfig.autoEnvAttributesEnabled
    }
    
    /**
     * Enables automatic environment attributes collection
     * When enabled, device and application info will be automatically detected
     */
    fun enableAutoEnvAttributes() {
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setAutoEnvAttributesEnabled(true)
        }
        Timber.d("Auto environment attributes collection enabled")
        
        // If not already initialized, detect and set now
        if (deviceContext.toMap().isEmpty() && applicationInfo == null) {
            // Initialize device context
            deviceContext = DeviceContext.createBasic()
            updateUserWithDeviceContext()
            
            // Initialize application info
            val detectedAppInfo = ApplicationInfoDetector.detectApplicationInfo()
            if (detectedAppInfo != null) {
                setApplicationInfo(detectedAppInfo)
                Timber.d("Auto-detected application info: $detectedAppInfo")
            }
        }
    }
    
    /**
     * Disables automatic environment attributes collection
     * When disabled, device and application info will not be automatically detected
     */
    fun disableAutoEnvAttributes() {
        CoroutineScope(Dispatchers.IO).launch {
            mutableConfig.setAutoEnvAttributesEnabled(false)
        }
        Timber.d("Auto environment attributes collection disabled")
    }

    companion object {
        fun init(cfConfig: CFConfig, user: CFUser): CFClient = CFClient(cfConfig, user)
    }
}
