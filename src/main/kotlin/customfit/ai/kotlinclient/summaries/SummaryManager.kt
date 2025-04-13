package customfit.ai.kotlinclient.summaries

import customfit.ai.kotlinclient.core.CFConfig
import customfit.ai.kotlinclient.core.CFUser
import customfit.ai.kotlinclient.network.HttpClient
import java.util.Collections
import java.util.concurrent.LinkedBlockingQueue
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import mu.KotlinLogging
import org.joda.time.DateTime
import org.json.JSONArray
import org.json.JSONObject

private val logger = KotlinLogging.logger {}

class SummaryManager(
        private val sessionId: String,
        private val httpClient: HttpClient,
        private val user: CFUser,
        private val cfConfig: CFConfig
) {
    // Use values from config or fallback to defaults
    private val summariesQueueSize = cfConfig.summariesQueueSize
    private val summariesFlushTimeSeconds = cfConfig.summariesFlushTimeSeconds
    private val summariesFlushIntervalMs = cfConfig.summariesFlushIntervalMs
    
    private val summaries: LinkedBlockingQueue<CFConfigRequestSummary> = LinkedBlockingQueue(summariesQueueSize)
    private val summaryTrackMap = Collections.synchronizedMap(mutableMapOf<String, Boolean>())
    private val trackMutex = Mutex()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    init {
        logger.info { "SummaryManager initialized with summariesQueueSize=$summariesQueueSize, summariesFlushTimeSeconds=$summariesFlushTimeSeconds, summariesFlushIntervalMs=$summariesFlushIntervalMs" }
        startPeriodicFlush()
    }

    fun pushSummary(config: Any) {
        if (config !is Map<*, *>) {
            logger.warn { "Config is not a map: $config" }
            return
        }
        val configMap =
                config.takeIf { it.keys.all { k -> k is String } }?.let {
                    @Suppress("UNCHECKED_CAST") it as Map<String, Any>
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
                            config_id = configMap["config_id"] as? String,
                            version = configMap["version"]?.toString(),
                            user_id = configMap["user_id"] as? String,
                            requested_time = DateTime.now().toString("yyyy-MM-dd HH:mm:ss"),
                            variation_id = configMap["variation_id"] as? String,
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
                    val jsonObject = JSONObject()
                    jsonObject.put("user", JSONObject().apply {
                        put("user_customer_id", user.user_customer_id)
                        put("anonymous", user.anonymous)
                        put("private_fields", user.private_fields)
                        put("session_fields", user.session_fields)
                        put("properties", JSONObject(user.properties))
                    })
                    jsonObject.put("summaries", JSONArray(summaries))
                    jsonObject.put("cf_client_sdk_version", "1.0.0")
                    jsonObject.toString()
                } catch (e: Exception) {
                    logger.error(e) { "Error serializing summaries: ${e.message}" }
                    summaries.forEach { this.summaries.offer(it) }
                    return
                }

        val success =
                httpClient.postJson("https://example.com/v1/config/request/summary", jsonPayload)
        if (!success) {
            logger.warn { "Failed to send ${summaries.size} summaries, re-queuing" }
            // Re-add summaries to queue in case of failure, but avoid infinite growth
            val capacity = summariesQueueSize - this.summaries.size
            if (capacity > 0) {
                summaries.take(capacity).forEach { this.summaries.offer(it) }
            } else {
                logger.warn { "Summary queue is full, couldn't re-queue failed summaries" }
            }
        } else {
            logger.info { "Successfully sent ${summaries.size} summaries" }
        }
    }

    private fun mapToJsonObject(map: Map<String, Any?>): JSONObject {
        val jsonObject = JSONObject()
        map.forEach { (key, value) ->
            when (value) {
                is Map<*, *> -> jsonObject.put(key, mapToJsonObject(value as Map<String, Any?>))
                is List<*> -> jsonObject.put(key, JSONArray(value))
                null -> jsonObject.put(key, JSONObject.NULL)
                else -> jsonObject.put(key, value)
            }
        }
        return jsonObject
    }

    private fun startPeriodicFlush() {
        fixedRateTimer("SummaryFlush", daemon = true, period = summariesFlushIntervalMs) {
            scope.launch {
                val oldestSummary = summaries.peek()
                val currentTime = DateTime.now()
                
                if (oldestSummary != null && 
                    currentTime.minusSeconds(summariesFlushTimeSeconds)
                    .isAfter(DateTime.parse(oldestSummary.requested_time))) {
                    logger.debug { "Time-based flush triggered for summaries" }
                    flushSummaries()
                }
            }
        }
    }
    
    // Method to retrieve all active summaries for other components
    fun getSummaries(): Map<String, Boolean> = summaryTrackMap.toMap()
}
