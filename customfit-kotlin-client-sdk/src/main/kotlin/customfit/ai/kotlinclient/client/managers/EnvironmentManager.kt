package customfit.ai.kotlinclient.client.managers

import customfit.ai.kotlinclient.core.model.ApplicationInfo
import customfit.ai.kotlinclient.core.model.DeviceContext
import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.platform.ApplicationInfoDetector
import customfit.ai.kotlinclient.platform.AppState
import customfit.ai.kotlinclient.platform.AppStateListener
import customfit.ai.kotlinclient.platform.BackgroundStateMonitor
import customfit.ai.kotlinclient.platform.BatteryState
import customfit.ai.kotlinclient.platform.BatteryStateListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Interface for managing environment information (device, application, background state, etc.)
 */
interface EnvironmentManager {
    /**
     * Initialize environment information
     */
    fun initialize(autoDetectEnabled: Boolean)
    
    /**
     * Get device context
     */
    fun getDeviceContext(): DeviceContext
    
    /**
     * Get application info
     */
    fun getApplicationInfo(): ApplicationInfo?
    
    /**
     * Detect and update device and application information
     */
    fun detectEnvironmentInfo(forceUpdate: Boolean = false)
    
    /**
     * Get current app state (foreground/background)
     */
    fun getCurrentAppState(): AppState
    
    /**
     * Get current battery state
     */
    fun getCurrentBatteryState(): BatteryState
    
    /**
     * Add app state listener
     */
    fun addAppStateListener(listener: AppStateListener)
    
    /**
     * Add battery state listener
     */
    fun addBatteryStateListener(listener: BatteryStateListener)
    
    /**
     * Cleanup resources
     */
    fun shutdown()
}

/**
 * Implementation of EnvironmentManager that handles environment information
 */
class EnvironmentManagerImpl(
    private val backgroundStateMonitor: BackgroundStateMonitor,
    private val userManager: UserManager,
    private val clientScope: CoroutineScope
) : EnvironmentManager {
    
    private var autoDetectEnabled: Boolean = false
    
    override fun initialize(autoDetectEnabled: Boolean) {
        this.autoDetectEnabled = autoDetectEnabled
        if (autoDetectEnabled) {
            detectEnvironmentInfo(true)
        }
    }
    
    override fun getDeviceContext(): DeviceContext = userManager.getDeviceContext()
    
    override fun getApplicationInfo(): ApplicationInfo? = userManager.getApplicationInfo()
    
    override fun detectEnvironmentInfo(forceUpdate: Boolean) {
        if (!autoDetectEnabled && !forceUpdate) {
            Timber.d("Auto environment detection disabled, skipping")
            return
        }
        
        // Detect application info if not already set
        val currentAppInfo = userManager.getApplicationInfo()
        if (currentAppInfo == null || forceUpdate) {
            clientScope.launch {
                try {
                    val detectedAppInfo = ApplicationInfoDetector.detectApplicationInfo()
                    if (detectedAppInfo != null) {
                        userManager.setApplicationInfo(detectedAppInfo)
                        Timber.d("Auto-detected application info: $detectedAppInfo")
                    }
                } catch (e: Exception) {
                    Timber.e(e, "Failed to detect application info: ${e.message}")
                }
            }
        } else {
            Timber.d("Using existing application info")
        }
        
        // Device context is always initialized in UserManager
    }
    
    override fun getCurrentAppState(): AppState = backgroundStateMonitor.getCurrentAppState()
    
    override fun getCurrentBatteryState(): BatteryState = backgroundStateMonitor.getCurrentBatteryState()
    
    override fun addAppStateListener(listener: AppStateListener) {
        backgroundStateMonitor.addAppStateListener(listener)
    }
    
    override fun addBatteryStateListener(listener: BatteryStateListener) {
        backgroundStateMonitor.addBatteryStateListener(listener)
    }
    
    override fun shutdown() {
        backgroundStateMonitor.shutdown()
    }
} 