package customfit.ai.kotlinclient.platform

/** Represents the application's state */
enum class AppState {
    /** App is in the foreground and visible to the user */
    FOREGROUND,

    /** App is in the background (not visible) */
    BACKGROUND
}

/** Interface for battery state */
data class BatteryState(
        val isLow: Boolean,
        val isCharging: Boolean,
        val level: Float // 0.0 to 1.0
)

/** Interface for objects that will be notified when app state changes */
interface AppStateListener {
    /**
     * Called when the app state changes
     *
     * @param state the new app state
     */
    fun onAppStateChange(state: AppState)
}

/** Interface for objects that will be notified when battery state changes */
interface BatteryStateListener {
    /**
     * Called when the battery state changes
     *
     * @param state the new battery state
     */
    fun onBatteryStateChange(state: BatteryState)
}

/**
 * Interface for monitoring application foreground/background state and battery level.
 * Implementation will be platform-specific.
 */
interface BackgroundStateMonitor {
    /** Get the current app state */
    fun getCurrentAppState(): AppState

    /** Get the current battery state */
    fun getCurrentBatteryState(): BatteryState

    /** Register a listener for app state changes */
    fun addAppStateListener(listener: AppStateListener)

    /** Unregister a listener for app state changes */
    fun removeAppStateListener(listener: AppStateListener)

    /** Register a listener for battery state changes */
    fun addBatteryStateListener(listener: BatteryStateListener)

    /** Unregister a listener for battery state changes */
    fun removeBatteryStateListener(listener: BatteryStateListener)

    /** Clean up resources */
    fun shutdown()
}
