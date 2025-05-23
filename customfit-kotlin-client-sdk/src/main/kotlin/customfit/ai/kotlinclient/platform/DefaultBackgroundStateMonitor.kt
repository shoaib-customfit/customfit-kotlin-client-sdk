package customfit.ai.kotlinclient.platform

import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Default implementation of BackgroundStateMonitor that assumes foreground and normal battery
 * state. This is used when no platform-specific implementation is provided.
 */
class DefaultBackgroundStateMonitor : BackgroundStateMonitor {
    private val appStateListeners = CopyOnWriteArrayList<AppStateListener>()
    private val batteryStateListeners = CopyOnWriteArrayList<BatteryStateListener>()
    private val scope = CoroutineScope(Dispatchers.Default)

    // Default states
    private val defaultAppState = AppState.FOREGROUND
    private val defaultBatteryState = BatteryState(isLow = false, isCharging = true, level = 1.0f)

    override fun getCurrentAppState(): AppState = defaultAppState

    override fun getCurrentBatteryState(): BatteryState = defaultBatteryState

    override fun addAppStateListener(listener: AppStateListener) {
        appStateListeners.add(listener)
        // Notify immediately with current state
        scope.launch { listener.onAppStateChange(defaultAppState) }
    }

    override fun removeAppStateListener(listener: AppStateListener) {
        appStateListeners.remove(listener as Any)
    }

    override fun addBatteryStateListener(listener: BatteryStateListener) {
        batteryStateListeners.add(listener)
        // Notify immediately with current state
        scope.launch { listener.onBatteryStateChange(defaultBatteryState) }
    }

    override fun removeBatteryStateListener(listener: BatteryStateListener) {
        batteryStateListeners.remove(listener as Any)
    }

    override fun shutdown() {
        appStateListeners.clear()
        batteryStateListeners.clear()
    }
}
