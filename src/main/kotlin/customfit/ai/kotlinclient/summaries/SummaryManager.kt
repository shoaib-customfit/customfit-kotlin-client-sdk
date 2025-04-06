package customfit.ai.kotlinclient.summaries

import customfit.ai.kotlinclient.core.CFUser
import customfit.ai.kotlinclient.network.HttpClient
import java.util.concurrent.LinkedBlockingQueue
import org.joda.time.DateTime
import org.json.JSONObject
import org.slf4j.LoggerFactory

class SummaryManager(
        private val sessionId: String,
        private val user: CFUser,
        private val httpClient: HttpClient
) {
    private val logger = LoggerFactory.getLogger(SummaryManager::class.java)
    private val summaries: LinkedBlockingQueue<CFConfigRequestSummary> = LinkedBlockingQueue()
    private val summaryTrackMap = mutableMapOf<String, Boolean>()

    fun pushSummary(config: Any) {
        if (config !is Map<*, *>) {
            logger.warn("Config is not a valid map: $config")
            return
        }

        // Safely cast to Map<String, Any> after verifying keys are Strings
        val configMap =
                config.let { map ->
                    if (map.keys.all { it is String }) {
                        @Suppress("UNCHECKED_CAST") map as Map<String, Any>
                    } else {
                        logger.warn("Config map has non-String keys: $config")
                        return
                    }
                }

        val experienceId = configMap["experience_id"] as? String
        val behaviourId = configMap["behaviour_id"] as? String
        val ruleId = configMap["rule_id"] as? String
        val variationId = configMap["variation_id"] as? String

        // Early exit if experience already processed
        if (experienceId != null && summaryTrackMap.containsKey(experienceId)) {
            logger.debug("Experience already processed: $experienceId")
            return
        }

        // Build summary with available fields
        val configSummary =
                CFConfigRequestSummary(
                        config_id =
                                configMap["config_id"] as? String,
                        version = configMap["version"] as? String,
                        user_id = configMap["user_id"] as? String,
                        requested_time = DateTime.now().toString("yyyy-MM-dd HH:mm:ss"),
                        variation_id = variationId,
                        user_customer_id = user.user_customer_id,
                        session_id = sessionId,
                        behaviour_id = behaviourId,
                        experience_id = experienceId,
                        rule_id = ruleId,
                )

        // Add to queue and track experience
        summaries.offer(configSummary)
        experienceId?.let { summaryTrackMap[it] = true }
        logger.info("Summary added to queue: $configSummary")
    }

    suspend fun flushSummaries() {
        if (summaries.isEmpty()) {
            logger.info("No summaries to flush")
            return
        }
        val summariesToFlush = mutableListOf<CFConfigRequestSummary>()
        summaries.drainTo(summariesToFlush)
        sendSummaryToServer(summariesToFlush)
        logger.info("Flushed ${summariesToFlush.size} summaries")
    }

    private suspend fun sendSummaryToServer(summaries: List<CFConfigRequestSummary>) {
        val jsonPayload =
                JSONObject(
                                mapOf(
                                        "user" to user,
                                        "summaries" to summaries,
                                        "cf_client_sdk_version" to "1.0.0"
                                )
                        )
                        .toString()

        val success =
                httpClient.postJson("https://example.com/v1/config/request/summary", jsonPayload)
        logger.info(if (success) "Summaries sent successfully" else "Error sending summaries")
    }
}
