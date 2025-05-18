package customfit.ai.kotlinclient.platform

import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.logging.Timber
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * Collects environment attributes about the device and application
 * Used when autoEnvAttributesEnabled is true in CFConfig
 */
class EnvironmentAttributesCollector(private val config: CFConfig) {
    companion object {
        private const val TAG = "EnvAttributes"
    }
    
    // Platform info provider
    private val platformInfo = PlatformInfo.getInstance()
    
    // Generate a unique installation ID if needed
    private val installationId by lazy { UUID.randomUUID().toString() }
    
    /**
     * Collect environment attributes if enabled in config
     * Returns an empty map if collection is disabled
     */
    fun collectAttributes(): Map<String, Any> {
        if (!config.autoEnvAttributesEnabled) {
            Timber.d("Environment attributes collection is disabled in config")
            return emptyMap()
        }
        
        Timber.d("Collecting environment attributes")
        
        val attributes = mutableMapOf<String, Any>()
        
        try {
            // Add common attributes
            attributes.putAll(collectCommonAttributes())
            
            // Add device info
            attributes.putAll(collectDeviceInfo())
            
            // Add app info
            attributes.putAll(collectAppInfo())
            
            Timber.d("Collected ${attributes.size} environment attributes")
        } catch (e: Exception) {
            Timber.e(e, "Error collecting environment attributes: ${e.message}")
        }
        
        return attributes
    }
    
    /**
     * Collect common attributes like locale, timezone, etc.
     */
    private fun collectCommonAttributes(): Map<String, Any> {
        val attributes = mutableMapOf<String, Any>()
        
        try {
            // Add common attributes
            attributes["install_id"] = installationId
            attributes["locale"] = Locale.getDefault().toString()
            attributes["timezone"] = TimeZone.getDefault().id
            attributes["timezone_offset_mins"] = TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60000
        } catch (e: Exception) {
            Timber.e(e, "Error collecting common attributes: ${e.message}")
        }
        
        return attributes
    }
    
    /**
     * Collect device information like OS, model, etc.
     */
    private fun collectDeviceInfo(): Map<String, Any> {
        val attributes = mutableMapOf<String, Any>()
        
        try {
            // Get device info from platform provider
            val deviceInfo = platformInfo.getDeviceInfo()
            
            // Add device info to attributes
            attributes["device_platform"] = deviceInfo["platform"] ?: "unknown"
            attributes["device_os_version"] = deviceInfo["os_version"] ?: "unknown"
            attributes["device_model"] = deviceInfo["device_model"] ?: "unknown"
            attributes["sdk_platform"] = deviceInfo["sdk_platform"] ?: "kotlin"
            
            // Get network type
            val networkType = platformInfo.getNetworkConnectionType()
            attributes["network_type"] = networkType
        } catch (e: Exception) {
            Timber.e(e, "Error collecting device info: ${e.message}")
        }
        
        return attributes
    }
    
    /**
     * Collect application information like version, build, etc.
     */
    private fun collectAppInfo(): Map<String, Any> {
        val attributes = mutableMapOf<String, Any>()
        
        try {
            // In a real implementation, these would come from runtime app info
            // For now, we just use placeholders to demonstrate the concept
            attributes["app_version"] = "unknown"
            attributes["app_build"] = "unknown"
            attributes["app_id"] = "unknown"
        } catch (e: Exception) {
            Timber.e(e, "Error collecting app info: ${e.message}")
        }
        
        return attributes
    }
} 