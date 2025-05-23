package customfit.ai.kotlinclient.analytics.summary

import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import kotlinx.serialization.Serializable

// Define formatter matching SummaryManager
private val summaryTimestampFormatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSSX").withZone(ZoneOffset.UTC)

@Serializable
data class CFConfigRequestSummary(
        val config_id: String?,
        val version: String?,
        val user_id: String?,
        val requested_time: String?,
        val variation_id: String?,
        val user_customer_id: String?,
        val session_id: String?,
        val behaviour_id: String?,
        val experience_id: String?,
        val rule_id: String?,
) {
        constructor(
                config: Map<String, Any>,
                customerUserId: String,
                sessionId: String
        ) : this(
                config_id = config["config_id"] as? String,
                version = config["version"] as? String,
                user_id = config["user_id"] as? String,
                requested_time = summaryTimestampFormatter.format(Instant.now()),
                variation_id = config["variation_id"] as? String,
                user_customer_id = customerUserId,
                session_id = sessionId,
                behaviour_id =
                        (config["experience_behaviour_response"] as? Map<*, *>)?.get(
                                "behaviour_id"
                        ) as?
                                String,
                experience_id =
                        (config["experience_behaviour_response"] as? Map<*, *>)?.get(
                                "experience_id"
                        ) as?
                                String,
                rule_id =
                        (config["experience_behaviour_response"] as? Map<*, *>)?.get("rule_id") as?
                                String,
        )
}
