package customfit.ai.kotlinclient.utils

import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.platform.PlatformInfo
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Manages battery state detection and provides polling interval adjustments based on battery status
 */
class BatteryManager {
    companion object {
        private const val LOW_BATTERY_THRESHOLD = 0.15 // 15% battery is considered low

        @Volatile
        private var instance: BatteryManager? = null

        fun getInstance(): BatteryManager {
            return instance ?: synchronized(this) {
                instance ?: BatteryManager().also { instance = it }
            }
        }
    }

    private val isLowBatteryMode = AtomicBoolean(false)
    private val platformInfo = PlatformInfo.getInstance()

    /**
     * Initialize battery monitoring
     */
    fun initialize() {
        try {
            // Run initial battery check
            checkBatteryState()
            
            // On Android and iOS, we'd register for battery state notifications here
            // This is a simplified implementation that relies on periodic checks
            Timber.i("Battery monitoring initialized")
        } catch (e: Exception) {
            Timber.e(e, "Failed to initialize battery monitoring: ${e.message}")
        }
    }

    /**
     * Check current battery state and update low battery mode flag
     */
    fun checkBatteryState() {
        try {
            val batteryInfo = platformInfo.getBatteryInfo()
            val batteryLevel = batteryInfo?.level ?: 1.0
            val isCharging = batteryInfo?.isCharging ?: true
            
            val newLowBatteryMode = !isCharging && batteryLevel <= LOW_BATTERY_THRESHOLD
            val previousMode = isLowBatteryMode.getAndSet(newLowBatteryMode)
            
            if (newLowBatteryMode != previousMode) {
                if (newLowBatteryMode) {
                    Timber.i("Device entered low battery mode (${(batteryLevel * 100).toInt()}%)")
                } else {
                    Timber.i("Device exited low battery mode (${(batteryLevel * 100).toInt()}%)")
                }
            }
            
            Timber.d("Battery check: level=${(batteryLevel * 100).toInt()}%, charging=$isCharging, low mode=$newLowBatteryMode")
        } catch (e: Exception) {
            Timber.e(e, "Failed to check battery state: ${e.message}")
        }
    }

    /**
     * Returns true if the device is in low battery mode
     */
    fun isLowBatteryMode(): Boolean {
        return isLowBatteryMode.get()
    }

    /**
     * Get the appropriate polling interval based on battery state and config
     *
     * @param normalIntervalMs The normal polling interval in milliseconds
     * @param reducedIntervalMs The reduced polling interval for low battery in milliseconds
     * @param useReducedWhenLow Whether to use reduced interval when battery is low
     * @return The appropriate polling interval in milliseconds
     */
    fun getPollingInterval(
        normalIntervalMs: Long,
        reducedIntervalMs: Long,
        useReducedWhenLow: Boolean
    ): Long {
        // Check battery again to ensure we have current state
        checkBatteryState()
        
        // If we should use reduced rate and battery is low, return the reduced interval
        if (useReducedWhenLow && isLowBatteryMode()) {
            Timber.d("Using reduced polling interval due to low battery: $reducedIntervalMs ms")
            return reducedIntervalMs
        }
        
        // Otherwise use normal interval
        return normalIntervalMs
    }

    /**
     * Shutdown and cleanup resources
     */
    fun shutdown() {
        // Unregister any battery callbacks here if needed
        Timber.d("Battery monitoring shutdown")
    }
} 