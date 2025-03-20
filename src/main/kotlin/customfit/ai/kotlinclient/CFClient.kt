package customfit.ai.kotlinclient

import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject
import java.security.MessageDigest
import java.util.*
import kotlin.concurrent.fixedRateTimer

class CFClient private constructor(
    private val config: CFConfig,
    private val user: CFUser
) {

    private var previousSdkSettingsHash: String? = null
    private var previousLastModified: String? = null  // Store Last-Modified timestamp

    init {
        println("CFClient initialized with config: $config and user: $user")
        // Start periodic check every 5 minutes
        startSdkSettingsCheck()
    }

    // Function to check for updates every 5 minutes
    private fun startSdkSettingsCheck() {
        fixedRateTimer("SdkSettingsCheck", daemon = true, period = 300_000) { // 5 minutes = 300,000 ms
            checkSdkSettings()
        }
    }

    // Function to check the SDK settings by calling CloudFront API
    private suspend fun checkSdkSettings() {
        val metadata = fetchSdkSettingsMetadata()
        if (metadata != null) {
            val currentLastModified = metadata["Last-Modified"]
            // If the Last-Modified timestamp has changed, re-fetch the settings
            if (currentLastModified != previousLastModified) {
                println("SDK Settings have changed, re-fetching configurations.")
                fetchConfigs() // Re-fetch the configurations if settings have changed
                previousLastModified = currentLastModified
            }
        }
    }

    // Function to fetch the metadata (Last-Modified or ETag) from CloudFront API
    private suspend fun fetchSdkSettingsMetadata(): Map<String, String>? {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/sdk-settings")  // Replace with actual URL to CloudFront API
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "HEAD"  // HEAD request to fetch only metadata
                connection.connect()

                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    // Get headers from the response
                    val headers = connection.headerFields

                    // Get the Last-Modified or ETag header
                    val lastModified = headers["Last-Modified"]?.firstOrNull()
                    val eTag = headers["ETag"]?.firstOrNull()

                    // We can use either `Last-Modified` or `ETag` for comparison
                    return@withContext mapOf("Last-Modified" to lastModified ?: "")
                } else {
                    println("Error fetching SDK Settings metadata: ${connection.responseCode}")
                    return@withContext null
                }
            } catch (e: Exception) {
                e.printStackTrace()
                return@withContext null
            }
        }
    }

    // Function to fetch SDK settings from CloudFront API (full content)
    private suspend fun fetchSdkSettings(): SdkSettings? {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/sdk-settings")  // Replace with actual URL to CloudFront API
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connect()

                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().readText()
                    val jsonResponse = JSONObject(response)

                    val sdkSettings = SdkSettings.builder()
                        .cf_key(jsonResponse.getString("cf_key"))
                        .cf_account_enabled(jsonResponse.getBoolean("cf_account_enabled"))
                        .cf_skip_sdk(jsonResponse.getBoolean("cf_skip_sdk"))
                        // Map other fields as needed
                        .build()

                    if (!sdkSettings.cf_account_enabled || sdkSettings.cf_skip_sdk) {
                        println("Account is disabled or SDK is skipped. No further processing.")
                        return@withContext null
                    }
                    return@withContext sdkSettings
                } else {
                    println("Error fetching SDK Settings: ${connection.responseCode}")
                    return@withContext null
                }
            } catch (e: Exception) {
                e.printStackTrace()
                return@withContext null
            }
        }
    }

    // Function to make the API request to fetch configurations
    private suspend fun fetchConfigs(): Map<String, Any>? {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://example.com/v1/users/configs?cfenc=${config.clientKey}")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                val userJson = JSONObject(user.properties).toString()
                val jsonInputString = """{
                    "user": $userJson
                }"""

                connection.outputStream.use { os ->
                    val input = jsonInputString.toByteArray(Charsets.UTF_8)
                    os.write(input, 0, input.size)
                }

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().readText()
                    println("Response: $response")

                    // Parse the JSON response
                    val jsonResponse = JSONObject(response)
                    val configs = jsonResponse.getJSONObject("configs")

                    // Map the configurations as key-value pairs
                    val configMap = mutableMapOf<String, Any>()
                    configs.keys().forEach { key ->
                        val config = configs.getJSONObject(key)
                        val experience = config.getJSONObject("experience_behaviour_response")
                        val experienceKey = experience.getString("experience")
                        val variation = config.getJSONObject("variation")
                        configMap[experienceKey] = variation 
                    }
                    return@withContext configMap
                } else {
                    println("Error response code: $responseCode")
                    return@withContext null
                }
            } catch (e: Exception) {
                e.printStackTrace()
                return@withContext null
            }
        }
    }

    companion object {
        fun init(config: CFConfig, user: CFUser): CFClient {
            return CFClient(config, user)
        }
    }
}
