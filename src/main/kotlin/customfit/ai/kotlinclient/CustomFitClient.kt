package customfit.ai.kotlinclient

/**
 * Dummy Feature Flag Client for CustomFit.ai.
 *
 * Usage example:
 *
 * val client = CustomFitClient.init("some-token")
 * val flagValue = client.getFlagValue("my-feature-key", "default-value")
 * println("Flag value: $flagValue")
 */
class CustomFitClient private constructor(
    private val token: String
) {

    init {
        // In a real client, you might store the token, set up network, etc.
        println("CustomFitClient initialized with token: $token")
    }

    /**
     * Get the flag value for a given [key].
     * If the flag is not found (or some other fallback condition),
     * returns [defaultValue].
     */
    fun getFlagValue(key: String, defaultValue: String): String {
        // Dummy logic for now:
        // In a real scenario, you'd fetch from your service or local cache
        return "mocked-value-for-$key"
    }

    companion object {
        /**
         * Use this method to create or initialize the SDK with the provided [token].
         */
        fun init(token: String): CustomFitClient {
            // You can do more initialization logic here if needed.
            return CustomFitClient(token)
        }
    }
}
