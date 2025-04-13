    package customfit.ai.kotlinclient.core

    import java.util.*
    import kotlinx.serialization.Serializable
    import mu.KotlinLogging
    import org.json.JSONObject

    private val logger = KotlinLogging.logger {}

    @Serializable
    data class CFConfig(val clientKey: String) {
        val dimensionId: String? by lazy { extractDimensionIdFromToken(clientKey) }

        companion object {
            fun fromClientKey(clientKey: String): CFConfig = CFConfig(clientKey)

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
    }
