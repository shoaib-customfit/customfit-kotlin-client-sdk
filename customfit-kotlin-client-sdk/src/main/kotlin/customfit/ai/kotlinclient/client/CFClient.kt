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
import customfit.ai.kotlinclient.core.session.SessionManager
import customfit.ai.kotlinclient.core.session.SessionConfig
import customfit.ai.kotlinclient.core.session.SessionRotationListener
import customfit.ai.kotlinclient.core.session.RotationReason
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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Modular implementation of the CustomFit client SDK
 * 
 * This class serves as a facade that delegates operations to specialized manager classes.
 */
class CFClient private constructor(cfConfig: CFConfig, initialUser: CFUser) {
    private val mutableConfig = MutableCFConfig(cfConfig)
    private val httpClient = HttpClient(cfConfig)
    
    // Client scope for coroutines
    private val clientScope = CoroutineUtils.createScope(Dispatchers.IO)
    
    // Used to track initialization of SDK settings
    private val sdkSettingsDeferred: CompletableDeferred<Unit> = CompletableDeferred()
    
    // Session management
    private var sessionManager: SessionManager? = null
    private var currentSessionId: String = UUID.randomUUID().toString() // Fallback until SessionManager initializes
    
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
    
    // API managers (will be updated with SessionManager session ID)
    val summaryManager = SummaryManager(currentSessionId, httpClient, initialUser, cfConfig)
    val eventTracker = EventTracker(currentSessionId, httpClient, initialUser, summaryManager, cfConfig)
    private val configFetcher = ConfigFetcher(httpClient, cfConfig, initialUser)
    private val configManager: ConfigManager = ConfigManagerImpl(
        configFetcher,
        clientScope,
        listenerManager,
        cfConfig,
        summaryManager
    )

    init {
        // Configure logger with the log level from config
        
        // Initialize SessionManager
        initializeSessionManager()
        
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
     * Initialize SessionManager with configuration
     */
    private fun initializeSessionManager() {
        clientScope.launch {
            try {
                // Create session configuration based on CFConfig
                val sessionConfig = SessionConfig(
                    maxSessionDurationMs = TimeUnit.MINUTES.toMillis(60), // 1 hour default
                    minSessionDurationMs = TimeUnit.MINUTES.toMillis(5),  // 5 minutes minimum
                    backgroundThresholdMs = TimeUnit.MINUTES.toMillis(15), // 15 minutes background threshold
                    rotateOnAppRestart = true,
                    rotateOnAuthChange = true,
                    sessionIdPrefix = "cf_session",
                    enableTimeBasedRotation = true
                )
                
                // Initialize SessionManager with storage
                val result = SessionManager.initialize(sessionConfig)
                
                when (result) {
                    is CFResult.Success -> {
                        sessionManager = result.data
                        
                        // Get the current session ID
                        currentSessionId = sessionManager!!.getCurrentSessionId()
                        
                        // Update existing managers with new session ID
                        updateSessionIdInManagers(currentSessionId)
                        
                        // Set up session rotation listener
                        sessionManager!!.addListener(object : SessionRotationListener {
                            override fun onSessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
                                Timber.i("🔄 Session rotated: $oldSessionId -> $newSessionId (${reason.description})")
                                currentSessionId = newSessionId
                                updateSessionIdInManagers(newSessionId)
                                
                                // Track session rotation event
                                trackSessionRotationEvent(oldSessionId, newSessionId, reason)
                            }
                            
                            override fun onSessionRestored(sessionId: String) {
                                Timber.i("🔄 Session restored: $sessionId")
                                currentSessionId = sessionId
                                updateSessionIdInManagers(sessionId)
                            }
                            
                            override fun onSessionError(error: String) {
                                Timber.e("🔄 Session error: $error")
                            }
                        })
                        
                        Timber.i("🔄 SessionManager initialized with session: $currentSessionId")
                    }
                    is CFResult.Error -> {
                        Timber.e("Failed to initialize SessionManager: ${result.error}")
                    }
                }
            } catch (e: Exception) {
                Timber.e(e, "Exception initializing SessionManager: ${e.message}")
            }
        }
    }
    
    /**
     * Update session ID in all managers that use it
     */
    private fun updateSessionIdInManagers(sessionId: String) {
        try {
            // TODO: EventTracker and SummaryManager don't have updateSessionId methods
            // These would need to be enhanced to support dynamic session ID updates
            // For now, we'll just log the session change
            
            // summaryManager.updateSessionId(sessionId)
            // eventTracker.updateSessionId(sessionId)
            
            Timber.d("Updated session ID in managers: $sessionId")
        } catch (e: Exception) {
            Timber.e(e, "Error updating session ID in managers: ${e.message}")
        }
    }
    
    /**
     * Track session rotation as an analytics event
     */
    private fun trackSessionRotationEvent(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
        try {
            val properties = mapOf(
                "old_session_id" to (oldSessionId ?: "none"),
                "new_session_id" to newSessionId,
                "rotation_reason" to reason.description,
                "timestamp" to System.currentTimeMillis()
            )
            
            trackEvent("cf_session_rotated", properties)
        } catch (e: Exception) {
            Timber.e(e, "Error tracking session rotation event: ${e.message}")
        }
    }
    
    /**
     * Wait for SDK settings to be initialized
     * This is a suspend function that will wait until the SDK settings have been fetched and processed
     * 
     * @return Unit if successful, throws exception if SDK settings initialization failed
     */
    private suspend fun awaitSdkSettingsCheck() = sdkSettingsDeferred.await()
    
    /**
     * Set up background state monitoring
     */
    private fun setupBackgroundStateMonitoring() {
        environmentManager.addAppStateListener(
            object : AppStateListener {
                override fun onAppStateChange(state: AppState) {
                    Timber.d("App state changed: $state")
                    
                    // Handle session lifecycle based on app state
                    clientScope.launch {
                        when (state) {
                            AppState.BACKGROUND -> {
                                // Notify SessionManager about background transition
                                sessionManager?.onAppBackground()
                                
                                // Pause polling in background if configured to do so
                                if (mutableConfig.disableBackgroundPolling) {
                                    configManager.pausePolling()
                                }
                            }
                            AppState.FOREGROUND -> {
                                // Notify SessionManager about foreground transition
                                sessionManager?.onAppForeground()
                                
                                // Update session activity
                                sessionManager?.updateActivity()
                                
                                // Resume polling when app comes to foreground
                                configManager.resumePolling()
                                
                                // Check for updates immediately when coming to foreground
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
     * Add a listener to be notified when the specified feature flag's value changes
     * @param flagKey the flag to listen for
     * @param listener the listener to add
     */
    fun addFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        listenerManager.registerFeatureFlagListener(flagKey, listener)
    }
    
    /**
     * Remove a previously added feature flag listener
     * @param flagKey the flag being listened to
     * @param listener the listener to remove
     */
    fun removeFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener) {
        listenerManager.unregisterFeatureFlagListener(flagKey, listener)
    }
    
    /**
     * Add a listener to be notified when any feature flag changes
     * @param listener the listener to add
     */
    fun addAllFlagsListener(listener: AllFlagsListener) {
        listenerManager.registerAllFlagsListener(listener)
    }
    
    /**
     * Remove a previously added all flags listener
     * @param listener the listener to remove
     */
    fun removeAllFlagsListener(listener: AllFlagsListener) {
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
    
    /**
     * Manually flushes the events queue to the server
     * Useful for immediately sending tracked events without waiting for the automatic flush
     * 
     * @return CFResult containing the number of events flushed or error details
     */
    fun flushEvents(): CFResult<Int> {
        return try {
            var result: CFResult<Int>? = null
            val latch = CountDownLatch(1)
            
            // Use clientScope to perform the flush operation
            clientScope.launch {
                CoroutineUtils.withErrorHandling(errorMessage = "Error flushing events") {
                    result = eventTracker.flushEvents()
                    latch.countDown()
                }
                .onFailure { e ->
                    Timber.e(e, "Failed to flush events: ${e.message}")
                    result = CFResult.error(
                        "Failed to flush events",
                        e,
                        category = ErrorHandler.ErrorCategory.INTERNAL
                    )
                    latch.countDown()
                }
            }
            
            // Wait for the operation to complete with a reasonable timeout
            latch.await(5, TimeUnit.SECONDS)
            
            result ?: CFResult.error(
                "Event flush operation timed out",
                category = ErrorHandler.ErrorCategory.INTERNAL
            )
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Unexpected error flushing events",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            CFResult.error(
                "Failed to flush events",
                e,
                category = ErrorHandler.ErrorCategory.INTERNAL
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
     * Enables automatic environment attributes collection
     */
    private fun enableAutoEnvAttributes() {
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
    private fun disableAutoEnvAttributes() {
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
        
        // Shutdown SessionManager
        clientScope.launch {
            try {
                SessionManager.shutdown()
                sessionManager = null
            } catch (e: Exception) {
                Timber.e(e, "Error shutting down SessionManager: ${e.message}")
            }
        }
        
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
    
    // SESSION MANAGEMENT METHODS
    
    /**
     * Get the current session ID
     * @return The current session ID
     */
    suspend fun getCurrentSessionId(): String {
        return sessionManager?.getCurrentSessionId() ?: currentSessionId
    }
    
    /**
     * Get current session data with metadata
     * @return SessionData object with session information or null if not available
     */
    suspend fun getCurrentSessionData(): customfit.ai.kotlinclient.core.session.SessionData? {
        return sessionManager?.getCurrentSession()
    }
    
    /**
     * Force session rotation with a manual trigger
     * @return The new session ID after rotation
     */
    suspend fun forceSessionRotation(): String? {
        return sessionManager?.forceRotation()
    }
    
    /**
     * Update session activity (should be called on user interactions)
     * This helps maintain session continuity by updating the last active timestamp
     */
    suspend fun updateSessionActivity() {
        sessionManager?.updateActivity()
    }
    
    /**
     * Handle user authentication changes
     * This will trigger session rotation if configured to do so
     * 
     * @param userId The new user ID (null if user logged out)
     */
    suspend fun onUserAuthenticationChange(userId: String?) {
        sessionManager?.onAuthenticationChange(userId)
    }
    
    /**
     * Get session statistics for debugging and monitoring
     * @return Map containing session statistics
     */
    suspend fun getSessionStatistics(): Map<String, Any> {
        return sessionManager?.getSessionStats() ?: mapOf(
            "hasActiveSession" to false,
            "sessionId" to currentSessionId,
            "sessionManagerInitialized" to false
        )
    }
    
    /**
     * Add a session rotation listener to be notified of session changes
     * @param listener The listener to add
     */
    fun addSessionRotationListener(listener: SessionRotationListener) {
        sessionManager?.addListener(listener)
    }
    
    /**
     * Remove a session rotation listener
     * @param listener The listener to remove
     */
    fun removeSessionRotationListener(listener: SessionRotationListener) {
        sessionManager?.removeListener(listener)
    }
    
    companion object {
        private const val SOURCE = "CFClient"
        
        // Singleton implementation
        @Volatile
        private var instance: CFClient? = null
        private val initializationMutex = Mutex()
        
        // Track initialization state
        @Volatile
        private var isInitializing = false
        private var initializationDeferred: CompletableDeferred<CFClient>? = null
        
        /**
         * Initialize or get the singleton instance of CFClient
         * This method ensures only one instance exists and handles concurrent initialization attempts
         * 
         * @param cfConfig The configuration for the client
         * @param user The initial user for the client
         * @return The singleton CFClient instance
         */
        suspend fun init(cfConfig: CFConfig, user: CFUser): CFClient {
            // Fast path: if already initialized, return existing instance
            instance?.let { existingInstance ->
                Timber.i("CFClient singleton already exists, returning existing instance")
                return existingInstance
            }
            
            // Use mutex to ensure thread-safe initialization
            return initializationMutex.withLock {
                // Double-check after acquiring lock
                instance?.let { existingInstance ->
                    Timber.i("CFClient singleton found after lock, returning existing instance")
                    return@withLock existingInstance
                }
                
                // If currently initializing, wait for existing initialization
                if (isInitializing && initializationDeferred != null) {
                    Timber.i("CFClient initialization in progress, waiting for completion...")
                    return@withLock initializationDeferred!!.await()
                }
                
                // Start new initialization
                Timber.i("Starting CFClient singleton initialization...")
                isInitializing = true
                val deferred = CompletableDeferred<CFClient>()
                initializationDeferred = deferred
                
                try {
                    // Create the instance
                    val newInstance = CFClient(cfConfig, user)
                    
                    // Wait for SDK settings initialization to complete
                    newInstance.awaitSdkSettingsCheck()
                    
                    // Store the singleton instance
                    instance = newInstance
                    isInitializing = false
                    
                    Timber.i("CFClient singleton initialized successfully")
                    deferred.complete(newInstance)
                    newInstance
                } catch (e: Exception) {
                    isInitializing = false
                    initializationDeferred = null
                    
                    Timber.e(e, "Failed to initialize CFClient singleton")
                    deferred.completeExceptionally(e)
                    throw e
                }
            }
        }
        
        /**
         * Get the current singleton instance if it exists
         * 
         * @return The current CFClient instance or null if not initialized
         */
        fun getInstance(): CFClient? {
            return instance
        }
        
        /**
         * Check if the singleton instance is initialized
         * 
         * @return true if the client is initialized, false otherwise
         */
        fun isInitialized(): Boolean {
            return instance != null
        }
        
        /**
         * Check if initialization is currently in progress
         * 
         * @return true if initialization is in progress, false otherwise
         */
        fun isInitializing(): Boolean {
            return isInitializing
        }
        
        /**
         * Shutdown and clear the singleton instance
         * This should be called when the application is shutting down or when you need to reinitialize with different parameters
         */
        suspend fun shutdown() {
            initializationMutex.withLock {
                instance?.let { client ->
                    Timber.i("Shutting down CFClient singleton...")
                    client.shutdown()
                    instance = null
                    isInitializing = false
                    initializationDeferred = null
                    Timber.i("CFClient singleton shutdown complete")
                }
            }
        }
        
        /**
         * Force reinitialize the singleton with new configuration
         * This will shutdown the existing instance and create a new one
         * 
         * @param cfConfig The new configuration for the client
         * @param user The new user for the client
         * @return The new CFClient singleton instance
         */
        suspend fun reinitialize(cfConfig: CFConfig, user: CFUser): CFClient {
            Timber.i("Reinitializing CFClient singleton...")
            shutdown()
            return init(cfConfig, user)
        }
        
        /**
         * Create a detached (non-singleton) instance of CFClient
         * Use this only if you specifically need multiple instances (not recommended)
         * Most applications should use init() for singleton pattern
         * 
         * @param cfConfig The configuration for the client
         * @param user The initial user for the client
         * @return A new CFClient instance (not managed by singleton pattern)
         */
        fun createDetached(cfConfig: CFConfig, user: CFUser): CFClient {
            Timber.w("Creating detached CFClient instance - this bypasses singleton pattern!")
            return CFClient(cfConfig, user)
        }
    }
} 