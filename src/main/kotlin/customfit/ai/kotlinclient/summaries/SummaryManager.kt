package customfit.ai.kotlinclient.summaries

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
        private val user: CFUser

) {
    private val summaries: LinkedBlockingQueue<CFConfigRequestSummary> = LinkedBlockingQueue()
    private val summaryTrackMap = Collections.synchronizedMap(mutableMapOf<String, Boolean>())
    private val trackMutex = Mutex()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    companion object {
        private const val FLUSH_INTERVAL_MS = 60_000L // 1 minute
    }

    init {
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
            }
            logger.debug { "Summary added to queue: $configSummary" }
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
            summaries.forEach { this.summaries.offer(it) }
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
        fixedRateTimer("SummaryFlush", daemon = true, period = FLUSH_INTERVAL_MS) {
            scope.launch { flushSummaries() }
        }
    }
}
