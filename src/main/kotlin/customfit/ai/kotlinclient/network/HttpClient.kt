package customfit.ai.kotlinclient.network

import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import timber.log.Timber

class HttpClient {
    suspend fun <T> performRequest(
            url: String,
            method: String,
            headers: Map<String, String> = emptyMap(),
            body: String? = null,
            responseHandler: (HttpURLConnection) -> T?
    ): T? =
            withContext(Dispatchers.IO) {
                var connection: HttpURLConnection? = null
                try {
                    connection =
                            (URL(url).openConnection() as HttpURLConnection).apply {
                                requestMethod = method
                                connectTimeout = 10_000 // 10 seconds
                                readTimeout = 10_000 // 10 seconds
                                headers.forEach { (key, value) -> setRequestProperty(key, value) }
                                if (body != null) {
                                    doOutput = true
                                    outputStream.use { os ->
                                        os.write(body.toByteArray(Charsets.UTF_8))
                                    }
                                }
                            }
                    connection.connect()
                    responseHandler(connection)
                } catch (e: Exception) {
                    Timber.e(e, "HTTP request failed for $url: ${e.message}")
                    null
                } finally {
                    connection?.disconnect()
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
                    Timber.w("Failed to fetch metadata from $url: ${conn.responseCode}")
                    null
                }
            }

    suspend fun fetchJson(url: String): JSONObject? =
            performRequest(url, "GET") { conn ->
                if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                    JSONObject(conn.inputStream.bufferedReader().readText())
                } else {
                    Timber.w("Failed to fetch JSON from $url: ${conn.responseCode}")
                    null
                }
            }

    suspend fun postJson(url: String, payload: String): Boolean =
            performRequest(url, "POST", mapOf("Content-Type" to "application/json"), payload) { conn ->
                conn.responseCode == HttpURLConnection.HTTP_OK
            } ?: false
}
