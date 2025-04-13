package customfit.ai.kotlinclient.network

import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicInteger
import javax.net.ssl.HttpsURLConnection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import mu.KotlinLogging
import org.json.JSONObject
import customfit.ai.kotlinclient.core.CFConfig

private val logger = KotlinLogging.logger {}

class HttpClient(private val cfConfig: CFConfig? = null) {
    // Use atomics to allow thread-safe updates
    private val connectionTimeout = AtomicInteger(cfConfig?.networkConnectionTimeoutMs ?: 10_000)
    private val readTimeout = AtomicInteger(cfConfig?.networkReadTimeoutMs ?: 10_000)
    
    /**
     * Updates the connection timeout setting
     * 
     * @param timeoutMs new timeout in milliseconds
     */
    fun updateConnectionTimeout(timeoutMs: Int) {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        connectionTimeout.set(timeoutMs)
        logger.debug { "Updated connection timeout to $timeoutMs ms" }
    }
    
    /**
     * Updates the read timeout setting
     * 
     * @param timeoutMs new timeout in milliseconds
     */
    fun updateReadTimeout(timeoutMs: Int) {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        readTimeout.set(timeoutMs)
        logger.debug { "Updated read timeout to $timeoutMs ms" }
    }
    
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
                    connection.connectTimeout = connectionTimeout.get()
                    connection.readTimeout = readTimeout.get()
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
                val responseCode = conn.responseCode
                
                // Print API response
                val timestamp = java.text.SimpleDateFormat("HH:mm:ss.SSS").format(java.util.Date())
                logger.info { "================ API RESPONSE (${url.substringAfterLast("/")}) ================" }
                logger.info { "Status Code: $responseCode" }
                
                try {
                    if (responseCode == HttpURLConnection.HTTP_OK || responseCode == HttpURLConnection.HTTP_ACCEPTED) {
                        val responseBody = conn.inputStream.bufferedReader().readText()
                        logger.info { responseBody }
                    } else {
                        val errorBody = conn.errorStream?.bufferedReader()?.readText() ?: "No error body"
                        logger.error { "Error: $errorBody" }
                    }
                } catch (e: Exception) {
                    logger.error { "Failed to read response: ${e.message}" }
                } finally {
                    logger.info { "=================================================================" }
                }
                
                responseCode == HttpURLConnection.HTTP_OK || responseCode == HttpURLConnection.HTTP_ACCEPTED
            } ?: false
}
