package customfit.ai.kotlinclient.client

import customfit.ai.kotlinclient.analytics.event.EventPropertiesBuilder
import customfit.ai.kotlinclient.analytics.event.EventTracker
import customfit.ai.kotlinclient.analytics.summary.SummaryManager
import customfit.ai.kotlinclient.client.listener.AllFlagsListener
import customfit.ai.kotlinclient.client.listener.FeatureFlagChangeListener
import customfit.ai.kotlinclient.core.config.CFConfig
import customfit.ai.kotlinclient.core.config.MutableCFConfig
import customfit.ai.kotlinclient.core.model.ApplicationInfo
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.core.model.ContextType
import customfit.ai.kotlinclient.core.model.DeviceContext
import customfit.ai.kotlinclient.core.model.EvaluationContext
import customfit.ai.kotlinclient.core.model.SdkSettings
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.network.ConfigFetcher
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.network.connection.ConnectionInformation
import customfit.ai.kotlinclient.network.connection.ConnectionManager
import customfit.ai.kotlinclient.network.connection.ConnectionStatus
import customfit.ai.kotlinclient.network.connection.ConnectionStatusListener
import customfit.ai.kotlinclient.platform.AppState
import customfit.ai.kotlinclient.platform.AppStateListener
import customfit.ai.kotlinclient.platform.ApplicationInfoDetector
import customfit.ai.kotlinclient.platform.BackgroundStateMonitor
import customfit.ai.kotlinclient.platform.BatteryState
import customfit.ai.kotlinclient.platform.BatteryStateListener
import customfit.ai.kotlinclient.platform.DefaultBackgroundStateMonitor
import customfit.ai.kotlinclient.utils.CoroutineUtils
import java.net.HttpURLConnection
import java.util.Collections
import java.util.Date
import java.util.Timer
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.*

class CFClient private constructor(cfConfig: CFConfig, private var user: CFUser) {
    private val sessionId: String = UUID.randomUUID().toString()
    private val mutableConfig = MutableCFConfig(cfConfig)
    private val httpClient = HttpClient(cfConfig)
    val summaryManager = SummaryManager(sessionId, httpClient, user, cfConfig)
    val eventTracker = EventTracker(sessionId, httpClient, user, summaryManager, cfConfig)
    val configFetcher = ConfigFetcher(httpClient, cfConfig, user)

    // Connection and background state management
    private val connectionManager =
            ConnectionManager(cfConfig) {
                clientScope.launch {
                    CoroutineUtils.withErrorHandling(
                                    errorMessage = "Failed to check SDK settings on connection"
                            ) { checkSdkSettings() }
                            .onFailure { e ->
                                Timber.e(
                                        e,
                                        "Failed to check SDK settings on connection: ${e.message}"
                                )
                            }
                }
            }
    private val backgroundStateMonitor: BackgroundStateMonitor = DefaultBackgroundStateMonitor()
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
    private val featureFlagListeners =
            ConcurrentHashMap<String, MutableList<FeatureFlagChangeListener>>()
    private val allFlagsListeners = ConcurrentHashMap.newKeySet<AllFlagsListener>()

    // Application info
    private var applicationInfo: ApplicationInfo? = null

    // Dedicated coroutine scope for CFClient
    private val clientScope = CoroutineUtils.createScope(Dispatchers.IO)

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
        @Suppress("UNCHECKED_CAST") configListeners[key]?.remove(listener as (Any) -> Unit)
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
                val updatedAppInfo =
                        existingAppInfo.copy(launchCount = existingAppInfo.launchCount + 1)
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
            Timber.d(
                    "Auto environment attributes disabled, skipping device and application info detection"
            )
        }

        // Set up connection status monitoring
        setupConnectionStatusMonitoring()

        // Set up background state monitoring
        setupBackgroundStateMonitoring()

        // Add user context from the main user object
        addMainUserContext()

        // Set up config change listener
        mutableConfig.addConfigChangeListener(
                object : MutableCFConfig.ConfigChangeListener {
                    override fun onConfigChanged(oldConfig: CFConfig, newConfig: CFConfig) {
                        handleConfigChange(oldConfig, newConfig)
                    }
                }
        )

        // Start periodic SDK settings check
        startPeriodicSdkSettingsCheck()

        // Initial fetch of SDK settings
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Initial SDK settings check failed") {
                checkSdkSettings()
                sdkSettingsDeferred.complete(Unit)
            }
                    .onFailure { sdkSettingsDeferred.completeExceptionally(it) }
        }
    }

    /** Set up connection status monitoring */
    private fun setupConnectionStatusMonitoring() {
        connectionManager.addConnectionStatusListener(
                object : ConnectionStatusListener {
                    override fun onConnectionStatusChanged(
                            newStatus: ConnectionStatus,
                            info: ConnectionInformation
                    ) {
                        Timber.d("Connection status changed: $newStatus")

                        // Notify all listeners
                        for (listener in connectionStatusListeners) {
                            try {
                                listener.onConnectionStatusChanged(newStatus, info)
                            } catch (e: Exception) {
                                Timber.e(
                                        e,
                                        "Error notifying connection status listener: ${e.message}"
                                )
                            }
                        }

                        // If we're connected and we were previously disconnected, try to sync
                        if (newStatus == ConnectionStatus.CONNECTED &&
                                        (info.lastSuccessfulConnectionTimeMs == 0L ||
                                                System.currentTimeMillis() -
                                                        info.lastSuccessfulConnectionTimeMs > 60000)
                        ) {
                            clientScope.launch {
                                CoroutineUtils.withErrorHandling(
                                                errorMessage =
                                                        "Failed to check SDK settings on reconnect"
                                        ) { checkSdkSettings() }
                                        .onFailure { e ->
                                            Timber.e(
                                                    e,
                                                    "Failed to check SDK settings on reconnect: ${e.message}"
                                            )
                                        }
                            }
                        }
                    }
                }
        )
    }

    /** Set up background state monitoring */
    private fun setupBackgroundStateMonitoring() {
        backgroundStateMonitor.addAppStateListener(
                object : AppStateListener {
                    override fun onAppStateChange(state: AppState) {
                        Timber.d("App state changed: $state")

                        if (state == AppState.BACKGROUND && mutableConfig.disableBackgroundPolling
                        ) {
                            // Pause polling in background if configured to do so
                            pausePolling()
                        } else if (state == AppState.FOREGROUND) {
                            // Resume polling when app comes to foreground
                            resumePolling()

                            // Check for updates immediately when coming to foreground
                            clientScope.launch {
                                CoroutineUtils.withErrorHandling(
                                                errorMessage =
                                                        "Failed to check SDK settings on foreground"
                                        ) { checkSdkSettings() }
                                        .onFailure { e ->
                                            Timber.e(
                                                    e,
                                                    "Failed to check SDK settings on foreground: ${e.message}"
                                            )
                                        }
                            }
                        }
                    }
                }
        )

        backgroundStateMonitor.addBatteryStateListener(
                object : BatteryStateListener {
                    override fun onBatteryStateChange(state: BatteryState) {
                        Timber.d(
                                "Battery state changed: low=${state.isLow}, charging=${state.isCharging}, level=${state.level}"
                        )

                        if (mutableConfig.useReducedPollingWhenBatteryLow &&
                                        state.isLow &&
                                        !state.isCharging
                        ) {
                            // Use reduced polling on low battery
                            adjustPollingForBatteryState(true)
                        } else {
                            // Use normal polling
                            adjustPollingForBatteryState(false)
                        }
                    }
                }
        )
    }

    /** Add the main user to the contexts collection */
    private fun addMainUserContext() {
        // Create a user context from the main user object
        val userContext =
                EvaluationContext(
                        type = ContextType.USER,
                        key = user.user_customer_id ?: UUID.randomUUID().toString(),
                        properties = user.properties
                )
        contexts["user"] = userContext

        // Add user context to user properties
        user = user.addContext(userContext)

        // Add device context to user properties
        updateUserWithDeviceContext()
    }

    /** Handle configuration changes and update components as needed */
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
            clientScope.launch {
                CoroutineUtils.withErrorHandling(
                                errorMessage = "Failed to restart periodic SDK settings check"
                        ) { restartPeriodicSdkSettingsCheck() }
                        .onFailure { e ->
                            Timber.e(
                                    e,
                                    "Failed to restart periodic SDK settings check: ${e.message}"
                            )
                        }
            }
            Timber.i(
                    "Updated SDK settings check interval to ${newConfig.sdkSettingsCheckIntervalMs} ms"
            )
        }

        // Check for network timeout changes
        if (oldConfig.networkConnectionTimeoutMs != newConfig.networkConnectionTimeoutMs ||
                        oldConfig.networkReadTimeoutMs != newConfig.networkReadTimeoutMs
        ) {
            httpClient.updateConnectionTimeout(newConfig.networkConnectionTimeoutMs)
            httpClient.updateReadTimeout(newConfig.networkReadTimeoutMs)
            Timber.i("Updated network timeout settings")
        }

        // Check for background polling changes
        if (oldConfig.disableBackgroundPolling != newConfig.disableBackgroundPolling ||
                        oldConfig.backgroundPollingIntervalMs !=
                                newConfig.backgroundPollingIntervalMs ||
                        oldConfig.reducedPollingIntervalMs != newConfig.reducedPollingIntervalMs
        ) {
            Timber.i("Updated background polling settings")

            if (backgroundStateMonitor.getCurrentAppState() == AppState.BACKGROUND &&
                            newConfig.disableBackgroundPolling
            ) {
                pausePolling()
            } else {
                resumePolling()

                // Adjust for battery state
                val batteryState = backgroundStateMonitor.getCurrentBatteryState()
                if (newConfig.useReducedPollingWhenBatteryLow &&
                                batteryState.isLow &&
                                !batteryState.isCharging
                ) {
                    adjustPollingForBatteryState(true)
                }
            }
        }
    }

    /** Pause polling when in background if configured */
    private fun pausePolling() {
        if (mutableConfig.disableBackgroundPolling) {
            Timber.d("Pausing polling in background")
            clientScope.launch {
                CoroutineUtils.withErrorHandling(errorMessage = "Failed to pause polling") {
                    timerMutex.withLock {
                        sdkSettingsTimer?.cancel()
                        sdkSettingsTimer = null
                    }
                }
                        .onFailure { e -> Timber.e(e, "Failed to pause polling: ${e.message}") }
            }
        }
    }

    /** Resume polling when returning to foreground */
    private fun resumePolling() {
        Timber.d("Resuming polling")
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Failed to resume polling") {
                restartPeriodicSdkSettingsCheck()
            }
                    .onFailure { e -> Timber.e(e, "Failed to resume polling: ${e.message}") }
        }
    }

    /** Adjust polling intervals based on battery state */
    private fun adjustPollingForBatteryState(useLowBatteryInterval: Boolean) {
        if (backgroundStateMonitor.getCurrentAppState() == AppState.BACKGROUND) {
            clientScope.launch {
                CoroutineUtils.withErrorHandling(
                                errorMessage = "Failed to adjust polling for battery state"
                        ) {
                    val interval =
                            if (useLowBatteryInterval) {
                                mutableConfig.reducedPollingIntervalMs
                            } else {
                                mutableConfig.backgroundPollingIntervalMs
                            }

                    Timber.d(
                            "Adjusting background polling interval to $interval ms due to battery state"
                    )
                    restartPeriodicSdkSettingsCheck(interval)
                }
                        .onFailure { e ->
                            Timber.e(e, "Failed to adjust polling for battery state: ${e.message}")
                        }
            }
        }
    }

    private fun initializeSdkSettings() {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "SDK settings initialization failed") {
                Timber.i("Initializing SDK settings")
                checkSdkSettings()
                sdkSettingsDeferred.complete(Unit)
                Timber.i("SDK settings initialized successfully")
            }
                    .onFailure { sdkSettingsDeferred.completeExceptionally(it) }
        }
    }

    suspend fun awaitSdkSettingsCheck() = sdkSettingsDeferred.await()

    fun getString(key: String, fallbackValue: String): String =
            getConfigValue(key, fallbackValue) { it is String }

    fun getString(
            key: String,
            fallbackValue: String,
            callback: ((String) -> Unit)? = null
    ): String {
        val value = getString(key, fallbackValue)
        callback?.invoke(value)
        return value
    }

    fun getNumber(key: String, fallbackValue: Number): Number =
            getConfigValue(key, fallbackValue) { it is Number }

    fun getNumber(
            key: String,
            fallbackValue: Number,
            callback: ((Number) -> Unit)? = null
    ): Number {
        val value = getNumber(key, fallbackValue)
        callback?.invoke(value)
        return value
    }

    fun getBoolean(key: String, fallbackValue: Boolean): Boolean =
            getConfigValue(key, fallbackValue) { it is Boolean }

    fun getBoolean(
            key: String,
            fallbackValue: Boolean,
            callback: ((Boolean) -> Unit)? = null
    ): Boolean {
        val value = getBoolean(key, fallbackValue)
        callback?.invoke(value)
        return value
    }

    fun getJson(key: String, fallbackValue: Map<String, Any>): Map<String, Any> =
            getConfigValue(key, fallbackValue) {
                it is Map<*, *> && it.keys.all { k -> k is String }
            }

    fun getJson(
            key: String,
            fallbackValue: Map<String, Any>,
            callback: ((Map<String, Any>) -> Unit)? = null
    ): Map<String, Any> {
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
        user = user.addProperty(key, value)
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
        val jsonCompatible = value.filterValues { isJsonCompatible(it) }
        addUserProperty(key, jsonCompatible)
    }

    private fun isJsonCompatible(value: Any?): Boolean =
            when (value) {
                null -> true
                is String, is Number, is Boolean -> true
                is Map<*, *> ->
                        value.keys.all { it is String } && value.values.all { isJsonCompatible(it) }
                is Collection<*> -> value.all { isJsonCompatible(it) }
                else -> false
            }

    // Add multiple properties to the user at once
    fun addUserProperties(properties: Map<String, Any>) {
        user = user.addProperties(properties)
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

    /** Puts the client in offline mode, preventing network requests. This method is thread-safe. */
    fun setOffline() {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Failed to set offline mode") {
                mutableConfig.setOfflineMode(true)
                configFetcher.setOffline(true)
                connectionManager.setOfflineMode(true)
                Timber.i("CF client is now in offline mode")
            }
                    .onFailure { e -> Timber.e(e, "Failed to set offline mode: ${e.message}") }
        }
    }

    /**
     * Restores the client to online mode, allowing network requests. This method is thread-safe.
     */
    fun setOnline() {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Failed to set online mode") {
                mutableConfig.setOfflineMode(false)
                configFetcher.setOffline(false)
                connectionManager.setOfflineMode(false)
                Timber.i("CF client is now in online mode")
            }
                    .onFailure { e -> Timber.e(e, "Failed to set online mode: ${e.message}") }
        }
    }

    /**
     * Updates the SDK settings check interval. This will restart the timer with the new interval.
     *
     * @param intervalMs the new interval in milliseconds
     */
    fun updateSdkSettingsCheckInterval(intervalMs: Long) {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed to update SDK settings check interval"
                    ) { mutableConfig.setSdkSettingsCheckIntervalMs(intervalMs) }
                    .onFailure { e ->
                        Timber.e(e, "Failed to update SDK settings check interval: ${e.message}")
                    }
        }
    }

    /**
     * Updates the events flush interval.
     *
     * @param intervalMs the new interval in milliseconds
     */
    fun updateEventsFlushInterval(intervalMs: Long) {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed to update events flush interval"
                    ) { mutableConfig.setEventsFlushIntervalMs(intervalMs) }
                    .onFailure { e ->
                        Timber.e(e, "Failed to update events flush interval: ${e.message}")
                    }
        }
    }

    /**
     * Updates the summaries flush interval.
     *
     * @param intervalMs the new interval in milliseconds
     */
    fun updateSummariesFlushInterval(intervalMs: Long) {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed to update summaries flush interval"
                    ) { mutableConfig.setSummariesFlushIntervalMs(intervalMs) }
                    .onFailure { e ->
                        Timber.e(e, "Failed to update summaries flush interval: ${e.message}")
                    }
        }
    }

    /**
     * Updates the network connection timeout.
     *
     * @param timeoutMs the new timeout in milliseconds
     */
    fun updateNetworkConnectionTimeout(timeoutMs: Int) {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed to update network connection timeout"
                    ) { mutableConfig.setNetworkConnectionTimeoutMs(timeoutMs) }
                    .onFailure { e ->
                        Timber.e(e, "Failed to update network connection timeout: ${e.message}")
                    }
        }
    }

    /**
     * Updates the network read timeout.
     *
     * @param timeoutMs the new timeout in milliseconds
     */
    fun updateNetworkReadTimeout(timeoutMs: Int) {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed to update network read timeout"
                    ) { mutableConfig.setNetworkReadTimeoutMs(timeoutMs) }
                    .onFailure { e ->
                        Timber.e(e, "Failed to update network read timeout: ${e.message}")
                    }
        }
    }

    /**
     * Updates the debug logging setting.
     *
     * @param enabled true to enable debug logging, false to disable
     */
    fun setDebugLoggingEnabled(enabled: Boolean) {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Failed to set debug logging") {
                mutableConfig.setDebugLoggingEnabled(enabled)
            }
                    .onFailure { e -> Timber.e(e, "Failed to set debug logging: ${e.message}") }
        }
    }

    private fun startPeriodicSdkSettingsCheck() {
        startPeriodicSdkSettingsCheck(
                mutableConfig.sdkSettingsCheckIntervalMs,
                initialCheck = false
        )
    }

    private fun startPeriodicSdkSettingsCheck(intervalMs: Long, initialCheck: Boolean = true) {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed to start periodic SDK settings check"
                    ) {
                timerMutex.withLock {
                    // Cancel existing timer if any
                    sdkSettingsTimer?.cancel()

                    // Create a new timer
                    sdkSettingsTimer =
                            fixedRateTimer(
                                    "SdkSettingsCheck",
                                    daemon = true,
                                    initialDelay = intervalMs,
                                    period = intervalMs
                            ) {
                                clientScope.launch {
                                    CoroutineUtils.withErrorHandling(
                                                    errorMessage =
                                                            "Periodic SDK settings check failed"
                                            ) {
                                        Timber.d("Periodic SDK settings check triggered by timer")
                                        checkSdkSettings()
                                    }
                                            .onFailure { e ->
                                                Timber.e(
                                                        e,
                                                        "Periodic SDK settings check failed: ${e.message}"
                                                )
                                            }
                                }
                            }

                    Timber.d("Started SDK settings check timer with interval $intervalMs ms")

                    // Perform immediate check only if requested
                    if (initialCheck) {
                        checkSdkSettings()
                    }
                }
            }
                    .onFailure { e ->
                        Timber.e(e, "Failed to start periodic SDK settings check: ${e.message}")
                    }
        }
    }

    private suspend fun restartPeriodicSdkSettingsCheck() {
        restartPeriodicSdkSettingsCheck(
                mutableConfig.sdkSettingsCheckIntervalMs,
                initialCheck = false
        )
    }

    private suspend fun restartPeriodicSdkSettingsCheck(
            intervalMs: Long,
            initialCheck: Boolean = true
    ) {
        timerMutex.withLock {
            // Cancel existing timer if any
            sdkSettingsTimer?.cancel()

            // Create a new timer with updated interval
            sdkSettingsTimer =
                    fixedRateTimer(
                            "SdkSettingsCheck",
                            daemon = true,
                            initialDelay = intervalMs,
                            period = intervalMs
                    ) {
                        clientScope.launch {
                            CoroutineUtils.withErrorHandling(
                                            errorMessage = "Periodic SDK settings check failed"
                                    ) {
                                Timber.d("Periodic SDK settings check triggered by timer")
                                checkSdkSettings()
                            }
                                    .onFailure { e ->
                                        Timber.e(
                                                e,
                                                "Periodic SDK settings check failed: ${e.message}"
                                        )
                                    }
                        }
                    }
            Timber.d("Restarted periodic SDK settings check with interval $intervalMs ms")

            // Perform immediate check only if requested
            if (initialCheck) {
                clientScope.launch {
                    CoroutineUtils.withErrorHandling(
                                    errorMessage = "Failed immediate SDK settings check"
                            ) {
                        Timber.d(
                                "Performing immediate SDK settings check from restartPeriodicSdkSettingsCheck"
                        )
                        checkSdkSettings()
                    }
                            .onFailure { e ->
                                Timber.e(e, "Failed immediate SDK settings check: ${e.message}")
                            }
                }
            }
        }
    }

    private suspend fun checkSdkSettings() {
        CoroutineUtils.withCircuitBreaker(
                operationKey = "sdk_settings_fetch",
                failureThreshold = 3,
                resetTimeoutMs = 30_000,
                fallback = Unit
        ) {
            CoroutineUtils.withTiming("checkSdkSettings") {
                CoroutineUtils.withTimeoutOrNull(10_000) {
                    CoroutineUtils.withRetry(
                            maxAttempts = 3,
                            initialDelayMs = 100,
                            maxDelayMs = 1000,
                            retryOn = { it !is CancellationException }
                    ) {
                        val metadata =
                                configFetcher.fetchMetadata(
                                        "https://sdk.customfit.ai/${mutableConfig.dimensionId}/cf-sdk-settings.json"
                                )
                                        ?: run {
                                            Timber.warn { "Failed to fetch SDK settings metadata" }
                                            return@withRetry Unit
                                        }
                        val currentLastModified = metadata["Last-Modified"] ?: return@withRetry Unit

                        if (currentLastModified != previousLastModified) {
                            Timber.i(
                                    "SDK settings changed: Previous=$previousLastModified, Current=$currentLastModified"
                            )
                            val newConfigs =
                                    configFetcher.fetchConfig(currentLastModified)
                                            ?: run {
                                                Timber.warn {
                                                    "Failed to fetch config with last-modified: $currentLastModified"
                                                }
                                                return@withRetry Unit
                                            }

                            val updatedKeys = mutableSetOf<String>()
                            configMutex.withLock {
                                for (key in newConfigs.keys) {
                                    if (!configMap.containsKey(key) ||
                                                    configMap[key] != newConfigs[key]
                                    ) {
                                        updatedKeys.add(key)
                                    }
                                }
                                configMap.clear()
                                configMap.putAll(newConfigs)
                                previousLastModified = currentLastModified
                            }

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
                    }
                }
                        ?: Timber.warn { "SDK settings check timed out" }
            }
        }
    }

    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? =
            CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed to fetch SDK settings metadata"
                    ) {
                CoroutineUtils.withTimeoutOrNull(5_000) {
                    configFetcher.fetchMetadata(
                            "https://sdk.customfit.ai/${mutableConfig.dimensionId}/cf-sdk-settings.json"
                    )
                }
            }
                    .getOrElse {
                        Timber.e(it, "Error fetching SDK settings metadata")
                        null
                    }

    private suspend fun fetchSdkSettings(): SdkSettings? {
        return CoroutineUtils.withErrorHandling(
                        context = Dispatchers.IO,
                        errorMessage = "Failed to fetch SDK settings"
                ) {
            CoroutineUtils.withTimeoutOrNull(5_000) {
                val jsonObject =
                        httpClient.fetchJson(
                                "https://sdk.customfit.ai/${mutableConfig.dimensionId}/cf-sdk-settings.json"
                        )
                                ?: run {
                                    Timber.warn { "Failed to fetch SDK settings JSON" }
                                    null
                                }

                jsonObject?.let {
                    val settings = Json.decodeFromString<SdkSettings>(it.toString())
                    if (!settings.cf_account_enabled || settings.cf_skip_sdk) {
                        Timber.d(
                                "SDK settings skipped: cf_account_enabled=${settings.cf_account_enabled}, cf_skip_sdk=${settings.cf_skip_sdk}"
                        )
                        null
                    } else {
                        Timber.d("Fetched SDK settings: $settings")
                        settings
                    }
                }
            }
        }
                .getOrElse {
                    Timber.e(it, "Error fetching SDK settings")
                    null
                }
    }

    private suspend fun fetchConfigs(): Map<String, Any>? {
        return CoroutineUtils.withCircuitBreaker(
                operationKey = "configs_fetch",
                failureThreshold = 3,
                resetTimeoutMs = 30_000,
                fallback = null
        ) {
            CoroutineUtils.withRetry(
                    maxAttempts = 3,
                    initialDelayMs = 100,
                    maxDelayMs = 1000,
                    retryOn = { it !is CancellationException }
            ) {
                val url =
                        "https://api.customfit.ai/v1/users/configs?cfenc=${mutableConfig.clientKey}"
                val payload =
                        try {
                            val jsonPayload = buildJsonObject {
                                put("user", Json.encodeToJsonElement(user.toUserMap()))
                                put("include_only_features_flags", JsonPrimitive(true))
                            }
                            Json.encodeToString(JsonElement.serializer(), jsonPayload)
                        } catch (e: Exception) {
                            Timber.e(e, "Error creating config payload")
                            return@withRetry null
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
                                    Timber.warn {
                                        "Config fetch failed with code: ${conn.responseCode}"
                                    }
                                    null
                                }
                            }
                        }
                                ?: return@withRetry null

                val jsonElement =
                        try {
                            Json.parseToJsonElement(response)
                        } catch (e: Exception) {
                            Timber.e(e, "Error parsing config response JSON")
                            return@withRetry null
                        }

                if (jsonElement !is JsonObject) {
                    Timber.warn { "Config response is not a JSON object" }
                    return@withRetry null
                }

                val configs =
                        jsonElement["configs"]?.jsonObject
                                ?: run {
                                    Timber.warn { "No 'configs' object in response" }
                                    return@withRetry null
                                }

                val newConfigMap = mutableMapOf<String, Any>()
                val userId = jsonElement["user_id"]?.jsonPrimitive?.contentOrNull

                configs.entries.forEach { (key, configElement) ->
                    try {
                        if (configElement !is JsonObject) {
                            Timber.warn { "Config entry for '$key' is not a JSON object" }
                            return@forEach
                        }
                        val config = configElement.jsonObject
                        val experience =
                                config["experience_behaviour_response"]?.jsonObject
                                        ?: run {
                                            Timber.warn {
                                                "Missing 'experience_behaviour_response' for key: $key"
                                            }
                                            return@forEach
                                        }

                        val experienceKey =
                                experience["experience"]?.jsonPrimitive?.contentOrNull
                                        ?: run {
                                            Timber.warn {
                                                "Missing 'experience' field for key: $key"
                                            }
                                            return@forEach
                                        }
                        val variationDataType =
                                config["variation_data_type"]?.jsonPrimitive?.contentOrNull
                                        ?: "UNKNOWN"
                        val variationJsonElement = config["variation"]
                        val variation: Any =
                                when (variationDataType.uppercase()) {
                                    "STRING" -> variationJsonElement?.jsonPrimitive?.content ?: ""
                                    "BOOLEAN" -> variationJsonElement?.jsonPrimitive?.boolean
                                                    ?: false
                                    "NUMBER" -> variationJsonElement?.jsonPrimitive?.double ?: 0.0
                                    "JSON" ->
                                            variationJsonElement?.jsonObject?.let {
                                                jsonObjectToMap(it)
                                            }
                                                    ?: emptyMap<String, Any>()
                                    else ->
                                            variationJsonElement?.jsonPrimitive?.content?.also {
                                                Timber.warn {
                                                    "Unknown variation type: $variationDataType for $key"
                                                }
                                            }
                                                    ?: ""
                                }

                        val experienceData =
                                mapOf<String, Any?>(
                                                "version" to config["version"]?.jsonPrimitive?.long,
                                                "config_id" to
                                                        config["config_id"]?.jsonPrimitive?.content,
                                                "user_id" to userId,
                                                "experience_id" to
                                                        experience["experience_id"]
                                                                ?.jsonPrimitive
                                                                ?.content,
                                                "behaviour" to
                                                        experience["behaviour"]
                                                                ?.jsonPrimitive
                                                                ?.content,
                                                "behaviour_id" to
                                                        experience["behaviour_id"]
                                                                ?.jsonPrimitive
                                                                ?.content,
                                                "variation_name" to
                                                        experience["behaviour"]
                                                                ?.jsonPrimitive
                                                                ?.content,
                                                "variation_id" to
                                                        experience["variation_id"]
                                                                ?.jsonPrimitive
                                                                ?.content,
                                                "priority" to
                                                        (experience["priority"]?.jsonPrimitive?.int
                                                                ?: 0),
                                                "experience_created_time" to
                                                        (experience["experience_created_time"]
                                                                ?.jsonPrimitive
                                                                ?.long
                                                                ?: 0L),
                                                "rule_id" to
                                                        experience["rule_id"]
                                                                ?.jsonPrimitive
                                                                ?.content,
                                                "experience" to experienceKey,
                                                "audience_name" to
                                                        experience["audience_name"]
                                                                ?.jsonPrimitive
                                                                ?.content,
                                                "ga_measurement_id" to
                                                        experience["ga_measurement_id"]
                                                                ?.jsonPrimitive
                                                                ?.content,
                                                "type" to
                                                        experience["type"]?.jsonPrimitive?.content,
                                                "config_modifications" to
                                                        experience["config_modifications"]
                                                                ?.jsonPrimitive
                                                                ?.content,
                                                "variation_data_type" to variationDataType,
                                                "variation" to variation
                                        )
                                        .filterValues { it != null }
                                        .mapValues { it.value!! } 

                        newConfigMap[experienceKey] = experienceData
                    } catch (e: Exception) {
                        Timber.e(e, "Error processing config key '$key'")
                    }
                }
                newConfigMap
            }
        }
    }

    // Helper functions as private methods of the class
    private fun jsonElementToValue(element: JsonElement?): Any? {
        return when (element) {
            is JsonNull -> null
            is JsonPrimitive ->
                    when {
                        element.isString -> element.content
                        element.content.toBooleanStrictOrNull() != null ->
                                element.content.toBooleanStrict()
                        element.content.toLongOrNull() != null -> element.content.toLong()
                        element.content.toDoubleOrNull() != null -> element.content.toDouble()
                        else -> element.content
                    }
            is JsonObject -> jsonObjectToMap(element)
            is JsonArray -> jsonArrayToList(element)
            else -> null
        }
    }

    private fun jsonObjectToMap(jsonObject: JsonObject): Map<String, Any?> {
        return jsonObject.mapValues { jsonElementToValue(it.value) }
    }

    private fun jsonArrayToList(jsonArray: JsonArray): List<Any?> {
        return jsonArray.map { jsonElementToValue(it) }
    }

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
                        Timber.warn {
                            "Type mismatch for '$key': expected ${fallbackValue!!::class.simpleName}, got ${variation::class.simpleName}"
                        }
                        fallbackValue
                    }
                } else {
                    Timber.warn { "No valid variation for '$key': $variation" }
                    fallbackValue
                }
        summaryManager.pushSummary(config as Map<String, Any>)
        return result
    }

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
                    Timber.e(e, "Error notifying feature flag listener: ${e.message}")
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
                    Timber.e(e, "Error notifying all flags listener: ${e.message}")
                }
            }
        }
    }

    /** Returns a map of all feature flags with their current values */
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
        featureFlagListeners[flagKey]?.remove(listener as Any)
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

    /** Gets the current connection information */
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

    /** Updates user properties with the current device context */
    private fun updateUserWithDeviceContext() {
        val deviceContextMap = deviceContext.toMap()
        // Only add non-empty device context
        if (deviceContextMap.isNotEmpty()) {
            // Update the device context in the properties map
            user = user.setDeviceContext(deviceContext)

            // Also keep the legacy mobile_device_context for backward compatibility
            user = user.addProperty("mobile_device_context", deviceContextMap)

            Timber.d("Updated user properties with device context")
        }
    }

    /** Updates user properties with the current application info */
    private fun updateUserWithApplicationInfo(appInfo: ApplicationInfo) {
        val appInfoMap = appInfo.toMap()
        if (appInfoMap.isNotEmpty()) {
            user = user.setApplicationInfo(appInfo)
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
        user = user.addContext(context)
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
        val userContexts = user.getAllContexts().filter { !(it.type == type && it.key == key) }
        val contextsList = mutableListOf<Map<String, Any?>>()
        userContexts.forEach { contextsList.add(it.toMap()) }
        user = user.addProperty("contexts", contextsList)

        Timber.d("Removed evaluation context: $type:$key")
    }

    /** Gets all current evaluation contexts */
    fun getContexts(): List<EvaluationContext> = contexts.values.toList()

    /** Clean up resources when the client is no longer needed */
    fun shutdown() {
        Timber.i("Shutting down CF client")

        // Cancel client scope
        clientScope.cancel()

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
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Error flushing during shutdown") {
                eventTracker.flushEvents()
                summaryManager.flushSummaries()
            }
                    .onFailure { e ->
                        Timber.e(e, "Failed to flush events during shutdown: ${e.message}")
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

    /** Gets the current application info */
    fun getApplicationInfo(): ApplicationInfo? {
        return applicationInfo
    }

    /** Increments the application launch count */
    fun incrementAppLaunchCount() {
        val currentAppInfo = applicationInfo ?: return
        val updatedAppInfo = currentAppInfo.copy(launchCount = currentAppInfo.launchCount + 1)
        updateUserWithApplicationInfo(updatedAppInfo)
        Timber.d("Application launch count incremented to: ${updatedAppInfo.launchCount}")
    }

    /** Checks if automatic environment attributes collection is enabled */
    fun isAutoEnvAttributesEnabled(): Boolean {
        return mutableConfig.autoEnvAttributesEnabled
    }

    /**
     * Enables automatic environment attributes collection When enabled, device and application info
     * will be automatically detected
     */
    fun enableAutoEnvAttributes() {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed to enable auto environment attributes"
                    ) {
                mutableConfig.setAutoEnvAttributesEnabled(true)
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
                    .onFailure { e ->
                        Timber.e(e, "Failed to enable auto environment attributes: ${e.message}")
                    }
        }
    }

    /**
     * Disables automatic environment attributes collection When disabled, device and application
     * info will not be automatically detected
     */
    fun disableAutoEnvAttributes() {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                            errorMessage = "Failed to disable auto environment attributes"
                    ) {
                mutableConfig.setAutoEnvAttributesEnabled(false)
                Timber.d("Auto environment attributes collection disabled")
            }
                    .onFailure { e ->
                        Timber.e(e, "Failed to disable auto environment attributes: ${e.message}")
                    }
        }
    }

    companion object {
        fun init(cfConfig: CFConfig, user: CFUser): CFClient = CFClient(cfConfig, user)
    }
}
