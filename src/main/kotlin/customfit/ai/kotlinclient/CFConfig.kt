import io.jsonwebtoken.Jwts
import io.jsonwebtoken.Claims
import java.util.*

data class CFConfig(
    val accountId: String,
    val projectId: String,
    val environmentId: String,
    val dimensionId: String,
    val clientKey: String
) {
    companion object {
        fun fromClientKey(clientKey: String): CFConfig {
            // Decode JWT token without verifying the signature
            val claims: Claims = Jwts.parserBuilder()
                .setSigningKeyResolver { _, _ -> null } // Disable signature verification
                .build()
                .parseClaimsJws(clientKey)
                .body

            // Extract values from the JWT claims
            val accountId = claims["account_id"] as String
            val projectId = claims["project_id"] as String
            val environmentId = claims["environment_id"] as String
            val dimensionId = claims["dimension_id"] as String
            val clientKey = clientKey as String

            return CFConfig(accountId, projectId, environmentId, dimensionId, clientKey)
        }
    }
}
