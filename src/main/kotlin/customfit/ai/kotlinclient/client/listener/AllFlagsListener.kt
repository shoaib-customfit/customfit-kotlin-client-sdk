package customfit.ai.kotlinclient.client

/**
 * An interface for objects that will be notified when any feature flag changes.
 * Register instances of this with [CFClient.registerAllFlagsListener].
 */
interface AllFlagsListener {
    /**
     * Called when any feature flag changes.
     *
     * @param flagMap a map of all current feature flags
     */
    fun onFlagsChange(flagMap: Map<String, Any>)
} 