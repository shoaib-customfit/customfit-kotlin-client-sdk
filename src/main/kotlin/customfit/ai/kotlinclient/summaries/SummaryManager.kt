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
import org.joda.time.DateTime
import org.json.JSONArray
import org.json.JSONObject
import timber.log.Timber

class SummaryManager(
        private val sessionId: String,
        private val user: CFUser,
        private val httpClient: HttpClient
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
            Timber.w("Config is not a map: $config")
            return
        }
        val configMap =
                config.takeIf { it.keys.all { k -> k is String } }?.let {
                    @Suppress("UNCHECKED_CAST") it as Map<String, Any>
                }
                        ?: run {
                            Timber.w("Config map has non-string keys: $config")
                            return
                        }

        val experienceId =
                configMap["experience_id"] as? String
                        ?: run {
                            Timber.w("Missing mandatory 'experience_id' in config: $configMap")
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
                Timber.w("Summary queue full, forcing flush for: $configSummary")
                flushSummaries()
                if (!summaries.offer(configSummary)) {
                    Timber.e("Failed to queue summary after flush: $configSummary")
                }
            }
            Timber.d("Summary added to queue: $configSummary")
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
            Timber.i("Flushed %d summaries successfully", summariesToFlush.size)
        }
    }

    private suspend fun sendSummaryToServer(summaries: List<CFConfigRequestSummary>) {
        val jsonPayload =
                try {
                    val jsonObject = JSONObject()
                    jsonObject.put("user", user)
                    jsonObject.put("summaries", JSONArray(summaries))
                    jsonObject.put("cf_client_sdk_version", "1.0.0")
                    jsonObject.toString()
                } catch (e: Exception) {
                    Timber.e("Error serializing summaries: $e")
                    summaries.forEach { this.summaries.offer(it) }
                    return
                }

        val success =
                httpClient.postJson("https://example.com/v1/config/request/summary", jsonPayload)
        if (!success) {
            Timber.w("Failed to send %d summaries, re-queuing", summaries.size)
            summaries.forEach { this.summaries.offer(it) }
        } else {
            Timber.i("Successfully sent %d summaries", summaries.size)
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
