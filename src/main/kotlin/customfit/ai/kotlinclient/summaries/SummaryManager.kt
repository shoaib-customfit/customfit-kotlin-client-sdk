package customfit.ai.kotlinclient.summaries

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import customfit.ai.kotlinclient.network.HttpClient
import java.util.Collections
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import mu.KotlinLogging
import org.joda.time.DateTime
import kotlinx.serialization.json.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.Serializable

private val logger = KotlinLogging.logger {}

// --- Copied Helper function to serialize Any --- 
private fun anyToJsonElement(value: Any?): JsonElement = when (value) {
    null -> JsonNull
    is JsonElement -> value // If it's already a JsonElement, return it directly
    is String -> JsonPrimitive(value)
    is Number -> JsonPrimitive(value)
    is Boolean -> JsonPrimitive(value)
    is Map<*, *> -> buildJsonObject { // Recursively handle maps
        value.forEach { (k, v) ->
            if (k is String) {
                put(k, anyToJsonElement(v)) // Recursive call
            } else {
                // Handle non-string keys if necessary, e.g., convert toString or throw error
                logger.warn { "Skipping non-string key in map during serialization: $k" }
            }
        }
    }
    is Iterable<*> -> buildJsonArray { // Recursively handle lists/collections
        value.forEach { 
            add(anyToJsonElement(it)) // Recursive call
        }
    }
    // Add other specific types if needed (e.g., Date -> JsonPrimitive(date.toString()))
    else -> throw kotlinx.serialization.SerializationException("Serializer for class '${value::class.simpleName}' is not found. Cannot serialize value of type Any.")
}
// --- End Helper function --- 

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
        logger.info { "SummaryManager initialized with summariesQueueSize=$summariesQueueSize, summariesFlushTimeSeconds=$summariesFlushTimeSeconds, flushIntervalMs=${flushIntervalMs.get()}" }
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
        logger.info { "Updated summaries flush interval to $intervalMs ms" }
    }

    fun pushSummary(config: Any) {
        if (config !is Map<*, *>) {
            logger.warn { "Config is not a map: $config" }
            return
        }
        val configMap =
                config.takeIf { it.keys.all { k -> k is String } }?.let {
                    @Suppress("UNCHECKED_CAST")
                    (it as Map<String, Any>).also { 
                    }
                }
                        ?: run {
                            logger.warn { "Config map has non-string keys: $config" }
                            return
                        }

        val experienceId =
                configMap["experience_id"] as? String
                        ?: run {
                            logger.warn { "Missing mandatory 'experience_id' in config: $configMap" }
                            return
                        }
                        
        // Validate mandatory fields before creating the summary
        val configId = configMap["config_id"] as? String
        val variationId = configMap["variation_id"] as? String
        // Keep version as String but ensure it's not null
        val versionString = configMap["version"]?.toString()

        if (configId == null) {
            logger.warn { "Missing mandatory 'config_id' for summary: $configMap" }
            return
        }
        if (variationId == null) {
            logger.warn { "Missing mandatory 'variation_id' for summary: $configMap" }
            return
        }
        if (versionString == null) {
            logger.warn { "Missing or invalid mandatory 'version' for summary: $configMap" }
            return
        }

        scope.launch {
            trackMutex.withLock {
                if (summaryTrackMap.containsKey(experienceId)) {
                    logger.debug { "Experience already processed: $experienceId" }
                    return@launch
                }
                summaryTrackMap[experienceId] = true
            }

            val configSummary =
                    CFConfigRequestSummary(
                            config_id = configId,
                            version = versionString, // Use validated String version
                            user_id = configMap["user_id"] as? String,
                            requested_time = DateTime.now().toString("yyyy-MM-dd HH:mm:ss.SSSZ"), // Keep as formatted string for now
                            variation_id = variationId,
                            user_customer_id = user.user_customer_id,
                            session_id = sessionId,
                            behaviour_id = configMap["behaviour_id"] as? String,
                            experience_id = experienceId,
                            rule_id = configMap["rule_id"] as? String
                    )

            if (!summaries.offer(configSummary)) {
                logger.warn { "Summary queue full, forcing flush for: $configSummary" }
                flushSummaries()
                if (!summaries.offer(configSummary)) {
                    logger.error { "Failed to queue summary after flush: $configSummary" }
                }
            } else {
                logger.debug { "Summary added to queue: $configSummary" }
                // Check if queue size threshold is reached
                if (summaries.size >= summariesQueueSize) {
                    flushSummaries()
                }
            }
        }
    }

    suspend fun flushSummaries() {
        if (summaries.isEmpty()) {
            logger.debug { "No summaries to flush" }
            return
        }
        val summariesToFlush = mutableListOf<CFConfigRequestSummary>()
        summaries.drainTo(summariesToFlush)
        if (summariesToFlush.isNotEmpty()) {
            sendSummaryToServer(summariesToFlush)
            logger.info { "Flushed ${summariesToFlush.size} summaries successfully" }
        }
    }

    private suspend fun sendSummaryToServer(summaries: List<CFConfigRequestSummary>) {
        val jsonPayload =
                try {
                    // Use kotlinx.serialization builders
                    val jsonObject = buildJsonObject {
                        // Use user.toUserMap() and the helper
                        put("user", buildJsonObject { 
                            // Use helper function for values in user map
                            user.toUserMap().forEach { (k, v) -> 
                                put(k, anyToJsonElement(v))
                            } 
                        })
                        
                        // Add summaries array
                        put("summaries", buildJsonArray {
                            summaries.forEach { summary ->
                                // Assuming CFConfigRequestSummary is simple enough or @Serializable
                                // If not, it would need manual construction or its own serializer
                                add(Json.encodeToJsonElement(summary)) 
                                /* // Manual construction if needed:
                                add(buildJsonObject { 
                                    summary.config_id?.let { put("config_id", JsonPrimitive(it)) }
                                    summary.version?.let { put("version", JsonPrimitive(it)) }
                                    // ... other summary fields ...
                                })
                                */
                            }
                        })
                        
                        // Add SDK version
                        put("cf_client_sdk_version", JsonPrimitive("1.1.1")) // Use correct version
                    }
                    
                    Json.encodeToString(jsonObject)
                } catch (e: Exception) {
                     // Catch specific SerializationException from helper if needed
                    if (e is kotlinx.serialization.SerializationException) {
                        logger.error(e) { "Serialization error creating summary payload: ${e.message}" }
                    } else {
                        logger.error(e) { "Error serializing summaries: ${e.message}" }
                    }
                    summaries.forEach { this.summaries.offer(it) } // Re-queue on serialization error
                    return
                }

        // Print the API payload for debugging
        val timestamp = java.text.SimpleDateFormat("HH:mm:ss.SSS").format(java.util.Date())
        logger.debug { "================ SUMMARY API PAYLOAD ================" }
        logger.debug { jsonPayload }
        logger.debug { "====================================================" }

        val success =
                httpClient.postJson("https://api.customfit.ai/v1/config/request/summary?cfenc=${cfConfig.clientKey}", jsonPayload)
        if (!success) {
            logger.warn { "Failed to send ${summaries.size} summaries, re-queuing" }
            // Re-add summaries to queue in case of failure, but avoid infinite growth
            val capacity = summariesQueueSize - this.summaries.size
            if (capacity > 0) {
                summaries.take(capacity).forEach { this.summaries.offer(it) }
            }
        } else {
            logger.info { "Successfully sent ${summaries.size} summaries" }
        }
    }

    private fun startPeriodicFlush() {
        scope.launch {
            timerMutex.withLock {
                // Cancel existing timer if any
                flushTimer?.cancel()
                
                // Create a new timer
                flushTimer = fixedRateTimer("SummaryFlush", daemon = true, period = flushIntervalMs.get()) {
                    scope.launch {
                        logger.debug { "Periodic flush triggered for summaries" }
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
            flushTimer = fixedRateTimer("SummaryFlush", daemon = true, period = flushIntervalMs.get()) {
                scope.launch {
                    logger.debug { "Periodic flush triggered for summaries" }
                    flushSummaries()
                }
            }
            logger.debug { "Restarted periodic flush with interval ${flushIntervalMs.get()} ms" }
        }
    }
    
    // Method to retrieve all active summaries for other components
    fun getSummaries(): Map<String, Boolean> = summaryTrackMap.toMap()
}
