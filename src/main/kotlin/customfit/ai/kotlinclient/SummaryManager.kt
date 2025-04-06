package customfit.ai.kotlinclient

import java.util.concurrent.LinkedBlockingQueue
import org.joda.time.DateTime
import org.json.JSONObject

class SummaryManager(
        private val sessionId: String,
        private val user: CFUser,
        private val httpClient: HttpClient
) {
    private val summaries: LinkedBlockingQueue<CFConfigRequestSummary> = LinkedBlockingQueue()
    private val summaryTrackMap = mutableMapOf<String, Boolean>()

    fun pushSummary(config: Any) {
        if (config !is Map<*, *>) {
            println("Config is not a valid map")
            return
        }
        val configMap = config as Map<String, Any>
        val experienceBehaviourResponse =
                configMap["experience_behaviour_response"] as? Map<String, Any>
        val experienceId = experienceBehaviourResponse?.get("experience_id") as? String

        if (experienceId != null && summaryTrackMap.containsKey(experienceId)) {
            println("Experience already processed, skipping summary addition.")
            return
        }

        val configSummary =
                CFConfigRequestSummary(
                        config_id = configMap["config_id"] as? String,
                        version = configMap["version"] as? String,
                        user_id = configMap["user_id"] as? String,
                        requested_time = DateTime.now().toString("yyyy-MM-dd HH:mm:ss"),
                        variation_id = configMap["variation_id"] as? String,
                        user_customer_id = user.user_customer_id,
                        session_id = sessionId,
                        behaviour_id = experienceBehaviourResponse?.get("behaviour_id") as? String,
                        experience_id = experienceId,
                        rule_id = experienceBehaviourResponse?.get("rule_id") as? String,
                        is_template_config = configMap["template_info"] != null
                )

        summaries.offer(configSummary)
        experienceId?.let { summaryTrackMap[it] = true }
        println("Summary added to queue: $configSummary")
    }

    suspend fun flushSummaries() {
        if (summaries.isEmpty()) {
            println("No summaries to flush.")
            return
        }
        val summariesToFlush = mutableListOf<CFConfigRequestSummary>()
        summaries.drainTo(summariesToFlush)
        sendSummaryToServer(summariesToFlush)
        println("Flushed ${summariesToFlush.size} summaries.")
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
        println(if (success) "Summaries sent successfully." else "Error sending summaries.")
    }
}
