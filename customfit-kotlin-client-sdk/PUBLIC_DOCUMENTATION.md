# CustomFit Kotlin SDK Documentation

[![Version](https://img.shields.io/badge/version-1.1.1-blue.svg)](https://github.com/customfit/kotlin-sdk)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Java](https://img.shields.io/badge/java-11+-orange.svg)](https://www.oracle.com/java/)
[![Kotlin](https://img.shields.io/badge/kotlin-1.9.22-purple.svg)](https://kotlinlang.org/)

CustomFit Kotlin SDK enables seamless integration of real-time feature flags, user analytics, and personalization capabilities into your Kotlin/JVM applications. Built with performance, reliability, and developer experience in mind.

## Table of Contents

- [Key Concepts](#key-concepts)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [User Management](#user-management)
- [Feature Flags](#feature-flags)
- [Event Tracking](#event-tracking)
- [Session Management](#session-management)
- [Listeners & Callbacks](#listeners--callbacks)
- [Offline Support](#offline-support)
- [Advanced Features](#advanced-features)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)

## Key Concepts

### Feature Flags
Feature flags (also known as feature toggles) allow you to dynamically control feature availability without deploying new code. The SDK supports multiple data types:
- **Boolean flags**: Simple on/off toggles
- **String flags**: Text values, configuration strings
- **Number flags**: Numeric values, thresholds, percentages
- **JSON flags**: Complex objects, configuration maps

### Real-time Updates
The SDK maintains persistent connections to receive instant flag updates, ensuring your application responds immediately to configuration changes without requiring restarts.

### User Context & Personalization
Associate users with properties and contexts to enable personalized experiences. The SDK supports:
- User properties (demographics, preferences, etc.)
- Evaluation contexts (location, device, session data)
- Anonymous and identified users

### Analytics & Events
Track user interactions and feature usage to gain insights into user behavior and feature performance. All events are efficiently batched and sent to the analytics platform.

### Session Management
Automatic session lifecycle management with configurable rotation policies based on time, user authentication changes, and app state transitions.

## Installation

### Prerequisites
- Java 11 or higher
- Kotlin 1.9.22 or higher

### Gradle (Kotlin DSL)
```kotlin
dependencies {
    implementation("ai.customfit:kotlin-sdk:1.1.1")
}
```

### Gradle (Groovy)
```groovy
dependencies {
    implementation 'ai.customfit:kotlin-sdk:1.1.1'
}
```

### Maven
```xml
<dependency>
    <groupId>ai.customfit</groupId>
    <artifactId>kotlin-sdk</artifactId>
    <version>1.1.1</version>
</dependency>
```

## Quick Start

### 1. Initialize the SDK

```kotlin
import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.model.CFUser
import kotlinx.coroutines.runBlocking

// Create configuration
val config = CFConfig.Builder("your-client-key-here")
    .debugLoggingEnabled(true)
    .eventsFlushIntervalMs(5000)
    .build()

// Create user
val user = CFUser.builder("user123")
    .withStringProperty("plan", "premium")
    .withNumberProperty("age", 25)
    .build()

// Initialize client (async)
runBlocking {
    val client = CFClient.initialize(config, user)
    
    // Wait for SDK initialization to complete
    client.awaitInitialization()
    
    println("CustomFit SDK initialized successfully!")
}
```

### 2. Use Feature Flags

```kotlin
// Get a boolean feature flag
val newUIEnabled = client.getBoolean("new_ui_enabled", false)

// Get a string configuration
val welcomeMessage = client.getString("welcome_message", "Welcome!")

// Get a number value
val maxRetries = client.getNumber("max_retries", 3)

// Get JSON configuration
val themeConfig = client.getJson("theme_config", mapOf("color" to "blue"))
```

### 3. Track Events

```kotlin
// Track a simple event
client.trackEvent("button_clicked", mapOf("button_id" to "login"))

// Track with properties builder
client.trackEvent("page_viewed") {
    stringProperty("page_name", "dashboard")
    numberProperty("load_time", 1.2)
    booleanProperty("first_visit", true)
}
```

## Configuration

The `CFConfig` class provides extensive customization options using the builder pattern:

```kotlin
val config = CFConfig.Builder("your-client-key")
    // Logging
    .debugLoggingEnabled(true)
    .logLevel("DEBUG")
    
    // Event tracking
    .eventsQueueSize(100)
    .eventsFlushTimeSeconds(30)
    .eventsFlushIntervalMs(5000)
    
    // Network settings
    .networkConnectionTimeoutMs(10000)
    .networkReadTimeoutMs(15000)
    
    // Background behavior
    .backgroundPollingIntervalMs(60000)
    .useReducedPollingWhenBatteryLow(true)
    .reducedPollingIntervalMs(300000)
    
    // Retry configuration
    .maxRetryAttempts(3)
    .retryInitialDelayMs(1000)
    .retryMaxDelayMs(30000)
    .retryBackoffMultiplier(2.0)
    
    // Offline support
    .offlineMode(false)
    .maxStoredEvents(1000)
    
    // Auto environment detection
    .autoEnvAttributesEnabled(true)
    
    .build()
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `debugLoggingEnabled` | Enable detailed debug logging | `false` |
| `eventsQueueSize` | Maximum events in memory queue | `100` |
| `eventsFlushIntervalMs` | Automatic event flush interval | `30000` |
| `networkConnectionTimeoutMs` | Network connection timeout | `10000` |
| `backgroundPollingIntervalMs` | Config polling when app in background | `300000` |
| `useReducedPollingWhenBatteryLow` | Reduce polling on low battery | `true` |
| `maxRetryAttempts` | Maximum retry attempts for failed requests | `3` |
| `offlineMode` | Start in offline mode | `false` |
| `autoEnvAttributesEnabled` | Auto-detect device/app context | `false` |

## User Management

### Creating Users

```kotlin
// Identified user with properties
val user = CFUser.builder("user123")
    .withStringProperty("email", "user@example.com")
    .withStringProperty("plan", "premium")
    .withNumberProperty("age", 28)
    .withBooleanProperty("beta_tester", true)
    .withDateProperty("signup_date", Date())
    .withGeoPointProperty("location", 37.7749, -122.4194) // lat, lon
    .withJsonProperty("preferences", mapOf(
        "theme" to "dark",
        "notifications" to true
    ))
    .build()

// Anonymous user
val anonymousUser = CFUser.builder("anonymous_123")
    .makeAnonymous(true)
    .withStringProperty("source", "mobile_app")
    .build()
```

### Updating User Properties

```kotlin
// Add single property
client.addStringProperty("subscription_tier", "pro")
client.addNumberProperty("login_count", 15)
client.addBooleanProperty("verified_email", true)

// Add multiple properties
client.addUserProperties(mapOf(
    "last_activity" to Date(),
    "device_type" to "mobile",
    "app_version" to "2.1.0"
))
```

### User Contexts

```kotlin
import customfit.ai.kotlinclient.core.model.EvaluationContext
import customfit.ai.kotlinclient.core.model.ContextType

// Add evaluation contexts for targeting
val locationContext = EvaluationContext(
    type = ContextType.LOCATION,
    key = "current_location",
    attributes = mapOf(
        "country" to "US",
        "state" to "CA",
        "city" to "San Francisco"
    )
)

val deviceContext = EvaluationContext(
    type = ContextType.DEVICE,
    key = "device_info",
    attributes = mapOf(
        "platform" to "Android",
        "version" to "13",
        "model" to "Pixel 7"
    )
)

client.addContext(locationContext)
client.addContext(deviceContext)
```

## Feature Flags

### Basic Flag Retrieval

```kotlin
// Boolean flags
val isNewFeatureEnabled = client.getBoolean("new_feature", false)
val showBetaFeatures = client.getBoolean("beta_features", false)

// String flags
val apiEndpoint = client.getString("api_endpoint", "https://api.example.com")
val welcomeMessage = client.getString("welcome_text", "Welcome!")

// Number flags
val maxFileSize = client.getNumber("max_file_size_mb", 10)
val retryAttempts = client.getNumber("retry_attempts", 3)

// JSON flags
val featureConfig = client.getJson("feature_config", mapOf(
    "enabled" to true,
    "max_users" to 100
))
```

### Callbacks

```kotlin
// Get value with callback
val theme = client.getString("app_theme", "light") { value ->
    println("Current theme: $value")
    applyTheme(value)
}

val maxRetries = client.getNumber("max_retries", 3) { value ->
    updateRetryPolicy(value.toInt())
}
```

### Generic Feature Flag Access

```kotlin
// Type-safe generic access
val feature: Boolean = client.getFeatureFlag("my_feature", false)
val config: Map<String, Any> = client.getFeatureFlag("config", emptyMap())
```

### Get All Flags

```kotlin
val allFlags = client.getAllFlags()
println("Current flags: $allFlags")
```

## Event Tracking

### Simple Event Tracking

```kotlin
// Basic event
client.trackEvent("user_login")

// Event with properties
client.trackEvent("purchase_completed", mapOf(
    "product_id" to "prod_123",
    "amount" to 99.99,
    "currency" to "USD",
    "payment_method" to "credit_card"
))
```

### Using Properties Builder

```kotlin
import customfit.ai.kotlinclient.analytics.event.EventPropertiesBuilder

client.trackEvent("video_watched") {
    stringProperty("video_id", "vid_456")
    numberProperty("duration_seconds", 120.5)
    booleanProperty("completed", true)
    jsonProperty("metadata", mapOf(
        "quality" to "HD",
        "subtitles" to true
    ))
}
```

### Event Result Handling

```kotlin
import customfit.ai.kotlinclient.core.error.CFResult

val result = client.trackEvent("user_action", mapOf("action" to "click"))

result.onSuccess { eventData ->
    println("Event tracked successfully: ${eventData.eventId}")
}.onError { error ->
    println("Failed to track event: ${error.error}")
}
```

## Session Management

The SDK automatically manages user sessions with configurable rotation policies.

### Getting Session Information

```kotlin
runBlocking {
    // Get current session ID
    val sessionId = client.getCurrentSessionId()
    
    // Get detailed session data
    val sessionData = client.getCurrentSessionData()
    sessionData?.let {
        println("Session: ${it.sessionId}")
        println("Started: ${it.startTime}")
        println("Last activity: ${it.lastActivityTime}")
    }
    
    // Get session statistics
    val stats = client.getSessionStatistics()
    println("Session stats: $stats")
}
```

### Manual Session Control

```kotlin
runBlocking {
    // Force session rotation
    val newSessionId = client.forceSessionRotation()
    println("New session: $newSessionId")
    
    // Update activity (call on user interactions)
    client.updateSessionActivity()
    
    // Handle authentication changes
    client.onUserAuthenticationChange("new_user_id")
}
```

### Session Listeners

```kotlin
import customfit.ai.kotlinclient.core.session.SessionRotationListener
import customfit.ai.kotlinclient.core.session.RotationReason

val sessionListener = object : SessionRotationListener {
    override fun onSessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
        println("Session rotated: $oldSessionId -> $newSessionId (${reason.description})")
        // Update analytics, clear caches, etc.
    }
    
    override fun onSessionRestored(sessionId: String) {
        println("Session restored: $sessionId")
    }
    
    override fun onSessionError(error: String) {
        println("Session error: $error")
    }
}

client.addSessionRotationListener(sessionListener)
```

## Listeners & Callbacks

### Feature Flag Change Listeners

```kotlin
import customfit.ai.kotlinclient.client.listener.FeatureFlagChangeListener

// Listen to specific flag changes
val flagListener = FeatureFlagChangeListener { oldValue, newValue ->
    println("Feature flag changed: $oldValue -> $newValue")
    handleFeatureChange(newValue)
}

client.addFeatureFlagListener("my_feature", flagListener)

// Type-safe listeners with lambdas
client.addConfigListener<Boolean>("dark_mode") { isEnabled ->
    updateUITheme(isEnabled)
}

client.addConfigListener<String>("api_url") { url ->
    updateApiEndpoint(url)
}
```

### All Flags Listener

```kotlin
import customfit.ai.kotlinclient.client.listener.AllFlagsListener

val allFlagsListener = AllFlagsListener { flags ->
    println("Flags updated: ${flags.size} flags")
    flags.forEach { (key, value) ->
        println("  $key = $value")
    }
}

client.addAllFlagsListener(allFlagsListener)
```

### Connection Status Listeners

```kotlin
import customfit.ai.kotlinclient.network.connection.ConnectionStatusListener
import customfit.ai.kotlinclient.network.connection.ConnectionStatus

val connectionListener = ConnectionStatusListener { status ->
    when (status) {
        ConnectionStatus.CONNECTED -> println("Connected to CustomFit")
        ConnectionStatus.DISCONNECTED -> println("Disconnected from CustomFit")
        ConnectionStatus.CONNECTING -> println("Connecting...")
        ConnectionStatus.ERROR -> println("Connection error")
    }
}

client.addConnectionStatusListener(connectionListener)

// Get current connection info
val connectionInfo = client.getConnectionInformation()
println("Connection: ${connectionInfo.status}, Type: ${connectionInfo.networkType}")
```

## Offline Support

The SDK provides robust offline capabilities with automatic synchronization when connectivity is restored.

### Offline Mode Control

```kotlin
// Check if offline
val isOffline = client.isOffline()

// Enable offline mode
client.setOffline()

// Restore online mode
client.setOnline()
```

### Offline Configuration

```kotlin
val config = CFConfig.Builder("your-client-key")
    .offlineMode(true)  // Start in offline mode
    .maxStoredEvents(1000)  // Max events to store offline
    .build()
```

### Offline Behavior

- **Feature flags**: Return cached values or defaults
- **Events**: Queued locally and sent when online
- **Configuration updates**: Resume when connectivity restored
- **Automatic synchronization**: Seamless transition between offline/online

## Advanced Features

### Force Configuration Refresh

```kotlin
runBlocking {
    // Force refresh from server (ignores cache)
    client.forceRefresh()
}
```

### Runtime Configuration Updates

```kotlin
// Update polling intervals
client.updateSdkSettingsCheckInterval(60000) // 1 minute

// Update event flush intervals
client.updateEventsFlushInterval(10000) // 10 seconds

// Update network timeouts
client.updateNetworkConnectionTimeout(15000)
client.updateNetworkReadTimeout(20000)

// Toggle logging
client.setDebugLoggingEnabled(true)
client.setLoggingEnabled(false)
```

### Background State Optimization

The SDK automatically optimizes behavior based on app state:

- **Foreground**: Normal polling and event tracking
- **Background**: Reduced polling frequency
- **Low battery**: Further reduced activity
- **No connectivity**: Offline mode with local queuing

## Error Handling

The SDK uses `CFResult<T>` for standardized error handling:

```kotlin
import customfit.ai.kotlinclient.core.error.CFResult

// Pattern 1: Direct checking
val result = client.trackEvent("user_action")
when (result) {
    is CFResult.Success -> {
        println("Success: ${result.data}")
    }
    is CFResult.Error -> {
        println("Error: ${result.error}")
        result.exception?.printStackTrace()
    }
}

// Pattern 2: Functional style
result
    .onSuccess { data -> 
        println("Event tracked: ${data.eventId}")
    }
    .onError { error ->
        println("Failed: ${error.error}")
        handleError(error)
    }

// Pattern 3: Extract values
val eventData = result.getOrNull()
val eventOrDefault = result.getOrDefault(defaultEventData)
val eventOrElse = result.getOrElse { error -> 
    logError(error)
    createFallbackEvent()
}

// Pattern 4: Transform results
val eventId = result.map { it.eventId }
```

### Error Categories

```kotlin
import customfit.ai.kotlinclient.core.error.ErrorHandler

// Error categories for different handling strategies
when (error.category) {
    ErrorHandler.ErrorCategory.NETWORK -> {
        // Network issues - retry logic
        scheduleRetry()
    }
    ErrorHandler.ErrorCategory.VALIDATION -> {
        // Invalid input - fix and retry
        fixInputAndRetry()
    }
    ErrorHandler.ErrorCategory.AUTHENTICATION -> {
        // Auth issues - refresh token
        refreshAuthToken()
    }
    ErrorHandler.ErrorCategory.INTERNAL -> {
        // SDK issues - report bug
        reportIssue(error)
    }
}
```

## Best Practices

### 1. Initialization

```kotlin
// ✅ Good: Initialize once, use globally
class App {
    companion object {
        lateinit var cfClient: CFClient
            private set
    }
    
    fun onCreate() {
        runBlocking {
            cfClient = CFClient.initialize(config, user)
            cfClient.awaitInitialization()
        }
    }
}

// ✅ Access globally
val isFeatureEnabled = App.cfClient.getBoolean("feature", false)
```

### 2. User Updates

```kotlin
// ✅ Good: Batch property updates
client.addUserProperties(mapOf(
    "last_login" to Date(),
    "session_count" to sessionCount,
    "premium_user" to isPremium
))

// ❌ Avoid: Multiple individual calls
client.addStringProperty("last_login", loginTime)
client.addNumberProperty("session_count", sessionCount)
client.addBooleanProperty("premium_user", isPremium)
```

### 3. Event Tracking

```kotlin
// ✅ Good: Use meaningful event names and properties
client.trackEvent("purchase_completed") {
    stringProperty("product_category", "electronics")
    numberProperty("revenue", 99.99)
    stringProperty("payment_method", "credit_card")
    booleanProperty("first_purchase", true)
}

// ❌ Avoid: Generic events without context
client.trackEvent("click", mapOf("type" to "button"))
```

### 4. Resource Management

```kotlin
// ✅ Good: Cleanup on app shutdown
override fun onDestroy() {
    runBlocking {
        CFClient.shutdown()
    }
    super.onDestroy()
}
```

### 5. Error Handling

```kotlin
// ✅ Good: Handle both success and error cases
client.trackEvent("user_action").fold(
    onSuccess = { data -> updateUI(data) },
    onError = { error -> 
        logError(error)
        showFallbackUI()
    }
)
```

## API Reference

### CFClient

#### Initialization
- `suspend fun initialize(config: CFConfig, user: CFUser): CFClient`
- `suspend fun awaitInitialization()`
- `fun shutdown()`

#### Feature Flags
- `fun <T> getFeatureFlag(key: String, defaultValue: T): T`
- `fun getString(key: String, fallbackValue: String): String`
- `fun getNumber(key: String, fallbackValue: Number): Number`
- `fun getBoolean(key: String, fallbackValue: Boolean): Boolean`
- `fun getJson(key: String, fallbackValue: Map<String, Any>): Map<String, Any>`
- `fun getAllFlags(): Map<String, Any>`

#### Event Tracking
- `fun trackEvent(eventName: String, properties: Map<String, Any> = emptyMap()): CFResult<EventData>`
- `fun trackEvent(eventName: String, propertiesBuilder: EventPropertiesBuilder.() -> Unit): CFResult<EventData>`

#### User Management
- `fun addUserProperty(key: String, value: Any)`
- `fun addStringProperty(key: String, value: String)`
- `fun addNumberProperty(key: String, value: Number)`
- `fun addBooleanProperty(key: String, value: Boolean)`
- `fun addUserProperties(properties: Map<String, Any>)`

#### Session Management
- `suspend fun getCurrentSessionId(): String`
- `suspend fun getCurrentSessionData(): SessionData?`
- `suspend fun forceSessionRotation(): String?`
- `suspend fun updateSessionActivity()`

#### Listeners
- `fun <T : Any> addConfigListener(key: String, listener: (T) -> Unit)`
- `fun addFeatureFlagListener(flagKey: String, listener: FeatureFlagChangeListener)`
- `fun addAllFlagsListener(listener: AllFlagsListener)`
- `fun addConnectionStatusListener(listener: ConnectionStatusListener)`

#### Offline Support
- `fun isOffline(): Boolean`
- `fun setOffline()`
- `fun setOnline()`

### CFConfig.Builder

Configuration builder methods for customizing SDK behavior.

### CFUser.Builder

User builder methods for setting user properties and contexts.

## Troubleshooting

### Common Issues

#### 1. Initialization Failures

```kotlin
// Problem: Client not initializing
// Solution: Check client key format and network connectivity
try {
    val client = CFClient.initialize(config, user)
    client.awaitInitialization()
} catch (e: Exception) {
    println("Init failed: ${e.message}")
    // Check client key, network, etc.
}
```

#### 2. Feature Flags Not Updating

```kotlin
// Problem: Flags returning default values
// Solution: Verify initialization and check logs
runBlocking {
    client.forceRefresh() // Force update from server
}

// Check if offline
if (client.isOffline()) {
    client.setOnline()
}
```

#### 3. Events Not Being Sent

```kotlin
// Problem: Events stuck in queue
// Solution: Check network and flush manually
val result = client.trackEvent("test_event")
result.onError { error ->
    println("Event error: ${error.error}")
    // Check network connectivity
    if (!client.isOffline()) {
        // Try manual flush (if exposed in future versions)
    }
}
```

### Debug Logging

Enable debug logging to troubleshoot issues:

```kotlin
val config = CFConfig.Builder("your-client-key")
    .debugLoggingEnabled(true)
    .logLevel("DEBUG")
    .build()
```

### Performance Monitoring

```kotlin
// Monitor session statistics
runBlocking {
    val stats = client.getSessionStatistics()
    println("Session stats: $stats")
}

// Monitor connection status
val connectionInfo = client.getConnectionInformation()
println("Connection: ${connectionInfo.status}")
```

---

## Support

For technical support, documentation updates, or feature requests:

- **Documentation**: [https://docs.customfit.ai](https://docs.customfit.ai)
- **GitHub Issues**: [https://github.com/customfit/kotlin-sdk/issues](https://github.com/customfit/kotlin-sdk/issues)
- **Support Email**: support@customfit.ai

## License

This SDK is released under the MIT License. See [LICENSE](LICENSE) file for details.

---

*This documentation is for CustomFit Kotlin SDK v1.1.1. For the latest updates, visit our [documentation site](https://docs.customfit.ai).* 