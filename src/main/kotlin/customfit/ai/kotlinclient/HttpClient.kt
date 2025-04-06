package customfit.ai.kotlinclient

import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

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
                    connection = URL(url).openConnection() as HttpURLConnection
                    connection.requestMethod = method
                    headers.forEach { (key, value) -> connection.setRequestProperty(key, value) }

                    if (body != null) {
                        connection.doOutput = true
                        connection.outputStream.use { os ->
                            val input = body.toByteArray(Charsets.UTF_8)
                            os.write(input, 0, input.size)
                        }
                    }

                    connection.connect()
                    responseHandler(connection)
                } catch (e: Exception) {
                    println("HTTP request failed: ${e.message}")
                    null
                } finally {
                    connection?.disconnect()
                }
            }

    suspend fun fetchMetadata(url: String): Map<String, String>? {
        return performRequest(url, "HEAD") { connection ->
            if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                val headers = connection.headerFields
                mapOf(
                        "Last-Modified" to (headers["Last-Modified"]?.firstOrNull() ?: ""),
                        "ETag" to (headers["ETag"]?.firstOrNull() ?: "")
                )
            } else {
                println("Error fetching metadata: ${connection.responseCode}")
                null
            }
        }
    }

    suspend fun fetchJson(url: String): JSONObject? {
        return performRequest(url, "GET") { connection ->
            if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                JSONObject(connection.inputStream.bufferedReader().readText())
            } else {
                println("Error fetching JSON: ${connection.responseCode}")
                null
            }
        }
    }

    suspend fun postJson(url: String, payload: String): Boolean {
        return performRequest(url, "POST", mapOf("Content-Type" to "application/json"), payload) {
                connection ->
            connection.responseCode == HttpURLConnection.HTTP_OK
        }
                ?: false
    }
}
