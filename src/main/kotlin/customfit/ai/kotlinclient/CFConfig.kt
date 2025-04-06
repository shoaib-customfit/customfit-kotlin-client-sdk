package customfit.ai.kotlinclient

import java.util.*
import org.json.JSONObject

data class CFConfig(
        val clientKey: String
) {
    val dimensionId: String? = extractDimensionIdFromToken(clientKey)

    companion object {
        fun fromClientKey(clientKey: String): CFConfig {
            return CFConfig(clientKey)
        }

        private fun extractDimensionIdFromToken(token: String): String? {
            return try {
                val parts = token.split(".")
                if (parts.size != 3) {
                    println("Invalid JWT structure")
                    return null
                }

                var payload = parts[1]
                while (payload.length % 4 != 0) {
                    payload += "="
                }
                val decodedBytes = Base64.getUrlDecoder().decode(payload)
                val decodedString = String(decodedBytes)
                JSONObject(decodedString).optString("dimension_id", null)
            } catch (e: Exception) {
                println("JWT decoding error: ${e.javaClass.simpleName} - ${e.message}")
                null
            }
        }
    }
}
