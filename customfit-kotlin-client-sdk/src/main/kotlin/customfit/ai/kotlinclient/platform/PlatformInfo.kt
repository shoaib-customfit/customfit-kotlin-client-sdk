package customfit.ai.kotlinclient.platform

import customfit.ai.kotlinclient.logging.Timber

/**
 * Data class for battery information
 */
data class BatteryInfo(
    val level: Double, // 0.0 to 1.0, representing battery percentage
    val isCharging: Boolean
)

/**
 * Platform information provider that handles platform-specific operations
 * This abstracts platform differences between Android, iOS, and other platforms
 */
class PlatformInfo {
    companion object {
        @Volatile
        private var instance: PlatformInfo? = null

        fun getInstance(): PlatformInfo {
            return instance ?: synchronized(this) {
                instance ?: PlatformInfo().also { instance = it }
            }
        }
    }

    /**
     * Get current battery information if available on this platform
     * Returns null if battery information cannot be determined
     */
    fun getBatteryInfo(): BatteryInfo? {
        // This is a stub that would be implemented differently per platform
        // In a real implementation, Android would use BatteryManager, iOS would use UIDevice, etc.
        try {
            // Attempt to get platform-specific battery info
            // For now, just return a simulated value
            return simulateBatteryInfo()
        } catch (e: Exception) {
            Timber.e(e, "Error getting battery info: ${e.message}")
            return null
        }
    }

    /**
     * Get device information for tracking and analytics
     */
    fun getDeviceInfo(): Map<String, String> {
        val deviceInfo = mutableMapOf<String, String>()
        
        try {
            // Add basic platform info that should be safe across platforms
            deviceInfo["platform"] = getPlatformName()
            deviceInfo["os_version"] = getOSVersion()
            deviceInfo["device_model"] = getDeviceModel()
            deviceInfo["sdk_platform"] = "kotlin"
            
            // Add more platform-specific info here
        } catch (e: Exception) {
            Timber.e(e, "Error gathering device info: ${e.message}")
        }
        
        return deviceInfo
    }

    /**
     * Get network connection type (wifi, cellular, none)
     */
    fun getNetworkConnectionType(): String {
        // Stub implementation - would be platform-specific
        return "unknown"
    }

    /**
     * Get platform name (Android, iOS, Web, etc.)
     */
    private fun getPlatformName(): String {
        // Determine platform - would be set differently for each platform
        val platform = System.getProperty("os.name") ?: "Unknown"
        return when {
            platform.contains("Android", ignoreCase = true) -> "Android"
            platform.contains("iOS", ignoreCase = true) -> "iOS" 
            platform.contains("Mac", ignoreCase = true) -> "macOS"
            platform.contains("Windows", ignoreCase = true) -> "Windows"
            platform.contains("Linux", ignoreCase = true) -> "Linux"
            else -> platform
        }
    }

    /**
     * Get OS version
     */
    private fun getOSVersion(): String {
        return System.getProperty("os.version") ?: "Unknown"
    }

    /**
     * Get device model
     */
    private fun getDeviceModel(): String {
        // This would be platform-specific
        return "Unknown"
    }

    /**
     * Simulate battery info for testing
     * In a real implementation, this would be replaced with actual platform-specific code
     */
    private fun simulateBatteryInfo(): BatteryInfo {
        // For testing purposes only - simulates a battery level between 10% and 100%
        val level = 0.1 + (Math.random() * 0.9)
        val isCharging = Math.random() > 0.3 // 70% chance of being plugged in
        
        return BatteryInfo(level, isCharging)
    }
} 