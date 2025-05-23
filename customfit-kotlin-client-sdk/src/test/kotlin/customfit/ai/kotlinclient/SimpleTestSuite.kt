package customfit.ai.kotlinclient

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Assertions.*
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.model.*
import java.util.*

@DisplayName("CustomFit Kotlin Client SDK - Simple Test Suite")
class SimpleTestSuite {

    @Test
    @DisplayName("Test CFConfig creation")
    fun testCFConfigCreation() {
        val config = CFConfig.fromClientKey("test-client-key")
        
        assertEquals("test-client-key", config.clientKey)
        assertFalse(config.offlineMode)
        assertTrue(config.loggingEnabled)
    }

    @Test
    @DisplayName("Test CFUser creation with builder")
    fun testCFUserCreation() {
        val user = CFUser.builder("test-user-123")
            .withStringProperty("name", "Test User")
            .withNumberProperty("age", 25)
            .withBooleanProperty("active", true)
            .build()
        
        assertEquals("test-user-123", user.user_customer_id)
        assertEquals("Test User", user.properties["name"])
        assertEquals(25, user.properties["age"])
        assertEquals(true, user.properties["active"])
    }

    @Test
    @DisplayName("Test CFUser with device context")
    fun testCFUserWithDeviceContext() {
        val deviceContext = DeviceContext(
            manufacturer = "Google",
            model = "Pixel 6",
            osName = "Android",
            osVersion = "12"
        )
        
        val user = CFUser.builder("test-user")
            .withDeviceContext(deviceContext)
            .build()
        
        assertNotNull(user.device)
        assertEquals("Google", user.device?.manufacturer)
        assertEquals("Pixel 6", user.device?.model)
    }

    @Test
    @DisplayName("Test CFUser with application info")
    fun testCFUserWithApplicationInfo() {
        val appInfo = ApplicationInfo(
            appName = "TestApp",
            versionName = "1.0.0",
            packageName = "com.test.app"
        )
        
        val user = CFUser.builder("test-user")
            .withApplicationInfo(appInfo)
            .build()
        
        assertNotNull(user.application)
        assertEquals("TestApp", user.application?.appName)
        assertEquals("1.0.0", user.application?.versionName)
    }

    @Test
    @DisplayName("Test CFUser with evaluation context")
    fun testCFUserWithEvaluationContext() {
        val context = EvaluationContext(
            type = ContextType.CUSTOM,
            key = "test-context",
            properties = mapOf("attr1" to "value1")
        )
        
        val user = CFUser.builder("test-user")
            .withContext(context)
            .build()
        
        assertEquals(1, user.contexts.size)
        assertEquals(ContextType.CUSTOM, user.contexts[0].type)
        assertEquals("test-context", user.contexts[0].key)
    }

    @Test
    @DisplayName("Test anonymous user creation")
    fun testAnonymousUser() {
        val user = CFUser(anonymous = true)
        
        assertNull(user.user_customer_id)
        assertTrue(user.anonymous)
    }

    @Test
    @DisplayName("Test CFUser property operations")
    fun testCFUserPropertyOperations() {
        val originalUser = CFUser(user_customer_id = "test-user")
        val updatedUser = originalUser.addProperty("newProp", "newValue")
        
        // Original user should be unchanged (immutable)
        assertFalse(originalUser.properties.containsKey("newProp"))
        
        // Updated user should have the new property
        assertTrue(updatedUser.properties.containsKey("newProp"))
        assertEquals("newValue", updatedUser.properties["newProp"])
    }

    @Test
    @DisplayName("Test CFUser toUserMap conversion")
    fun testCFUserToUserMap() {
        val user = CFUser(
            user_customer_id = "test-user",
            properties = mapOf("name" to "John", "age" to 30)
        )
        
        val userMap = user.toUserMap()
        
        assertEquals("test-user", userMap["user_customer_id"])
        assertFalse(userMap["anonymous"] as Boolean)
        
        val properties = userMap["properties"] as Map<*, *>
        assertEquals("John", properties["name"])
        assertEquals(30, properties["age"])
    }

    @Test
    @DisplayName("Test CFConfig builder with custom values")
    fun testCFConfigBuilder() {
        val config = CFConfig.Builder("test-key")
            .eventsQueueSize(500)
            .eventsFlushTimeSeconds(120)
            .offlineMode(true)
            .debugLoggingEnabled(true)
            .build()
        
        assertEquals("test-key", config.clientKey)
        assertEquals(500, config.eventsQueueSize)
        assertEquals(120, config.eventsFlushTimeSeconds)
        assertTrue(config.offlineMode)
        assertTrue(config.debugLoggingEnabled)
    }

    @Test
    @DisplayName("Test DeviceContext creation")
    fun testDeviceContextCreation() {
        val deviceContext = DeviceContext.Builder()
            .manufacturer("Samsung")
            .model("Galaxy S21")
            .osName("Android")
            .osVersion("11")
            .build()
        
        assertEquals("Samsung", deviceContext.manufacturer)
        assertEquals("Galaxy S21", deviceContext.model)
        assertEquals("Android", deviceContext.osName)
        assertEquals("11", deviceContext.osVersion)
    }

    @Test
    @DisplayName("Test ApplicationInfo creation")
    fun testApplicationInfoCreation() {
        val appInfo = ApplicationInfo.Builder()
            .appName("MyApp")
            .packageName("com.example.myapp")
            .versionName("2.0.0")
            .versionCode(20)
            .build()
        
        assertEquals("MyApp", appInfo.appName)
        assertEquals("com.example.myapp", appInfo.packageName)
        assertEquals("2.0.0", appInfo.versionName)
        assertEquals(20, appInfo.versionCode)
    }

    @Test
    @DisplayName("Test EvaluationContext builder")
    fun testEvaluationContextBuilder() {
        val context = EvaluationContext.Builder(ContextType.USER, "user-123")
            .withName("Main User Context")
            .withProperty("role", "admin")
            .withProperty("department", "engineering")
            .addPrivateAttribute("email")
            .build()
        
        assertEquals(ContextType.USER, context.type)
        assertEquals("user-123", context.key)
        assertEquals("Main User Context", context.name)
        assertEquals("admin", context.properties["role"])
        assertEquals("engineering", context.properties["department"])
        assertTrue(context.privateAttributes.contains("email"))
    }

    @Test
    @DisplayName("Test CFUser context operations")
    fun testCFUserContextOperations() {
        val context1 = EvaluationContext(
            type = ContextType.USER,
            key = "user-context",
            properties = mapOf("level" to "premium")
        )
        
        val context2 = EvaluationContext(
            type = ContextType.SESSION,
            key = "session-context", 
            properties = mapOf("duration" to "30min")
        )
        
        val user = CFUser.builder("test-user")
            .withContext(context1)
            .withContext(context2)
            .build()
        
        assertEquals(2, user.contexts.size)
        
        // Test context retrieval
        val allContexts = user.getAllContexts()
        assertEquals(2, allContexts.size)
    }

    @Test
    @DisplayName("Test CFUser immutability")
    fun testCFUserImmutability() {
        val originalUser = CFUser.builder("test-user")
            .withStringProperty("name", "Original")
            .build()
        
        // Adding properties should return new instance
        val modifiedUser = originalUser.addProperty("name", "Modified")
        
        // Original should be unchanged
        assertEquals("Original", originalUser.properties["name"])
        // Modified should have new value
        assertEquals("Modified", modifiedUser.properties["name"])
        
        // Should be different instances
        assertNotSame(originalUser, modifiedUser)
    }
} 