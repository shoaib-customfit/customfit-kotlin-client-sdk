package customfit.ai.kotlinclient.client

import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import mu.KotlinLogging

private val logger = KotlinLogging.logger {}

/**
 * Represents the application's state
 */
enum class AppState {
    /**
     * App is in the foreground and visible to the user
     */
    FOREGROUND,
    
    /**
     * App is in the background (not visible)
     */
    BACKGROUND
}

/**
 * Interface for battery state
 */
data class BatteryState(
    val isLow: Boolean,
    val isCharging: Boolean,
    val level: Float // 0.0 to 1.0
)

/**
 * Interface for objects that will be notified when app state changes
 */
interface AppStateListener {
    /**
     * Called when the app state changes
     * 
     * @param state the new app state
     */
    fun onAppStateChange(state: AppState)
}

/**
 * Interface for objects that will be notified when battery state changes
 */
interface BatteryStateListener {
    /**
     * Called when the battery state changes
     * 
     * @param state the new battery state
     */
    fun onBatteryStateChange(state: BatteryState)
}

/**
 * Interface for monitoring application foreground/background state
 * and battery level. Implementation will be platform-specific.
 */
interface BackgroundStateMonitor {
    /**
     * Get the current app state
     */
    fun getCurrentAppState(): AppState
    
    /**
     * Get the current battery state
     */
    fun getCurrentBatteryState(): BatteryState
    
    /**
     * Register a listener for app state changes
     */
    fun addAppStateListener(listener: AppStateListener)
    
    /**
     * Unregister a listener for app state changes
     */
    fun removeAppStateListener(listener: AppStateListener)
    
    /**
     * Register a listener for battery state changes
     */
    fun addBatteryStateListener(listener: BatteryStateListener)
    
    /**
     * Unregister a listener for battery state changes
     */
    fun removeBatteryStateListener(listener: BatteryStateListener)
    
    /**
     * Clean up resources
     */
    fun shutdown()
}

/**
 * Default implementation of BackgroundStateMonitor that assumes foreground
 * and normal battery state. This is used when no platform-specific
 * implementation is provided.
 */
class DefaultBackgroundStateMonitor : BackgroundStateMonitor {
    private val appStateListeners = CopyOnWriteArrayList<AppStateListener>()
    private val batteryStateListeners = CopyOnWriteArrayList<BatteryStateListener>()
    private val scope = CoroutineScope(Dispatchers.Default)
    
    // Default states
    private val defaultAppState = AppState.FOREGROUND
    private val defaultBatteryState = BatteryState(
        isLow = false,
        isCharging = true,
        level = 1.0f
    )
    
    override fun getCurrentAppState(): AppState = defaultAppState
    
    override fun getCurrentBatteryState(): BatteryState = defaultBatteryState
    
    override fun addAppStateListener(listener: AppStateListener) {
        appStateListeners.add(listener)
        // Notify immediately with current state
        scope.launch {
            listener.onAppStateChange(defaultAppState)
        }
    }
    
    override fun removeAppStateListener(listener: AppStateListener) {
        appStateListeners.remove(listener)
    }
    
    override fun addBatteryStateListener(listener: BatteryStateListener) {
        batteryStateListeners.add(listener)
        // Notify immediately with current state
        scope.launch {
            listener.onBatteryStateChange(defaultBatteryState)
        }
    }
    
    override fun removeBatteryStateListener(listener: BatteryStateListener) {
        batteryStateListeners.remove(listener)
    }
    
    override fun shutdown() {
        appStateListeners.clear()
        batteryStateListeners.clear()
    }
} 