package customfit.ai.kotlinclient.analytics.summary

import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.core.error.ErrorHandler
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.core.util.RetryUtil.withRetry
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.network.HttpClient
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Collections
import java.util.Timer
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*

// Define formatter for the specific timestamp format needed by the server
private val summaryTimestampFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSSX").withZone(ZoneOffset.UTC)

// Helper function to serialize Any
private fun anyToJsonElement(value: Any?): JsonElement = when (value) {
    null -> JsonNull
    is String -> JsonPrimitive(value)
    is Number -> JsonPrimitive(value)
    is Boolean -> JsonPrimitive(value)
    is Map<*, *> -> buildJsonObject {
        value.forEach { (k, v) ->
            if (k is String) {
                put(k, anyToJsonElement(v))
            }
        }
    }
    is List<*> -> buildJsonArray {
        value.forEach { item ->
            add(anyToJsonElement(item))
        }
    }
    else -> JsonPrimitive(value.toString())
}

class SummaryManager(
    private val sessionId: String,
    private val httpClient: HttpClient,
    private val user: CFUser,
    private val cfConfig: CFConfig
) {
    companion object {
        private const val SOURCE = "SummaryManager"
    }
    
    // Use atomic values to allow thread-safe updates
    private val summariesQueueSize = cfConfig.summariesQueueSize
    private val summariesFlushTimeSeconds = cfConfig.summariesFlushTimeSeconds
    private val flushIntervalMs = AtomicLong(cfConfig.summariesFlushIntervalMs)

    private val summaries: LinkedBlockingQueue<CFConfigRequestSummary> = LinkedBlockingQueue(summariesQueueSize)
    private val summaryTrackMap = Collections.synchronizedMap(mutableMapOf<String, Boolean>())
    private val trackMutex = Mutex()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Timer management
    private var flushTimer: Timer? = null
    private val timerMutex = Mutex()

    init {
        Timber.i("SummaryManager initialized with summariesQueueSize=$summariesQueueSize, summariesFlushTimeSeconds=$summariesFlushTimeSeconds, flushIntervalMs=${flushIntervalMs.get()}")
        startPeriodicFlush()
    }

    /**
     * Updates the flush interval and restarts the timer with improved error handling
     *
     * @param intervalMs new interval in milliseconds
     * @return CFResult containing the updated interval or error details
     */
    suspend fun updateFlushInterval(intervalMs: Long): CFResult<Long> {
        try {
            require(intervalMs > 0) { "Interval must be greater than 0" }

            flushIntervalMs.set(intervalMs)
            restartPeriodicFlush()
            Timber.i("Updated summaries flush interval to $intervalMs ms")
            return CFResult.success(intervalMs)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Failed to update flush interval to $intervalMs",
                SOURCE,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            return CFResult.error(
                "Failed to update summaries flush interval", 
                e, 
                category = ErrorHandler.ErrorCategory.VALIDATION
            )
        }
    }

    /**
     * Adds a configuration summary to the queue with improved validation and error handling
     * 
     * @param config The configuration to summarize
     * @return CFResult indicating success or describing the error
     */
    fun pushSummary(config: Any): CFResult<Boolean> {
        // Validate input is a map
        if (config !is Map<*, *>) {
            val message = "Config is not a map: $config"
            ErrorHandler.handleError(
                message,
                SOURCE,
                ErrorHandler.ErrorCategory.VALIDATION,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            return CFResult.error(message, category = ErrorHandler.ErrorCategory.VALIDATION)
        }
        
        // Validate keys are strings
        val configMap = config.takeIf { it.keys.all { k -> k is String } }?.let {
            @Suppress("UNCHECKED_CAST") (it as Map<String, Any>).also {}
        } ?: run {
            val message = "Config map has non-string keys: $config"
            ErrorHandler.handleError(
                message,
                SOURCE,
                ErrorHandler.ErrorCategory.VALIDATION,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            return CFResult.error(message, category = ErrorHandler.ErrorCategory.VALIDATION)
        }

        // Log the config being processed
        Timber.i("📊 SUMMARY: Processing summary for config: ${configMap["key"] ?: "unknown"}")
        
        // Validate required fields are present
        val experienceId = configMap["experience_id"] as? String ?: run {
            val message = "Missing mandatory 'experience_id' in config"
            ErrorHandler.handleError(
                message,
                SOURCE,
                ErrorHandler.ErrorCategory.VALIDATION,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            Timber.w("📊 SUMMARY: Missing mandatory field 'experience_id', summary not tracked")
            return CFResult.error(message, category = ErrorHandler.ErrorCategory.VALIDATION)
        }

        // Validate other mandatory fields before creating the summary
        val configId = configMap["config_id"] as? String
        val variationId = configMap["variation_id"] as? String
        val versionString = configMap["version"]?.toString()

        val missingFields = mutableListOf<String>()
        if (configId == null) missingFields.add("config_id")
        if (variationId == null) missingFields.add("variation_id")
        if (versionString == null) missingFields.add("version")

        if (missingFields.isNotEmpty()) {
            val message = "Missing mandatory fields for summary: ${missingFields.joinToString(", ")}"
            ErrorHandler.handleError(
                message,
                SOURCE,
                ErrorHandler.ErrorCategory.VALIDATION,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            Timber.w("📊 SUMMARY: Missing mandatory fields: ${missingFields.joinToString(", ")}, summary not tracked")
            return CFResult.error(message, category = ErrorHandler.ErrorCategory.VALIDATION)
        }

        scope.launch {
            try {
                val shouldProcess = trackMutex.withLock {
                    if (summaryTrackMap.containsKey(experienceId)) {
                        Timber.d("📊 SUMMARY: Experience already processed: $experienceId")
                        false
                    } else {
                        summaryTrackMap[experienceId] = true
                        true
                    }
                }
                
                if (!shouldProcess) {
                    return@launch
                }

                val configSummary = CFConfigRequestSummary(
                    config_id = configId,
                    version = versionString,
                    user_id = configMap["user_id"] as? String,
                    requested_time = summaryTimestampFormatter.format(Instant.now()),
                    variation_id = variationId,
                    user_customer_id = user.user_customer_id,
                    session_id = sessionId,
                    behaviour_id = configMap["behaviour_id"] as? String,
                    experience_id = experienceId,
                    rule_id = configMap["rule_id"] as? String
                )

                Timber.i("📊 SUMMARY: Created summary for experience: $experienceId, config: $configId")
                
                if (!summaries.offer(configSummary)) {
                    Timber.w("📊 SUMMARY: Queue full, forcing flush for new entry")
                    ErrorHandler.handleError(
                        "Summary queue full, forcing flush for new entry",
                        SOURCE,
                        ErrorHandler.ErrorCategory.INTERNAL,
                        ErrorHandler.ErrorSeverity.MEDIUM
                    )
                    flushSummaries()
                    if (!summaries.offer(configSummary)) {
                        Timber.e("📊 SUMMARY: Failed to queue summary after flush")
                        ErrorHandler.handleError(
                            "Failed to queue summary after flush",
                            SOURCE,
                            ErrorHandler.ErrorCategory.INTERNAL,
                            ErrorHandler.ErrorSeverity.HIGH
                        )
                    }
                } else {
                    Timber.i("📊 SUMMARY: Added to queue: experience=$experienceId, queue size=${summaries.size}")
                    // Check if queue size threshold is reached
                    if (summaries.size >= summariesQueueSize) {
                        Timber.i("📊 SUMMARY: Queue size threshold reached (${summaries.size}/${summariesQueueSize}), triggering flush")
                        flushSummaries()
                    }
                }
            } catch (e: Exception) {
                Timber.e(e, "📊 SUMMARY: Error processing summary for experience: $experienceId")
                ErrorHandler.handleException(
                    e,
                    "Error processing summary for experience: $experienceId",
                    SOURCE,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
            }
        }
        
        return CFResult.success(true)
    }

    /**
     * Flushes collected summaries to the server with improved error handling
     * 
     * @return CFResult indicating success or describing the error
     */
    suspend fun flushSummaries(): CFResult<Int> {
        if (summaries.isEmpty()) {
            Timber.d("📊 SUMMARY: No summaries to flush")
            return CFResult.success(0)
        }
        
        val summariesToFlush = mutableListOf<CFConfigRequestSummary>()
        summaries.drainTo(summariesToFlush)
        
        if (summariesToFlush.isEmpty()) {
            Timber.d("📊 SUMMARY: No summaries to flush after drain")
            return CFResult.success(0)
        }
        
        Timber.i("📊 SUMMARY: Flushing ${summariesToFlush.size} summaries to server")
        
        return try {
            val result = sendSummaryToServer(summariesToFlush)
            result.onSuccess {
                Timber.i("📊 SUMMARY: Successfully flushed ${summariesToFlush.size} summaries to server")
            }
            result.onError { error ->
                Timber.w("📊 SUMMARY: Failed to flush summaries: ${error.error}")
            }
            result.map { summariesToFlush.size }
        } catch (e: Exception) {
            Timber.e(e, "📊 SUMMARY: Unexpected error during summary flush")
            ErrorHandler.handleException(
                e,
                "Unexpected error during summary flush",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            CFResult.error(
                "Failed to flush summaries", 
                e, 
                category = ErrorHandler.ErrorCategory.INTERNAL
            )
        }
    }

    /**
     * Sends summary data to the server with improved error handling
     * 
     * @param summaries The list of summaries to send
     * @return CFResult indicating success or describing the error
     */
    private suspend fun sendSummaryToServer(summaries: List<CFConfigRequestSummary>): CFResult<Boolean> {
        // Create the JSON payload
        val jsonPayload = try {
            val jsonObject = buildJsonObject {
                put("user", buildJsonObject {
                    user.toUserMap().forEach { (k, v) ->
                        put(k, anyToJsonElement(v))
                    }
                })
                put("summaries", buildJsonArray {
                    summaries.forEach { summary ->
                        add(Json.encodeToJsonElement(summary))
                    }
                })
                put("cf_client_sdk_version", JsonPrimitive("1.1.1"))
            }
            Json.encodeToString(jsonObject)
        } catch (e: Exception) {
            val category = if (e is SerializationException) 
                ErrorHandler.ErrorCategory.SERIALIZATION 
            else 
                ErrorHandler.ErrorCategory.INTERNAL
                
            Timber.e(e, "📊 SUMMARY: Error creating summary payload for ${summaries.size} summaries")
            ErrorHandler.handleException(
                e,
                "Error creating summary payload",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            
            // Re-queue summaries on serialization error
            summaries.forEach { 
                if (!this.summaries.offer(it)) {
                    Timber.w("📊 SUMMARY: Failed to re-queue summary after serialization error")
                    ErrorHandler.handleError(
                        "Failed to re-queue summary after serialization error",
                        SOURCE,
                        ErrorHandler.ErrorCategory.INTERNAL,
                        ErrorHandler.ErrorSeverity.HIGH
                    )
                }
            }
            
            return CFResult.error(
                "Error creating summary payload: ${e.message}", 
                e, 
                category = category
            )
        }

        val url = "https://api.customfit.ai/v1/config/request/summary?cfenc=${cfConfig.clientKey}"
        
        // Log detailed summary information before HTTP call
        Timber.i("📊 SUMMARY HTTP: Preparing to send ${summaries.size} summaries")
        
        summaries.forEachIndexed { index, summary ->
            Timber.d("📊 SUMMARY HTTP: Summary #${index+1}: experience_id=${summary.experience_id}, config_id=${summary.config_id}")
        }
        
        Timber.i("📊 SUMMARY: Sending ${summaries.size} summaries to server")
        
        return try {
            var success = false
            withRetry(
                maxAttempts = cfConfig.maxRetryAttempts,
                initialDelayMs = cfConfig.retryInitialDelayMs,
                maxDelayMs = cfConfig.retryMaxDelayMs,
                backoffMultiplier = cfConfig.retryBackoffMultiplier
            ) {
                Timber.d("📊 SUMMARY: Attempting to send summaries to")
                val result = httpClient.postJson(url, jsonPayload)
                
                if (result !is CFResult.Success) {
                    Timber.w("📊 SUMMARY: Server returned error, retrying...")
                    throw Exception("Failed to send summaries - server returned error")
                }
                
                Timber.i("📊 SUMMARY: Server accepted summaries")
                success = true
            }
            
            if (success) {
                Timber.i("📊 SUMMARY: Successfully sent ${summaries.size} summaries to server")
                CFResult.success(true)
            } else {
                Timber.w("📊 SUMMARY: Failed to send summaries after ${cfConfig.maxRetryAttempts} attempts")
                handleSendFailure(summaries)
                CFResult.error(
                    "Failed to send summaries after ${cfConfig.maxRetryAttempts} attempts",
                    category = ErrorHandler.ErrorCategory.NETWORK
                )
            }
        } catch (e: Exception) {
            Timber.e(e, "📊 SUMMARY: Error sending summaries to server")
            ErrorHandler.handleException(
                e,
                "Error sending summaries to server",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            handleSendFailure(summaries)
            CFResult.error(
                "Error sending summaries to server: ${e.message}", 
                e, 
                category = ErrorHandler.ErrorCategory.NETWORK
            )
        }
    }
    
    /**
     * Helper method to handle failed summary send by re-queuing items
     */
    private fun handleSendFailure(summaries: List<CFConfigRequestSummary>) {
        Timber.w("Failed to send ${summaries.size} summaries after retries, re-queuing")
        var requeueFailCount = 0
        
        summaries.forEach { summary ->
            if (!this.summaries.offer(summary)) {
                requeueFailCount++
            }
        }
        
        if (requeueFailCount > 0) {
            ErrorHandler.handleError(
                "Failed to re-queue $requeueFailCount summaries after send failure",
                SOURCE,
                ErrorHandler.ErrorCategory.INTERNAL,
                ErrorHandler.ErrorSeverity.HIGH
            )
        }
    }

    /**
     * Starts the periodic flush timer
     */
    private fun startPeriodicFlush() {
        scope.launch {
            try {
                timerMutex.withLock {
                    // Cancel existing timer if any
                    flushTimer?.cancel()

                    // Create a new timer
                    flushTimer = fixedRateTimer(
                        "SummaryFlush",
                        daemon = true,
                        period = flushIntervalMs.get()
                    ) {
                        scope.launch {
                            try {
                                Timber.d("Periodic flush triggered for summaries")
                                flushSummaries()
                            } catch (e: Exception) {
                                ErrorHandler.handleException(
                                    e,
                                    "Error during periodic summary flush",
                                    SOURCE,
                                    ErrorHandler.ErrorSeverity.MEDIUM
                                )
                            }
                        }
                    }
                    Timber.d("Started periodic summary flush with interval ${flushIntervalMs.get()} ms")
                }
            } catch (e: Exception) {
                ErrorHandler.handleException(
                    e,
                    "Failed to start periodic summary flush",
                    SOURCE,
                    ErrorHandler.ErrorSeverity.HIGH
                )
            }
        }
    }

    /**
     * Restarts the periodic flush timer with the current interval
     */
    private suspend fun restartPeriodicFlush() {
        try {
            timerMutex.withLock {
                // Cancel existing timer if any
                flushTimer?.cancel()

                // Create a new timer with updated interval
                flushTimer = fixedRateTimer(
                    "SummaryFlush", 
                    daemon = true, 
                    period = flushIntervalMs.get()
                ) {
                    scope.launch {
                        try {
                            Timber.d("Periodic flush triggered for summaries")
                            flushSummaries()
                        } catch (e: Exception) {
                            ErrorHandler.handleException(
                                e,
                                "Error during periodic summary flush",
                                SOURCE,
                                ErrorHandler.ErrorSeverity.MEDIUM
                            )
                        }
                    }
                }
                Timber.d("Restarted periodic flush with interval ${flushIntervalMs.get()} ms")
            }
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Failed to restart periodic summary flush",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
        }
    }

    /**
     * Returns all tracked summaries for other components
     * 
     * @return Map of experience IDs to tracking status
     */
    fun getSummaries(): Map<String, Boolean> = summaryTrackMap.toMap()
}

