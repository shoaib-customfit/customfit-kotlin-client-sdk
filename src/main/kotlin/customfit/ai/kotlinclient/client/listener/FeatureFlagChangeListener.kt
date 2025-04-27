package customfit.ai.kotlinclient.client

/**
 * An interface for objects that will be notified when a feature flag's value changes.
 * Register instances of this with [CFClient.registerFeatureFlagListener].
 */
interface FeatureFlagChangeListener {
    /**
     * Called when the value of a feature flag changes.
     *
     * @param flagKey the flag that changed
     * @param newValue the new value of the flag
     */
    fun onFeatureFlagChange(flagKey: String, newValue: Any)
} 