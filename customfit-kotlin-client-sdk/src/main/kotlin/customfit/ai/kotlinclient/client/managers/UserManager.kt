package customfit.ai.kotlinclient.client.managers

import customfit.ai.kotlinclient.core.model.ApplicationInfo
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.core.model.ContextType
import customfit.ai.kotlinclient.core.model.DeviceContext
import customfit.ai.kotlinclient.core.model.EvaluationContext
import customfit.ai.kotlinclient.logging.Timber
import java.util.Date
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Interface for managing user operations
 */
interface UserManager {
    /**
     * Get the current user
     */
    fun getUser(): CFUser
    
    /**
     * Update the current user
     */
    fun updateUser(user: CFUser)
    
    /**
     * Add a property to the user
     */
    fun addUserProperty(key: String, value: Any)
    
    /**
     * Add a string property to the user
     */
    fun addStringProperty(key: String, value: String)
    
    /**
     * Add a number property to the user
     */
    fun addNumberProperty(key: String, value: Number)
    
    /**
     * Add a boolean property to the user
     */
    fun addBooleanProperty(key: String, value: Boolean)
    
    /**
     * Add a date property to the user
     */
    fun addDateProperty(key: String, value: Date)
    
    /**
     * Add a geolocation property to the user
     */
    fun addGeoPointProperty(key: String, lat: Double, lon: Double)
    
    /**
     * Add a JSON property to the user
     */
    fun addJsonProperty(key: String, value: Map<String, Any>)
    
    /**
     * Add multiple properties to the user
     */
    fun addUserProperties(properties: Map<String, Any>)
    
    /**
     * Get all user properties
     */
    fun getUserProperties(): Map<String, Any>
    
    /**
     * Set the device context for the user
     */
    fun setDeviceContext(deviceContext: DeviceContext)
    
    /**
     * Get the current device context
     */
    fun getDeviceContext(): DeviceContext
    
    /**
     * Set the application info for the user
     */
    fun setApplicationInfo(appInfo: ApplicationInfo)
    
    /**
     * Get the current application info
     */
    fun getApplicationInfo(): ApplicationInfo?
    
    /**
     * Increment the application launch count
     */
    fun incrementAppLaunchCount()
    
    /**
     * Add an evaluation context to the user
     */
    fun addContext(context: EvaluationContext)
    
    /**
     * Remove an evaluation context from the user
     */
    fun removeContext(type: ContextType, key: String)
    
    /**
     * Get all evaluation contexts for the user
     */
    fun getContexts(): List<EvaluationContext>
}

/**
 * Implementation of UserManager that handles user-related operations
 */
class UserManagerImpl(initialUser: CFUser) : UserManager {
    private var user: CFUser = initialUser
    private var deviceContext: DeviceContext = initialUser.getDeviceContext() ?: DeviceContext.createBasic()
    private var applicationInfo: ApplicationInfo? = initialUser.getApplicationInfo()
    private val contexts = ConcurrentHashMap<String, EvaluationContext>()
    
    init {
        // Initialize from the user's properties
        // Add main user context
        val userContext = EvaluationContext(
            type = ContextType.USER,
            key = user.user_customer_id ?: UUID.randomUUID().toString(),
            properties = user.properties
        )
        contexts["user"] = userContext
        
        // Update user with the context
        user = user.addContext(userContext)
        
        // Initialize device and application contexts
        updateUserWithDeviceContext()
    }
    
    override fun getUser(): CFUser = user
    
    override fun updateUser(user: CFUser) {
        this.user = user
        Timber.d("User updated")
    }
    
    override fun addUserProperty(key: String, value: Any) {
        user = user.addProperty(key, value)
        Timber.d("Added user property: $key = $value")
    }
    
    override fun addStringProperty(key: String, value: String) {
        require(value.isNotBlank()) { "String value for '$key' cannot be blank" }
        addUserProperty(key, value)
    }
    
    override fun addNumberProperty(key: String, value: Number) {
        addUserProperty(key, value)
    }
    
    override fun addBooleanProperty(key: String, value: Boolean) {
        addUserProperty(key, value)
    }
    
    override fun addDateProperty(key: String, value: Date) {
        addUserProperty(key, value)
    }
    
    override fun addGeoPointProperty(key: String, lat: Double, lon: Double) {
        addUserProperty(key, mapOf("lat" to lat, "lon" to lon))
    }
    
    override fun addJsonProperty(key: String, value: Map<String, Any>) {
        val jsonCompatible = value.filterValues { isJsonCompatible(it) }
        addUserProperty(key, jsonCompatible)
    }
    
    override fun addUserProperties(properties: Map<String, Any>) {
        user = user.addProperties(properties)
        Timber.d("Added ${properties.size} user properties")
    }
    
    override fun getUserProperties(): Map<String, Any> = user.getCurrentProperties()
    
    override fun setDeviceContext(deviceContext: DeviceContext) {
        this.deviceContext = deviceContext
        updateUserWithDeviceContext()
        Timber.d("Device context updated: $deviceContext")
    }
    
    override fun getDeviceContext(): DeviceContext = deviceContext
    
    override fun setApplicationInfo(appInfo: ApplicationInfo) {
        this.applicationInfo = appInfo
        updateUserWithApplicationInfo(appInfo)
        Timber.d("Application info updated: $appInfo")
    }
    
    override fun getApplicationInfo(): ApplicationInfo? = applicationInfo
    
    override fun incrementAppLaunchCount() {
        val currentAppInfo = applicationInfo ?: return
        val updatedAppInfo = currentAppInfo.copy(launchCount = currentAppInfo.launchCount + 1)
        updateUserWithApplicationInfo(updatedAppInfo)
        Timber.d("Application launch count incremented to: ${updatedAppInfo.launchCount}")
    }
    
    override fun addContext(context: EvaluationContext) {
        contexts[context.type.name.lowercase() + ":" + context.key] = context
        // Update user
        user = user.addContext(context)
        Timber.d("Added evaluation context: ${context.type}:${context.key}")
    }
    
    override fun removeContext(type: ContextType, key: String) {
        val contextKey = type.name.lowercase() + ":" + key
        contexts.remove(contextKey)
        // Update user
        val userContexts = user.getAllContexts().filter { !(it.type == type && it.key == key) }
        val contextsList = mutableListOf<Map<String, Any?>>()
        userContexts.forEach { contextsList.add(it.toMap()) }
        user = user.addProperty("contexts", contextsList)
        Timber.d("Removed evaluation context: $type:$key")
    }
    
    override fun getContexts(): List<EvaluationContext> = contexts.values.toList()
    
    private fun updateUserWithDeviceContext() {
        val deviceContextMap = deviceContext.toMap()
        if (deviceContextMap.isNotEmpty()) {
            // Update the device context in the user
            user = user.setDeviceContext(deviceContext)
            
            // Also keep the legacy format for backward compatibility
            user = user.addProperty("mobile_device_context", deviceContextMap)
            
            Timber.d("Updated user properties with device context")
        }
    }
    
    private fun updateUserWithApplicationInfo(appInfo: ApplicationInfo) {
        val appInfoMap = appInfo.toMap()
        if (appInfoMap.isNotEmpty()) {
            user = user.setApplicationInfo(appInfo)
            this.applicationInfo = appInfo
            Timber.d("Updated user properties with application info")
        }
    }
    
    private fun isJsonCompatible(value: Any?): Boolean =
        when (value) {
            null -> true
            is String, is Number, is Boolean -> true
            is Map<*, *> ->
                value.keys.all { it is String } && value.values.all { isJsonCompatible(it) }
            is Collection<*> -> value.all { isJsonCompatible(it) }
            else -> false
        }
} 