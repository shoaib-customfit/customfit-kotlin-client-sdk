package customfit.ai.kotlinclient.config.core

import customfit.ai.kotlinclient.constants.CFConstants
import customfit.ai.kotlinclient.logging.Timber
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import java.util.Base64

@Serializable
data class CFConfig(
        val clientKey: String,
        // Event tracker configuration
        val eventsQueueSize: Int = CFConstants.EventDefaults.QUEUE_SIZE,
        val eventsFlushTimeSeconds: Int = CFConstants.EventDefaults.FLUSH_TIME_SECONDS,
        val eventsFlushIntervalMs: Long = CFConstants.EventDefaults.FLUSH_INTERVAL_MS,
        // Retry configuration
        val maxRetryAttempts: Int = CFConstants.RetryConfig.MAX_RETRY_ATTEMPTS,
        val retryInitialDelayMs: Long = CFConstants.RetryConfig.INITIAL_DELAY_MS,
        val retryMaxDelayMs: Long = CFConstants.RetryConfig.MAX_DELAY_MS,
        val retryBackoffMultiplier: Double = CFConstants.RetryConfig.BACKOFF_MULTIPLIER,
        // Summary manager configuration
        val summariesQueueSize: Int = CFConstants.SummaryDefaults.QUEUE_SIZE,
        val summariesFlushTimeSeconds: Int = CFConstants.SummaryDefaults.FLUSH_TIME_SECONDS,
        val summariesFlushIntervalMs: Long = CFConstants.SummaryDefaults.FLUSH_INTERVAL_MS,
        // SDK settings check configuration
        val sdkSettingsCheckIntervalMs: Long = CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS,
        // Network configuration
        val networkConnectionTimeoutMs: Int = CFConstants.Network.CONNECTION_TIMEOUT_MS,
        val networkReadTimeoutMs: Int = CFConstants.Network.READ_TIMEOUT_MS,
        // Logging configuration
        val loggingEnabled: Boolean = true,
        val debugLoggingEnabled: Boolean = false,
        val logLevel: String = CFConstants.Logging.DEFAULT_LOG_LEVEL,
        // Offline mode - when true, no network requests will be made
        val offlineMode: Boolean = false,
        // Background operation settings
        val disableBackgroundPolling: Boolean = false,
        val backgroundPollingIntervalMs: Long = CFConstants.BackgroundPolling.BACKGROUND_POLLING_INTERVAL_MS,
        val useReducedPollingWhenBatteryLow: Boolean = true,
        val reducedPollingIntervalMs: Long = CFConstants.BackgroundPolling.REDUCED_POLLING_INTERVAL_MS,
        val maxStoredEvents: Int = CFConstants.EventDefaults.MAX_STORED_EVENTS,
        // Auto environment attributes enabled - when true, automatically collect device and app
        // info
        val autoEnvAttributesEnabled: Boolean = false
) {
    val dimensionId: String? by lazy { extractDimensionIdFromToken(clientKey) }

    companion object {
        fun fromClientKey(clientKey: String): CFConfig = CFConfig(clientKey)

        // For backward compatibility with less verbose configuration
        fun fromClientKey(
                clientKey: String,
                eventsQueueSize: Int = CFConstants.EventDefaults.QUEUE_SIZE,
                eventsFlushTimeSeconds: Int = CFConstants.EventDefaults.FLUSH_TIME_SECONDS,
                eventsFlushIntervalMs: Long = CFConstants.EventDefaults.FLUSH_INTERVAL_MS,
                summariesQueueSize: Int = CFConstants.SummaryDefaults.QUEUE_SIZE,
                summariesFlushTimeSeconds: Int = CFConstants.SummaryDefaults.FLUSH_TIME_SECONDS,
                summariesFlushIntervalMs: Long = CFConstants.SummaryDefaults.FLUSH_INTERVAL_MS
        ): CFConfig =
                CFConfig(
                        clientKey = clientKey,
                        eventsQueueSize = eventsQueueSize,
                        eventsFlushTimeSeconds = eventsFlushTimeSeconds,
                        eventsFlushIntervalMs = eventsFlushIntervalMs,
                        summariesQueueSize = summariesQueueSize,
                        summariesFlushTimeSeconds = summariesFlushTimeSeconds,
                        summariesFlushIntervalMs = summariesFlushIntervalMs
                )

        private fun extractDimensionIdFromToken(token: String): String? {
            return try {
                val parts = token.split(".")
                if (parts.size != 3) {
                    Timber.w("Invalid JWT structure: $token")
                    return null
                }
                val payload =
                        parts[1].let {
                            val rem = it.length % 4
                            if (rem == 0) it else it + "=".repeat(4 - rem)
                        }
                val decodedBytes = Base64.getUrlDecoder().decode(payload)
                val decodedString = String(decodedBytes, Charsets.UTF_8)

                val jsonElement = Json.parseToJsonElement(decodedString)
                if (jsonElement is JsonObject) {
                    jsonElement["dimension_id"]?.jsonPrimitive?.contentOrNull
                } else {
                    Timber.w("Decoded JWT payload is not a JSON object: $decodedString")
                    null
                }
            } catch (e: Exception) {
                Timber.e(e, "JWT decoding error: ${e.javaClass.simpleName} - ${e.message}")
                null
            }
        }
    }

    /** Creates a builder for configuring CFConfig instances */
    class Builder(private val clientKey: String) {
        private var eventsQueueSize: Int = CFConstants.EventDefaults.QUEUE_SIZE
        private var eventsFlushTimeSeconds: Int = CFConstants.EventDefaults.FLUSH_TIME_SECONDS
        private var eventsFlushIntervalMs: Long = CFConstants.EventDefaults.FLUSH_INTERVAL_MS
        private var maxRetryAttempts: Int = CFConstants.RetryConfig.MAX_RETRY_ATTEMPTS
        private var retryInitialDelayMs: Long = CFConstants.RetryConfig.INITIAL_DELAY_MS
        private var retryMaxDelayMs: Long = CFConstants.RetryConfig.MAX_DELAY_MS
        private var retryBackoffMultiplier: Double = CFConstants.RetryConfig.BACKOFF_MULTIPLIER
        private var summariesQueueSize: Int = CFConstants.SummaryDefaults.QUEUE_SIZE
        private var summariesFlushTimeSeconds: Int = CFConstants.SummaryDefaults.FLUSH_TIME_SECONDS
        private var summariesFlushIntervalMs: Long = CFConstants.SummaryDefaults.FLUSH_INTERVAL_MS
        private var sdkSettingsCheckIntervalMs: Long = CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS
        private var networkConnectionTimeoutMs: Int = CFConstants.Network.CONNECTION_TIMEOUT_MS
        private var networkReadTimeoutMs: Int = CFConstants.Network.READ_TIMEOUT_MS
        private var loggingEnabled: Boolean = true
        private var debugLoggingEnabled: Boolean = false
        private var logLevel: String = CFConstants.Logging.DEFAULT_LOG_LEVEL
        private var offlineMode: Boolean = false
        private var disableBackgroundPolling: Boolean = false
        private var backgroundPollingIntervalMs: Long = CFConstants.BackgroundPolling.BACKGROUND_POLLING_INTERVAL_MS
        private var useReducedPollingWhenBatteryLow: Boolean = true
        private var reducedPollingIntervalMs: Long = CFConstants.BackgroundPolling.REDUCED_POLLING_INTERVAL_MS
        private var maxStoredEvents: Int = CFConstants.EventDefaults.MAX_STORED_EVENTS
        private var autoEnvAttributesEnabled: Boolean = false

        fun eventsQueueSize(size: Int) = apply { this.eventsQueueSize = size }
        fun eventsFlushTimeSeconds(seconds: Int) = apply { this.eventsFlushTimeSeconds = seconds }
        fun eventsFlushIntervalMs(ms: Long) = apply { this.eventsFlushIntervalMs = ms }
        fun maxRetryAttempts(attempts: Int) = apply { 
            require(attempts >= 0) { "Max retry attempts must be non-negative" }
            this.maxRetryAttempts = attempts 
        }
        fun retryInitialDelayMs(delayMs: Long) = apply { 
            require(delayMs > 0) { "Initial delay must be positive" }
            this.retryInitialDelayMs = delayMs 
        }
        fun retryMaxDelayMs(delayMs: Long) = apply { 
            require(delayMs > 0) { "Max delay must be positive" }
            this.retryMaxDelayMs = delayMs 
        }
        fun retryBackoffMultiplier(multiplier: Double) = apply { 
            require(multiplier > 1.0) { "Backoff multiplier must be greater than 1.0" }
            this.retryBackoffMultiplier = multiplier 
        }
        fun summariesQueueSize(size: Int) = apply { this.summariesQueueSize = size }
        fun summariesFlushTimeSeconds(seconds: Int) = apply {
            this.summariesFlushTimeSeconds = seconds
        }
        fun summariesFlushIntervalMs(ms: Long) = apply { this.summariesFlushIntervalMs = ms }
        fun sdkSettingsCheckIntervalMs(ms: Long) = apply { this.sdkSettingsCheckIntervalMs = ms }
        fun networkConnectionTimeoutMs(ms: Int) = apply { this.networkConnectionTimeoutMs = ms }
        fun networkReadTimeoutMs(ms: Int) = apply { this.networkReadTimeoutMs = ms }
        fun loggingEnabled(enabled: Boolean) = apply { this.loggingEnabled = enabled }
        fun debugLoggingEnabled(enabled: Boolean) = apply { this.debugLoggingEnabled = enabled }
        
        /**
         * Set the log level for the SDK.
         * Valid values: ERROR, WARN, INFO, DEBUG, TRACE
         * Default: DEBUG
         */
        fun logLevel(level: String) = apply { 
            require(level in CFConstants.Logging.VALID_LOG_LEVELS) { 
                "Log level must be one of: ${CFConstants.Logging.VALID_LOG_LEVELS.joinToString()}" 
            }
            this.logLevel = level 
        }
        
        fun offlineMode(enabled: Boolean) = apply { this.offlineMode = enabled }
        fun disableBackgroundPolling(disable: Boolean) = apply {
            this.disableBackgroundPolling = disable
        }
        fun backgroundPollingIntervalMs(intervalMs: Long) = apply {
            require(intervalMs > 0) { "Interval must be greater than 0" }
            this.backgroundPollingIntervalMs = intervalMs
        }
        fun useReducedPollingWhenBatteryLow(useReduced: Boolean) = apply {
            this.useReducedPollingWhenBatteryLow = useReduced
        }
        fun reducedPollingIntervalMs(intervalMs: Long) = apply {
            require(intervalMs > 0) { "Interval must be greater than 0" }
            this.reducedPollingIntervalMs = intervalMs
        }
        fun maxStoredEvents(maxEvents: Int) = apply {
            require(maxEvents > 0) { "Max stored events must be greater than 0" }
            this.maxStoredEvents = maxEvents
        }

        /**
         * Enable or disable automatic environment attributes collection When enabled, device
         * context and application info will be automatically detected
         */
        fun autoEnvAttributesEnabled(enabled: Boolean) = apply {
            this.autoEnvAttributesEnabled = enabled
        }

        fun build(): CFConfig =
                CFConfig(
                        clientKey = clientKey,
                        eventsQueueSize = eventsQueueSize,
                        eventsFlushTimeSeconds = eventsFlushTimeSeconds,
                        eventsFlushIntervalMs = eventsFlushIntervalMs,
                        maxRetryAttempts = maxRetryAttempts,
                        retryInitialDelayMs = retryInitialDelayMs,
                        retryMaxDelayMs = retryMaxDelayMs,
                        retryBackoffMultiplier = retryBackoffMultiplier,
                        summariesQueueSize = summariesQueueSize,
                        summariesFlushTimeSeconds = summariesFlushTimeSeconds,
                        summariesFlushIntervalMs = summariesFlushIntervalMs,
                        sdkSettingsCheckIntervalMs = sdkSettingsCheckIntervalMs,
                        networkConnectionTimeoutMs = networkConnectionTimeoutMs,
                        networkReadTimeoutMs = networkReadTimeoutMs,
                        loggingEnabled = loggingEnabled,
                        debugLoggingEnabled = debugLoggingEnabled,
                        logLevel = logLevel,
                        offlineMode = offlineMode,
                        disableBackgroundPolling = disableBackgroundPolling,
                        backgroundPollingIntervalMs = backgroundPollingIntervalMs,
                        useReducedPollingWhenBatteryLow = useReducedPollingWhenBatteryLow,
                        reducedPollingIntervalMs = reducedPollingIntervalMs,
                        maxStoredEvents = maxStoredEvents,
                        autoEnvAttributesEnabled = autoEnvAttributesEnabled
                )
    }
} 