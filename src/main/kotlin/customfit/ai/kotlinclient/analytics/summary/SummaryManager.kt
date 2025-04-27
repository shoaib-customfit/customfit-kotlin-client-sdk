package customfit.ai.kotlinclient.analytics.summary

import customfit.ai.kotlinclient.core.config.CFConfig
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
     * Updates the flush interval and restarts the timer
     *
     * @param intervalMs new interval in milliseconds
     */
    suspend fun updateFlushInterval(intervalMs: Long) {
        require(intervalMs > 0) { "Interval must be greater than 0" }

        flushIntervalMs.set(intervalMs)
        restartPeriodicFlush()
        Timber.i("Updated summaries flush interval to $intervalMs ms")
    }

    fun pushSummary(config: Any) {
        if (config !is Map<*, *>) {
            Timber.w("Config is not a map: $config")
            return
        }
        val configMap = config.takeIf { it.keys.all { k -> k is String } }?.let {
            @Suppress("UNCHECKED_CAST") (it as Map<String, Any>).also {}
        } ?: run {
            Timber.w("Config map has non-string keys: $config")
            return
        }

        val experienceId = configMap["experience_id"] as? String ?: run {
            Timber.w("Missing mandatory 'experience_id' in config: $configMap")
            return
        }

        // Validate mandatory fields before creating the summary
        val configId = configMap["config_id"] as? String
        val variationId = configMap["variation_id"] as? String
        val versionString = configMap["version"]?.toString()

        if (configId == null) {
            Timber.w("Missing mandatory 'config_id' for summary: $configMap")
            return
        }
        if (variationId == null) {
            Timber.w("Missing mandatory 'variation_id' for summary: $configMap")
            return
        }
        if (versionString == null) {
            Timber.w("Missing or invalid mandatory 'version' for summary: $configMap")
            return
        }

        scope.launch {
            trackMutex.withLock {
                if (summaryTrackMap.containsKey(experienceId)) {
                    Timber.d("Experience already processed: $experienceId")
                    return@launch
                }
                summaryTrackMap[experienceId] = true
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

            if (!summaries.offer(configSummary)) {
                Timber.w("Summary queue full, forcing flush for: $configSummary")
                flushSummaries()
                if (!summaries.offer(configSummary)) {
                    Timber.e("Failed to queue summary after flush: $configSummary")
                }
            } else {
                Timber.d("Summary added to queue: $configSummary")
                // Check if queue size threshold is reached
                if (summaries.size >= summariesQueueSize) {
                    flushSummaries()
                }
            }
        }
    }

    suspend fun flushSummaries() {
        if (summaries.isEmpty()) {
            Timber.d("No summaries to flush")
            return
        }
        val summariesToFlush = mutableListOf<CFConfigRequestSummary>()
        summaries.drainTo(summariesToFlush)
        if (summariesToFlush.isNotEmpty()) {
            sendSummaryToServer(summariesToFlush)
            Timber.i("Flushed ${summariesToFlush.size} summaries successfully")
        }
    }

    private suspend fun sendSummaryToServer(summaries: List<CFConfigRequestSummary>) {
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
            if (e is kotlinx.serialization.SerializationException) {
                Timber.e(e, "Serialization error creating summary payload: ${e.message}")
            }
            // Re-queue summaries on serialization error
            summaries.forEach { this.summaries.offer(it) }
            return
        }

        val url = "https://api.customfit.ai/v1/config/request/summary?cfenc=${cfConfig.clientKey}"
        try {
            withRetry(
                maxAttempts = cfConfig.maxRetryAttempts,
                initialDelayMs = cfConfig.retryInitialDelayMs,
                maxDelayMs = cfConfig.retryMaxDelayMs,
                backoffMultiplier = cfConfig.retryBackoffMultiplier
            ) {
                if (!httpClient.postJson(url, jsonPayload)) {
                    throw Exception("Failed to send summaries")
                }
            }
        } catch (e: Exception) {
            Timber.w("Failed to send ${summaries.size} summaries after retries, re-queuing")
            summaries.forEach { summary ->
                if (!this.summaries.offer(summary)) {
                    Timber.e("Failed to re-queue summary after send failure: $summary")
                }
            }
        }
    }

    private fun startPeriodicFlush() {
        scope.launch {
            timerMutex.withLock {
                // Cancel existing timer if any
                flushTimer?.cancel()

                // Create a new timer
                flushTimer =
                        fixedRateTimer(
                                "SummaryFlush",
                                daemon = true,
                                period = flushIntervalMs.get()
                        ) {
                            scope.launch {
                                Timber.d("Periodic flush triggered for summaries")
                                flushSummaries()
                            }
                        }
            }
        }
    }

    private suspend fun restartPeriodicFlush() {
        timerMutex.withLock {
            // Cancel existing timer if any
            flushTimer?.cancel()

            // Create a new timer with updated interval
            flushTimer =
                    fixedRateTimer("SummaryFlush", daemon = true, period = flushIntervalMs.get()) {
                        scope.launch {
                            Timber.d("Periodic flush triggered for summaries")
                            flushSummaries()
                        }
                    }
            Timber.d("Restarted periodic flush with interval ${flushIntervalMs.get()} ms")
        }
    }

    // Method to retrieve all active summaries for other components
    fun getSummaries(): Map<String, Boolean> = summaryTrackMap.toMap()
}
