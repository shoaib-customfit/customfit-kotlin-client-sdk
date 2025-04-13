    package customfit.ai.kotlinclient.core

    import java.util.*
    import kotlinx.serialization.Serializable
    import mu.KotlinLogging
    import org.json.JSONObject

    private val logger = KotlinLogging.logger {}

    @Serializable
    data class CFConfig(
        val clientKey: String,
        // Event tracker configuration
        val eventsQueueSize: Int = 100,
        val eventsFlushTimeSeconds: Int = 60,
        val eventsFlushIntervalMs: Long = 1000L,
        // Summary manager configuration
        val summariesQueueSize: Int = 100,
        val summariesFlushTimeSeconds: Int = 60,
        val summariesFlushIntervalMs: Long = 60_000L,
        // SDK settings check configuration
        val sdkSettingsCheckIntervalMs: Long = 300_000,  // 5 minutes
        // Network configuration
        val networkConnectionTimeoutMs: Int = 10_000,  // 10 seconds
        val networkReadTimeoutMs: Int = 10_000,        // 10 seconds
        // Logging configuration
        val loggingEnabled: Boolean = true,
        val debugLoggingEnabled: Boolean = false
    ) {
        val dimensionId: String? by lazy { extractDimensionIdFromToken(clientKey) }

        companion object {
            fun fromClientKey(clientKey: String): CFConfig = CFConfig(clientKey)

            // For backward compatibility with less verbose configuration
            fun fromClientKey(
                clientKey: String,
                eventsQueueSize: Int = 100,
                eventsFlushTimeSeconds: Int = 60,
                eventsFlushIntervalMs: Long = 1000L,
                summariesQueueSize: Int = 100,
                summariesFlushTimeSeconds: Int = 60,
                summariesFlushIntervalMs: Long = 60_000L
            ): CFConfig = CFConfig(
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
                        logger.warn { "Invalid JWT structure: $token" }
                        return null
                    }
                    val payload = parts[1].padEnd((parts[1].length + 3) / 4 * 4, '=')
                    val decodedBytes = Base64.getUrlDecoder().decode(payload)
                    val decodedString = String(decodedBytes)
                    JSONObject(decodedString).optString("dimension_id", null)
                } catch (e: Exception) {
                    logger.error(e) { "JWT decoding error: ${e.javaClass.simpleName} - ${e.message}" }
                    null
                }
            }
        }
        
        /**
         * Creates a builder for configuring CFConfig instances
         */
        class Builder(private val clientKey: String) {
            private var eventsQueueSize: Int = 100
            private var eventsFlushTimeSeconds: Int = 60
            private var eventsFlushIntervalMs: Long = 1000L
            private var summariesQueueSize: Int = 100
            private var summariesFlushTimeSeconds: Int = 60
            private var summariesFlushIntervalMs: Long = 60_000L
            private var sdkSettingsCheckIntervalMs: Long = 300_000
            private var networkConnectionTimeoutMs: Int = 10_000
            private var networkReadTimeoutMs: Int = 10_000
            private var loggingEnabled: Boolean = true
            private var debugLoggingEnabled: Boolean = false
            
            fun eventsQueueSize(size: Int) = apply { this.eventsQueueSize = size }
            fun eventsFlushTimeSeconds(seconds: Int) = apply { this.eventsFlushTimeSeconds = seconds }
            fun eventsFlushIntervalMs(ms: Long) = apply { this.eventsFlushIntervalMs = ms }
            fun summariesQueueSize(size: Int) = apply { this.summariesQueueSize = size }
            fun summariesFlushTimeSeconds(seconds: Int) = apply { this.summariesFlushTimeSeconds = seconds }
            fun summariesFlushIntervalMs(ms: Long) = apply { this.summariesFlushIntervalMs = ms }
            fun sdkSettingsCheckIntervalMs(ms: Long) = apply { this.sdkSettingsCheckIntervalMs = ms }
            fun networkConnectionTimeoutMs(ms: Int) = apply { this.networkConnectionTimeoutMs = ms }
            fun networkReadTimeoutMs(ms: Int) = apply { this.networkReadTimeoutMs = ms }
            fun loggingEnabled(enabled: Boolean) = apply { this.loggingEnabled = enabled }
            fun debugLoggingEnabled(enabled: Boolean) = apply { this.debugLoggingEnabled = enabled }
            
            fun build(): CFConfig = CFConfig(
                clientKey = clientKey,
                eventsQueueSize = eventsQueueSize,
                eventsFlushTimeSeconds = eventsFlushTimeSeconds,
                eventsFlushIntervalMs = eventsFlushIntervalMs,
                summariesQueueSize = summariesQueueSize,
                summariesFlushTimeSeconds = summariesFlushTimeSeconds,
                summariesFlushIntervalMs = summariesFlushIntervalMs,
                sdkSettingsCheckIntervalMs = sdkSettingsCheckIntervalMs,
                networkConnectionTimeoutMs = networkConnectionTimeoutMs,
                networkReadTimeoutMs = networkReadTimeoutMs,
                loggingEnabled = loggingEnabled,
                debugLoggingEnabled = debugLoggingEnabled
            )
        }
    }
