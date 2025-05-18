package customfit.ai.kotlinclient.network

import customfit.ai.kotlinclient.constants.CFConstants
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.core.error.ErrorHandler
import customfit.ai.kotlinclient.logging.Timber
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

class HttpClient(private val cfConfig: CFConfig? = null) {
    companion object {
        private const val SOURCE = "HttpClient"
    }
    
    // Use atomics to allow thread-safe updates
    private val connectionTimeout = AtomicInteger(cfConfig?.networkConnectionTimeoutMs ?: 
                                                 CFConstants.Network.CONNECTION_TIMEOUT_MS)
    private val readTimeout = AtomicInteger(cfConfig?.networkReadTimeoutMs ?: 
                                           CFConstants.Network.READ_TIMEOUT_MS)

    /**
     * Updates the connection timeout setting
     *
     * @param timeoutMs new timeout in milliseconds
     */
    fun updateConnectionTimeout(timeoutMs: Int) {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        connectionTimeout.set(timeoutMs)
        Timber.d("Updated connection timeout to $timeoutMs ms")
    }

    /**
     * Updates the read timeout setting
     *
     * @param timeoutMs new timeout in milliseconds
     */
    fun updateReadTimeout(timeoutMs: Int) {
        require(timeoutMs > 0) { "Timeout must be greater than 0" }
        readTimeout.set(timeoutMs)
        Timber.d("Updated read timeout to $timeoutMs ms")
    }

    /**
     * Performs an HTTP request with robust error handling
     */
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
                    Timber.d("API CALL: $method request to $url")
                    connection = URL(url).openConnection() as HttpURLConnection
                    connection.requestMethod = method
                    connection.connectTimeout = connectionTimeout.get()
                    connection.readTimeout = readTimeout.get()
                    connection.doInput = true
                    connection.instanceFollowRedirects = true
                    connection.setRequestProperty("User-Agent", "CustomFit-SDK/1.0 Kotlin")

                    headers.forEach { (key, value) -> 
                        connection.setRequestProperty(key, value)
                    }

                    if (body != null) {
                        connection.doOutput = true
                        connection.outputStream.use { it.write(body.toByteArray()) }
                    }

                    val response = responseHandler(connection)
                    connection.disconnect()
                    return@withContext response
                } catch (e: Exception) {
                    // Use our robust error handling system
                    Timber.e("API ERROR: ${e.javaClass.simpleName} - ${e.message}")
                    val category = ErrorHandler.handleException(
                        e, 
                        "Error making $method request to $url", 
                        SOURCE,
                        ErrorHandler.ErrorSeverity.HIGH
                    )
                    
                    connection?.disconnect()
                    null
                }
            }

    /**
     * Fetches metadata from a URL with improved error handling
     */
    suspend fun fetchMetadata(url: String): CFResult<Map<String, String>> =
            performRequest(url, "GET") { conn ->
                Timber.d("EXECUTING GET METADATA REQUEST")
                if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                    val metadata = conn.headerFields.let { headers ->
                        mapOf(
                                CFConstants.Http.HEADER_LAST_MODIFIED to (headers["Last-Modified"]?.firstOrNull() ?: ""),
                                CFConstants.Http.HEADER_ETAG to (headers["ETag"]?.firstOrNull() ?: "")
                        )
                    }
                    // Since we're using GET instead of HEAD, we need to read the response to ensure the connection is released
                    conn.inputStream.bufferedReader().readText()
                    Timber.d("GET METADATA SUCCESSFUL: $metadata")
                    CFResult.success(metadata)
                } else {
                    val message = "Failed to fetch metadata from $url: ${conn.responseCode}"
                    Timber.w("GET METADATA FAILED: $message")
                    ErrorHandler.handleError(
                        message, 
                        SOURCE, 
                        ErrorHandler.ErrorCategory.NETWORK
                    )
                    CFResult.error(message, code = conn.responseCode, category = ErrorHandler.ErrorCategory.NETWORK)
                }
            } ?: CFResult.error("Network error fetching metadata from $url", category = ErrorHandler.ErrorCategory.NETWORK)

    /**
     * Fetches JSON from a URL with improved error handling
     */
    suspend fun fetchJson(url: String): CFResult<JsonObject> =
            performRequest(url, "GET") { conn ->
                Timber.d("EXECUTING GET JSON REQUEST")
                if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                    try {
                        val responseText = conn.inputStream.bufferedReader().readText()
                        // Parse using kotlinx.serialization and cast to JsonObject
                        val jsonElement = Json.parseToJsonElement(responseText)
                        if (jsonElement is JsonObject) {
                            Timber.d("GET JSON SUCCESSFUL")
                            CFResult.success(jsonElement)
                        } else {
                            val message = "Parsed JSON from $url is not an object"
                            Timber.w("GET JSON FAILED: $message")
                            ErrorHandler.handleError(
                                message, 
                                SOURCE, 
                                ErrorHandler.ErrorCategory.SERIALIZATION
                            )
                            CFResult.error(message, category = ErrorHandler.ErrorCategory.SERIALIZATION)
                        }
                    } catch (e: Exception) {
                        Timber.e("GET JSON FAILED: ${e.message}")
                        ErrorHandler.handleException(
                            e, 
                            "Error parsing JSON response from $url", 
                            SOURCE,
                            ErrorHandler.ErrorSeverity.HIGH
                        )
                        CFResult.error("Error parsing JSON response", e, category = ErrorHandler.ErrorCategory.SERIALIZATION)
                    }
                } else {
                    val message = "Failed to fetch JSON from $url: ${conn.responseCode}"
                    Timber.w("GET JSON FAILED: $message")
                    ErrorHandler.handleError(
                        message, 
                        SOURCE, 
                        ErrorHandler.ErrorCategory.NETWORK
                    )
                    CFResult.error(message, code = conn.responseCode, category = ErrorHandler.ErrorCategory.NETWORK)
                }
            } ?: CFResult.error("Network error fetching JSON from $url", category = ErrorHandler.ErrorCategory.NETWORK)

    /**
     * Posts JSON to a URL with improved error handling and detailed logging
     */
    suspend fun postJson(url: String, payload: String): CFResult<Boolean> =
            performRequest(url, "POST", mapOf(CFConstants.Http.HEADER_CONTENT_TYPE to CFConstants.Http.CONTENT_TYPE_JSON), payload) { conn ->
                Timber.d("EXECUTING POST JSON REQUEST")
                val responseCode = conn.responseCode

                try {
                    if (responseCode == HttpURLConnection.HTTP_OK ||
                                    responseCode == HttpURLConnection.HTTP_ACCEPTED
                    ) {
                        val responseBody = conn.inputStream.bufferedReader().readText()
                        Timber.d("POST JSON SUCCESSFUL")
                        CFResult.success(true)
                    } else {
                        val errorBody = conn.errorStream?.bufferedReader()?.readText() ?: "No error body"
                        
                        // Use our error handling system
                        val message = "API error response: ${conn.responseCode}"
                        Timber.w("POST JSON FAILED: $message - $errorBody")
                        ErrorHandler.handleError(
                            "$message - $errorBody", 
                            SOURCE, 
                            ErrorHandler.ErrorCategory.NETWORK, 
                            ErrorHandler.ErrorSeverity.HIGH
                        )
                        
                        Timber.e("Error: $errorBody")
                        CFResult.error(message, code = conn.responseCode, category = ErrorHandler.ErrorCategory.NETWORK)
                    }
                } catch (e: Exception) {
                    Timber.e("POST JSON FAILED: ${e.message}")
                    ErrorHandler.handleException(
                        e, 
                        "Failed to read API response", 
                        SOURCE,
                        ErrorHandler.ErrorSeverity.HIGH
                    )
                    CFResult.error("Failed to read API response", e, category = ErrorHandler.ErrorCategory.NETWORK)
                }
            } ?: CFResult.error("Network error posting JSON to $url", category = ErrorHandler.ErrorCategory.NETWORK)

    /**
     * Performs a HEAD request to efficiently check for metadata changes
     * Only fetches headers without downloading the full response body
     */
    suspend fun makeHeadRequest(url: String): CFResult<Map<String, String>> {
        return withContext(Dispatchers.IO) {
            try {
                Timber.i("API POLL: HEAD request to $url")
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.requestMethod = "HEAD"
                connection.connectTimeout = CFConstants.Network.CONNECTION_TIMEOUT_MS
                connection.readTimeout = CFConstants.Network.READ_TIMEOUT_MS
                Timber.d("EXECUTING HEAD REQUEST")
                
                // Apply retry and timeout logic if needed
                val responseCode = connection.responseCode
                
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    // Extract headers
                    val headers = mutableMapOf<String, String>()
                    
                    // Get Last-Modified header which is crucial for caching
                    connection.getHeaderField(CFConstants.Http.HEADER_LAST_MODIFIED)?.let {
                        headers[CFConstants.Http.HEADER_LAST_MODIFIED] = it
                    }
                    
                    // Get ETag header for additional caching support
                    connection.getHeaderField(CFConstants.Http.HEADER_ETAG)?.let {
                        headers[CFConstants.Http.HEADER_ETAG] = it
                    }
                    
                    Timber.i("API POLL: HEAD request successful - Last-Modified: ${headers[CFConstants.Http.HEADER_LAST_MODIFIED]}, ETag: ${headers[CFConstants.Http.HEADER_ETAG]}")
                    return@withContext CFResult.success(headers)
                } else {
                    Timber.w("API POLL: HEAD request failed with code: $responseCode")
                    return@withContext CFResult.error(
                        "HEAD request failed with code: $responseCode",
                        category = ErrorHandler.ErrorCategory.NETWORK
                    )
                }
            } catch (e: Exception) {
                Timber.e("API POLL: HEAD request exception: ${e.message}")
                return@withContext CFResult.error(
                    "HEAD request failed with exception: ${e.message}",
                    e,
                    category = ErrorHandler.ErrorCategory.NETWORK
                )
            }
        }
    }

}
