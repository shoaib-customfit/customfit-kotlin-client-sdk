package customfit.ai.kotlinclient.network

import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import mu.KotlinLogging
import org.json.JSONObject
import customfit.ai.kotlinclient.core.CFConfig

private val logger = KotlinLogging.logger {}

class HttpClient(private val cfConfig: CFConfig? = null) {
    private val networkConnectionTimeout = cfConfig?.networkConnectionTimeoutMs ?: 10_000 // Default 10 seconds
    private val networkReadTimeout = cfConfig?.networkReadTimeoutMs ?: 10_000 // Default 10 seconds
    
    suspend fun <T> performRequest(
            url: String,
            method: String,
            headers: Map<String, String> = emptyMap(),
            body: String? = null,
            responseHandler: suspend (HttpURLConnection) -> T?
    ): T? =
            withContext(Dispatchers.IO) {
                var connection: HttpURLConnection? = null
                try {
                    logger.debug { "Making $method request to $url" }
                    connection = URL(url).openConnection() as HttpURLConnection
                    connection.requestMethod = method
                    connection.connectTimeout = networkConnectionTimeout
                    connection.readTimeout = networkReadTimeout
                    connection.doInput = true

                    headers.forEach { (key, value) -> connection.setRequestProperty(key, value) }

                    if (body != null) {
                        connection.doOutput = true
                        connection.outputStream.use { it.write(body.toByteArray()) }
                    }

                    val response = responseHandler(connection)
                    connection.disconnect()
                    return@withContext response
                } catch (e: Exception) {
                    logger.error(e) { "Error making request to $url: ${e.message}" }
                    connection?.disconnect()
                    null
                }
            }

    suspend fun fetchMetadata(url: String): Map<String, String>? =
            performRequest(url, "HEAD") { conn ->
                if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                    conn.headerFields.let { headers ->
                        mapOf(
                                "Last-Modified" to (headers["Last-Modified"]?.firstOrNull() ?: ""),
                                "ETag" to (headers["ETag"]?.firstOrNull() ?: "")
                        )
                    }
                } else {
                    logger.warn { "Failed to fetch metadata from $url: ${conn.responseCode}" }
                    null
                }
            }

    suspend fun fetchJson(url: String): JSONObject? =
            performRequest(url, "GET") { conn ->
                if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                    JSONObject(conn.inputStream.bufferedReader().readText())
                } else {
                    logger.warn { "Failed to fetch JSON from $url: ${conn.responseCode}" }
                    null
                }
            }

    suspend fun postJson(url: String, payload: String): Boolean =
            performRequest(url, "POST", mapOf("Content-Type" to "application/json"), payload) { conn ->
                conn.responseCode == HttpURLConnection.HTTP_OK
            } ?: false
}
