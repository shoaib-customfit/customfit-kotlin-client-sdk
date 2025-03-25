package customfit.ai.kotlinclient

import io.jsonwebtoken.Jwts
import io.jsonwebtoken.Claims
import java.util.*

data class CFConfig(

    val clientKey: String
) {
    companion object {
        fun fromClientKey(clientKey: String): CFConfig {
            return CFConfig(clientKey)
        }
    }
}
