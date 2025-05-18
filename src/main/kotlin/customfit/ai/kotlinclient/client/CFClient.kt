package customfit.ai.kotlinclient.client

import customfit.ai.kotlinclient.analytics.event.EventData
import customfit.ai.kotlinclient.analytics.event.EventPropertiesBuilder
import customfit.ai.kotlinclient.analytics.event.EventTracker
import customfit.ai.kotlinclient.analytics.summary.SummaryManager
import customfit.ai.kotlinclient.client.listener.AllFlagsListener
import customfit.ai.kotlinclient.client.listener.FeatureFlagChangeListener
import customfit.ai.kotlinclient.client.managers.ConfigManager
import customfit.ai.kotlinclient.client.managers.ConfigManagerImpl
import customfit.ai.kotlinclient.client.managers.ConnectionManagerInterface
import customfit.ai.kotlinclient.client.managers.ConnectionManagerWrapper
import customfit.ai.kotlinclient.client.managers.EnvironmentManager
import customfit.ai.kotlinclient.client.managers.EnvironmentManagerImpl
import customfit.ai.kotlinclient.client.managers.ListenerManager
import customfit.ai.kotlinclient.client.managers.ListenerManagerImpl
import customfit.ai.kotlinclient.client.managers.UserManager
import customfit.ai.kotlinclient.client.managers.UserManagerImpl
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.config.core.MutableCFConfig
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.core.error.ErrorHandler
import customfit.ai.kotlinclient.core.model.ApplicationInfo
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.core.model.ContextType
import customfit.ai.kotlinclient.core.model.DeviceContext
import customfit.ai.kotlinclient.core.model.EvaluationContext
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.network.ConfigFetcher
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.network.connection.ConnectionInformation
import customfit.ai.kotlinclient.network.connection.ConnectionStatus
import customfit.ai.kotlinclient.network.connection.ConnectionStatusListener
import customfit.ai.kotlinclient.platform.AppState
import customfit.ai.kotlinclient.platform.AppStateListener
import customfit.ai.kotlinclient.platform.BackgroundStateMonitor
import customfit.ai.kotlinclient.platform.BatteryStateListener
import customfit.ai.kotlinclient.platform.DefaultBackgroundStateMonitor
import customfit.ai.kotlinclient.utils.CoroutineUtils
import java.util.Date
import java.util.UUID
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Modular implementation of the CustomFit client SDK
 * 
 * This class serves as a facade that delegates operations to specialized manager classes.
 */
class CFClient private constructor(cfConfig: CFConfig, initialUser: CFUser) {
    private val sessionId: String = UUID.randomUUID().toString()
    private val mutableConfig = MutableCFConfig(cfConfig)
    private val httpClient = HttpClient(cfConfig)
    
    // Client scope for coroutines
    private val clientScope = CoroutineUtils.createScope(Dispatchers.IO)
    
    // Used to track initialization of SDK settings
    private val sdkSettingsDeferred: CompletableDeferred<Unit> = CompletableDeferred()
    
    // Core managers
    private val listenerManager: ListenerManager = ListenerManagerImpl()
    private val userManager: UserManager = UserManagerImpl(initialUser)
    private val connectionManager: ConnectionManagerInterface = ConnectionManagerWrapper(cfConfig)
    private val backgroundStateMonitor = DefaultBackgroundStateMonitor()
    private val environmentManager: EnvironmentManager = EnvironmentManagerImpl(
        backgroundStateMonitor, 
        userManager,
        clientScope
    )
    
    // API managers
    val summaryManager = SummaryManager(sessionId, httpClient, initialUser, cfConfig)
    val eventTracker = EventTracker(sessionId, httpClient, initialUser, summaryManager, cfConfig)
    private val configFetcher = ConfigFetcher(httpClient, cfConfig, initialUser)
    private val configManager: ConfigManager = ConfigManagerImpl(
        configFetcher,
        clientScope,
        listenerManager,
        cfConfig
    )

    init {
        // Configure logger with the log level from config
        
        // Set initial offline mode from the config
        if (mutableConfig.offlineMode) {
            configFetcher.setOffline(true)
            connectionManager.setOfflineMode(true)
            Timber.i("CF client initialized in offline mode")
        }
        
        // Initialize environment attributes
        environmentManager.initialize(mutableConfig.autoEnvAttributesEnabled)
        
        // Set up background state monitoring
        setupBackgroundStateMonitoring()
        
        // Set up config change listener
        mutableConfig.addConfigChangeListener(
            object : MutableCFConfig.ConfigChangeListener {
                override fun onConfigChanged(oldConfig: CFConfig, newConfig: CFConfig) {
                    handleConfigChange(oldConfig, newConfig)
                }
            }
        )
        
        // Start periodic SDK settings check
        configManager.startPeriodicSdkSettingsCheck(mutableConfig.sdkSettingsCheckIntervalMs)
        
        // Initial SDK settings check
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Initial SDK settings check failed") {
                configManager.checkSdkSettings()
                sdkSettingsDeferred.complete(Unit)
            }
            .onFailure { sdkSettingsDeferred.completeExceptionally(it) }
        }
    }
    
    /**
     * Suspends until SDK settings have been initialized
     * 
     * @return Unit if successful, throws exception if SDK settings initialization failed
     */
    suspend fun awaitSdkSettingsCheck() = sdkSettingsDeferred.await()
    
    /**
     * Set up background state monitoring
     */
    private fun setupBackgroundStateMonitoring() {
        environmentManager.addAppStateListener(
            object : AppStateListener {
                override fun onAppStateChange(state: AppState) {
                    Timber.d("App state changed: $state")
                    
                    if (state == AppState.BACKGROUND && mutableConfig.disableBackgroundPolling) {
                        // Pause polling in background if configured to do so
                        configManager.pausePolling()
                    } else if (state == AppState.FOREGROUND) {
                        // Resume polling when app comes to foreground
                        configManager.resumePolling()
                        
                        // Check for updates immediately when coming to foreground
                        clientScope.launch {
                            CoroutineUtils.withErrorHandling(
                                errorMessage = "Failed to check SDK settings on foreground"
                            ) { 
                                configManager.checkSdkSettings() 
                            }
                            .onFailure { e ->
                                Timber.e(e, "Failed to check SDK settings on foreground: ${e.message}")
                            }
                        }
                    }
                }
            }
        )
        
        environmentManager.addBatteryStateListener(
            object : BatteryStateListener {
                override fun onBatteryStateChange(state: customfit.ai.kotlinclient.platform.BatteryState) {
                    Timber.d(
                        "Battery state changed: low=${state.isLow}, charging=${state.isCharging}, level=${state.level}"
                    )
                    
                    // Use reduced polling on low battery based on config
                    clientScope.launch {
                        if (mutableConfig.useReducedPollingWhenBatteryLow && state.isLow && !state.isCharging) {
                            CoroutineUtils.withErrorHandling(
                                errorMessage = "Failed to adjust polling for battery state"
                            ) {
                                configManager.restartPeriodicSdkSettingsCheck(
                                    mutableConfig.reducedPollingIntervalMs
                                )
                            }
                            .onFailure { e ->
                                Timber.e(e, "Failed to adjust polling for battery state: ${e.message}")
                            }
                        } else {
                            CoroutineUtils.withErrorHandling(
                                errorMessage = "Failed to adjust polling for battery state"
                            ) {
                                configManager.restartPeriodicSdkSettingsCheck(
                                    mutableConfig.backgroundPollingIntervalMs
                                )
                            }
                            .onFailure { e ->
                                Timber.e(e, "Failed to adjust polling for battery state: ${e.message}")
                            }
                        }
                    }
                }
            }
        )
    }
    
    /**
     * Handle configuration changes
     */
    private fun handleConfigChange(oldConfig: CFConfig, newConfig: CFConfig) {
        Timber.d("Config changed")
        
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
                ) { 
                    configManager.restartPeriodicSdkSettingsCheck(newConfig.sdkSettingsCheckIntervalMs) 
                }
                .onFailure { e ->
                    Timber.e(e, "Failed to restart periodic SDK settings check: ${e.message}")
                }
            }
        }
        
        // Check for network timeout changes
        if (oldConfig.networkConnectionTimeoutMs != newConfig.networkConnectionTimeoutMs ||
            oldConfig.networkReadTimeoutMs != newConfig.networkReadTimeoutMs
        ) {
            httpClient.updateConnectionTimeout(newConfig.networkConnectionTimeoutMs)
            httpClient.updateReadTimeout(newConfig.networkReadTimeoutMs)
            Timber.i("Updated network timeout settings")
        }
    }
    
    /**
     * Register a listener for a specific feature flag
     * @param key The feature flag key
     * @param listener Callback function invoked whenever the flag value changes
     */
    fun <T : Any> addConfigListener(key: String, listener: (T) -> Unit) {
        listenerManager.addConfigListener(key, listener)
    }
    
    /**
     * Remove a listener for a specific feature flag
     * @param key The feature flag key
     * @param listener The listener to remove
     */
    fun <T : Any> removeConfigListener(key: String, listener: (T) -> Unit) {
        listenerManager.removeConfigListener(key, listener)
    }
    
    /**
     * Remove all listeners for a specific feature flag
     * @param key The feature flag key
     */
    fun clearConfigListeners(key: String) {
        listenerManager.clearConfigListeners(key)
    }
    
    /**
     * Registers a listener to be notified when the specified feature flag's value changes
     * @param flagKey the flag to listen for
     * @param listener the listener to register
     */
    fun registerFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        listenerManager.registerFeatureFlagListener(flagKey, listener)
    }
    
    /**
     * Unregisters a previously registered feature flag listener
     * @param flagKey the flag being listened to
     * @param listener the listener to unregister
     */
    fun unregisterFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        listenerManager.unregisterFeatureFlagListener(flagKey, listener)
    }
    
    /**
     * Registers a listener to be notified when any feature flag changes
     * @param listener the listener to register
     */
    fun registerAllFlagsListener(listener: AllFlagsListener) {
        listenerManager.registerAllFlagsListener(listener)
    }
    
    /**
     * Unregisters a previously registered all flags listener
     * @param listener the listener to unregister
     */
    fun unregisterAllFlagsListener(listener: AllFlagsListener) {
        listenerManager.unregisterAllFlagsListener(listener)
    }
    
    /**
     * Gets the current connection information
     */
    fun getConnectionInformation(): ConnectionInformation {
        return connectionManager.getConnectionInformation()
    }
    
    /**
     * Registers a connection status listener
     * @param listener the listener to register
     */
    fun addConnectionStatusListener(listener: ConnectionStatusListener) {
        connectionManager.addConnectionStatusListener(listener)
    }
    
    /**
     * Unregisters a connection status listener
     * @param listener the listener to unregister
     */
    fun removeConnectionStatusListener(listener: ConnectionStatusListener) {
        connectionManager.removeConnectionStatusListener(listener)
    }
    
    // USER PROPERTIES METHODS
    
    /**
     * Add a property to the user
     */
    fun addUserProperty(key: String, value: Any) {
        userManager.addUserProperty(key, value)
    }
    
    /**
     * Add a string property to the user
     */
    fun addStringProperty(key: String, value: String) {
        userManager.addStringProperty(key, value)
    }
    
    /**
     * Add a number property to the user
     */
    fun addNumberProperty(key: String, value: Number) {
        userManager.addNumberProperty(key, value)
    }
    
    /**
     * Add a boolean property to the user
     */
    fun addBooleanProperty(key: String, value: Boolean) {
        userManager.addBooleanProperty(key, value)
    }
    
    /**
     * Add a date property to the user
     */
    fun addDateProperty(key: String, value: Date) {
        userManager.addDateProperty(key, value)
    }
    
    /**
     * Add a geolocation property to the user
     */
    fun addGeoPointProperty(key: String, lat: Double, lon: Double) {
        userManager.addGeoPointProperty(key, lat, lon)
    }
    
    /**
     * Add a JSON property to the user
     */
    fun addJsonProperty(key: String, value: Map<String, Any>) {
        userManager.addJsonProperty(key, value)
    }
    
    /**
     * Add multiple properties to the user
     */
    fun addUserProperties(properties: Map<String, Any>) {
        userManager.addUserProperties(properties)
    }
    
    /**
     * Get all user properties
     */
    fun getUserProperties(): Map<String, Any> = userManager.getUserProperties()
    
    // CONTEXT METHODS
    
    /**
     * Add an evaluation context
     */
    fun addContext(context: EvaluationContext) {
        userManager.addContext(context)
    }
    
    /**
     * Remove an evaluation context
     */
    fun removeContext(type: ContextType, key: String) {
        userManager.removeContext(type, key)
    }
    
    /**
     * Get all evaluation contexts
     */
    fun getContexts(): List<EvaluationContext> = userManager.getContexts()
    
    // DEVICE AND APPLICATION INFO METHODS
    
    /**
     * Set the device context
     */
    fun setDeviceContext(deviceContext: DeviceContext) {
        userManager.setDeviceContext(deviceContext)
    }
    
    /**
     * Get the current device context
     */
    fun getDeviceContext(): DeviceContext = userManager.getDeviceContext()
    
    /**
     * Set the application info
     */
    fun setApplicationInfo(appInfo: ApplicationInfo) {
        userManager.setApplicationInfo(appInfo)
    }
    
    /**
     * Get the current application info
     */
    fun getApplicationInfo(): ApplicationInfo? = userManager.getApplicationInfo()
    
    /**
     * Increment the application launch count
     */
    fun incrementAppLaunchCount() {
        userManager.incrementAppLaunchCount()
    }
    
    // CONFIG VALUE ACCESSORS
    
    /**
     * Get a string configuration value
     */
    fun getString(key: String, fallbackValue: String): String =
        configManager.getConfigValue(key, fallbackValue) { it is String }
    
    /**
     * Get a string configuration value with callback
     */
    fun getString(
        key: String,
        fallbackValue: String,
        callback: ((String) -> Unit)? = null
    ): String {
        val value = getString(key, fallbackValue)
        callback?.invoke(value)
        return value
    }
    
    /**
     * Get a number configuration value
     */
    fun getNumber(key: String, fallbackValue: Number): Number =
        configManager.getConfigValue(key, fallbackValue) { it is Number }
    
    /**
     * Get a number configuration value with callback
     */
    fun getNumber(
        key: String,
        fallbackValue: Number,
        callback: ((Number) -> Unit)? = null
    ): Number {
        val value = getNumber(key, fallbackValue)
        callback?.invoke(value)
        return value
    }
    
    /**
     * Get a boolean configuration value
     */
    fun getBoolean(key: String, fallbackValue: Boolean): Boolean =
        configManager.getConfigValue(key, fallbackValue) { it is Boolean }
    
    /**
     * Get a boolean configuration value with callback
     */
    fun getBoolean(
        key: String,
        fallbackValue: Boolean,
        callback: ((Boolean) -> Unit)? = null
    ): Boolean {
        val value = getBoolean(key, fallbackValue)
        callback?.invoke(value)
        return value
    }
    
    /**
     * Get a JSON configuration value
     */
    fun getJson(key: String, fallbackValue: Map<String, Any>): Map<String, Any> =
        configManager.getConfigValue(key, fallbackValue) {
            it is Map<*, *> && it.keys.all { k -> k is String }
        }
    
    /**
     * Get a JSON configuration value with callback
     */
    fun getJson(
        key: String,
        fallbackValue: Map<String, Any>,
        callback: ((Map<String, Any>) -> Unit)? = null
    ): Map<String, Any> {
        val value = getJson(key, fallbackValue)
        callback?.invoke(value)
        return value
    }
    
    // EVENT TRACKING
    
    /**
     * Tracks an event
     * @param eventName The name of the event
     * @param properties Map of event properties
     * @return CFResult containing EventData on success or error details on failure
     */
    fun trackEvent(eventName: String, properties: Map<String, Any> = emptyMap()): CFResult<EventData> {
        try {
            // Validate event name
            if (eventName.isBlank()) {
                val message = "Event name cannot be blank"
                ErrorHandler.handleError(
                    message,
                    SOURCE,
                    ErrorHandler.ErrorCategory.VALIDATION,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
                return CFResult.error(message, category = ErrorHandler.ErrorCategory.VALIDATION)
            }
            
            // Use the event tracker's updated method that returns CFResult
            return eventTracker.trackEvent(eventName, properties)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Unexpected error tracking event: $eventName",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            return CFResult.error(
                "Failed to track event",
                e,
                category = ErrorHandler.ErrorCategory.INTERNAL
            )
        }
    }
    
    /**
     * Tracks an event using a property builder
     * @param eventName The name of the event
     * @param propertiesBuilder Builder function for event properties
     * @return CFResult containing EventData on success or error details on failure
     */
    fun trackEvent(eventName: String, propertiesBuilder: EventPropertiesBuilder.() -> Unit): CFResult<EventData> {
        try {
            val properties = EventPropertiesBuilder().apply(propertiesBuilder).build()
            return trackEvent(eventName, properties)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Error building properties for event: $eventName",
                SOURCE,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            return CFResult.error(
                "Failed to build event properties",
                e,
                category = ErrorHandler.ErrorCategory.VALIDATION
            )
        }
    }
    
    // OFFLINE MODE
    
    /**
     * Returns whether the client is in offline mode
     * @return true if the client is in offline mode
     */
    fun isOffline(): Boolean = configFetcher.isOffline()
    
    /**
     * Puts the client in offline mode, preventing network requests
     */
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
     * Restores the client to online mode, allowing network requests
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
    
    // CONFIGURATION UPDATES
    
    /**
     * Updates the SDK settings check interval
     * @param intervalMs the new interval in milliseconds
     */
    fun updateSdkSettingsCheckInterval(intervalMs: Long) {
        require(intervalMs > 0) { "Interval must be greater than 0" }
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                errorMessage = "Failed to update SDK settings check interval"
            ) { 
                mutableConfig.setSdkSettingsCheckIntervalMs(intervalMs)
                configManager.restartPeriodicSdkSettingsCheck(intervalMs)
            }
            .onFailure { e ->
                Timber.e(e, "Failed to update SDK settings check interval: ${e.message}")
            }
        }
    }
    
    /**
     * Updates the events flush interval
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
     * Updates the network connection timeout
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
     * Updates the network read timeout
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
     * Updates the debug logging setting
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
    
    /**
     * Enables automatic environment attributes collection
     */
    fun enableAutoEnvAttributes() {
        clientScope.launch {
            CoroutineUtils.withErrorHandling(
                errorMessage = "Failed to enable auto environment attributes"
            ) {
                mutableConfig.setAutoEnvAttributesEnabled(true)
                environmentManager.detectEnvironmentInfo(true)
                Timber.d("Auto environment attributes collection enabled")
            }
            .onFailure { e ->
                Timber.e(e, "Failed to enable auto environment attributes: ${e.message}")
            }
        }
    }
    
    /**
     * Disables automatic environment attributes collection
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
    
    /**
     * Gets the mutable configuration
     */
    fun getMutableConfig(): MutableCFConfig = mutableConfig
    
    /**
     * Returns a map of all feature flags with their current values
     */
    fun getAllFlags(): Map<String, Any> = configManager.getAllFlags()
    
    /**
     * Clean up resources when the client is no longer needed
     */
    fun shutdown() {
        Timber.i("Shutting down CF client")
        
        // Cancel client scope
        clientScope.cancel()
        
        // Shutdown managers
        configManager.shutdown()
        connectionManager.shutdown()
        environmentManager.shutdown()
        
        // Clear listeners
        listenerManager.clearAllListeners()
        
        // Flush any pending events and summaries
        clientScope.launch {
            CoroutineUtils.withErrorHandling(errorMessage = "Error flushing during shutdown") {
                eventTracker.flushEvents()
                summaryManager.flushSummaries()
                    .onError { error ->
                        Timber.w("Failed to flush summaries during shutdown: ${error.error}")
                    }
            }
            .onFailure { e ->
                Timber.e(e, "Failed to flush events during shutdown: ${e.message}")
            }
        }
    }
    
    /**
     * Force a refresh of the configuration.
     * This will force the SDK to fetch new configuration regardless of the Last-Modified header.
     */
    suspend fun forceRefresh() {
        CoroutineUtils.withErrorHandling(errorMessage = "Force refresh failed") {
            configManager.forceRefresh()
        }
        .onFailure { e ->
            Timber.e(e, "Force refresh failed: ${e.message}")
        }
    }
    
    companion object {
        private const val SOURCE = "CFClient"
        
        /**
         * Create a new instance of the modular CFClient
         */
        fun init(cfConfig: CFConfig, user: CFUser): CFClient {
            return CFClient(cfConfig, user)
        }
    }
} 