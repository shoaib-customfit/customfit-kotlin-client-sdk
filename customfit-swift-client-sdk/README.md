# CustomFit Swift SDK

The CustomFit Swift SDK enables you to integrate feature flags, configuration management, and analytics into your iOS, macOS, tvOS, and watchOS applications.

[![Swift 5.0+](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![iOS 13.0+](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://developer.apple.com/ios/)
[![macOS 10.15+](https://img.shields.io/badge/macOS-10.15+-blue.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Feature Flags](#feature-flags)
  - [Configuration Values](#configuration-values)
  - [Event Tracking](#event-tracking)
  - [Config Listeners](#config-listeners)
- [API Reference](#api-reference)
- [Advanced Usage](#advanced-usage)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)

## Features

- ✅ **Feature Flags**: Real-time feature toggles and A/B testing
- ✅ **Configuration Management**: Dynamic app configuration without app store updates
- ✅ **Event Tracking**: Comprehensive analytics and user behavior tracking
- ✅ **Config Listeners**: Real-time configuration change notifications
- ✅ **Offline Support**: Cached configurations for offline functionality
- ✅ **Background Polling**: Automatic configuration updates
- ✅ **Session Management**: Automatic session lifecycle tracking
- ✅ **Battery Optimization**: Adaptive polling based on device state
- ✅ **Thread Safety**: Safe for use across multiple threads
- ✅ **Comprehensive Logging**: Debug-friendly logging system

## Installation

### Swift Package Manager (Recommended)

Add the CustomFit Swift SDK to your project using Swift Package Manager:

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the repository URL: `https://github.com/customfit/customfit-swift-sdk`
3. Select the version or branch you want to use
4. Click **Add Package**

### Manual Installation

1. Download the latest release from [GitHub Releases](https://github.com/customfit/customfit-swift-sdk/releases)
2. Drag `CustomFitSwiftSDK.framework` into your Xcode project
3. Ensure the framework is added to your target's **Frameworks, Libraries, and Embedded Content**

## Quick Start

### 1. Import the SDK

```swift
import CustomFitSwiftSDK
```

### 2. Initialize the SDK

```swift
import SwiftUI
import CustomFitSwiftSDK

@main
struct MyApp: App {
    init() {
        initializeCustomFit()
    }
    
    private func initializeCustomFit() {
        // Your CustomFit client key
        let clientKey = "your_client_key_here"
        
        // Create configuration
        let config = CFConfig.builder(clientKey)
            .debugLoggingEnabled(true)
            .build()
        
        // Create user
        let user = CFUser(user_customer_id: "user_123")
            .addProperty(key: "platform", value: "ios")
        
        // Initialize SDK
        let client = CFClient.initialize(config: config, user: user)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 3. Use Feature Flags

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            if CFClient.getInstance()?.getBooleanFeatureFlag(key: "new_ui_enabled", defaultValue: false) == true {
                NewUIView()
            } else {
                LegacyUIView()
            }
        }
    }
}
```

## Configuration

### CFConfig Builder

The `CFConfig.builder()` provides a fluent API for configuring the SDK:

```swift
let config = CFConfig.builder(clientKey)
    // Polling intervals
    .sdkSettingsCheckIntervalMs(30000)        // Check for config changes every 30s
    .backgroundPollingIntervalMs(60000)       // Background polling interval
    .reducedPollingIntervalMs(120000)         // Low battery polling interval
    
    // Events configuration
    .eventsFlushTimeSeconds(30)               // Flush events every 30s
    .eventsFlushIntervalMs(30000)             // Event flush interval
    .maxStoredEvents(1000)                    // Maximum stored events
    
    // Summaries configuration
    .summariesFlushTimeSeconds(10)            // Flush summaries every 10s
    .summariesFlushIntervalMs(10000)          // Summary flush interval
    .summariesQueueSize(100)                  // Summary queue size
    
    // Network configuration
    .networkConnectionTimeoutMs(30000)        // Connection timeout
    .networkReadTimeoutMs(30000)              // Read timeout
    .maxRetryAttempts(3)                      // Retry attempts
    
    // Performance optimization
    .useReducedPollingWhenBatteryLow(true)    // Reduce polling on low battery
    .disableBackgroundPolling(false)          // Enable background polling
    
    // Logging
    .loggingEnabled(true)                     // Enable logging
    .debugLoggingEnabled(true)                // Enable debug logs
    .logLevel("DEBUG")                        // Log level
    
    // Offline mode
    .offlineMode(false)                       // Enable offline mode
    .autoEnvAttributesEnabled(true)           // Auto collect environment attributes
    .build()
```

### Configuration Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clientKey` | String | Required | Your CustomFit client key |
| `sdkSettingsCheckIntervalMs` | Int64 | 30000 | Interval for checking configuration changes |
| `backgroundPollingIntervalMs` | Int64 | 60000 | Polling interval when app is in background |
| `reducedPollingIntervalMs` | Int64 | 120000 | Polling interval when device battery is low |
| `eventsFlushTimeSeconds` | Int | 30 | How often to flush events to server |
| `eventsFlushIntervalMs` | Int64 | 30000 | Event flush interval in milliseconds |
| `maxStoredEvents` | Int | 1000 | Maximum number of events to store locally |
| `summariesFlushTimeSeconds` | Int | 10 | How often to flush summaries |
| `summariesFlushIntervalMs` | Int64 | 10000 | Summary flush interval in milliseconds |
| `networkConnectionTimeoutMs` | Int | 30000 | Network connection timeout |
| `networkReadTimeoutMs` | Int | 30000 | Network read timeout |
| `maxRetryAttempts` | Int | 3 | Maximum retry attempts for failed requests |
| `loggingEnabled` | Bool | true | Enable/disable logging |
| `debugLoggingEnabled` | Bool | false | Enable/disable debug logging |
| `offlineMode` | Bool | false | Run SDK in offline mode |

## Usage

### Feature Flags

#### Boolean Flags

```swift
let client = CFClient.getInstance()
let isNewFeatureEnabled = client?.getBooleanFeatureFlag(
    key: "new_feature_enabled", 
    defaultValue: false
) ?? false

if isNewFeatureEnabled {
    // Show new feature
}
```

#### Generic Feature Values

```swift
// String values
let welcomeMessage = client?.getFeatureFlag(
    key: "welcome_message", 
    defaultValue: "Welcome!"
) ?? "Welcome!"

// Integer values
let maxRetries = client?.getFeatureFlag(
    key: "max_retries", 
    defaultValue: 3
) ?? 3

// Double values
let discountRate = client?.getFeatureFlag(
    key: "discount_rate", 
    defaultValue: 0.1
) ?? 0.1
```

#### Get All Flags

```swift
let allFlags = client?.getAllFlags() ?? [:]
print("Current flags: \(allFlags)")
```

### Configuration Values

#### String Configuration

```swift
let apiUrl = client?.getStringFlag(
    key: "api_url", 
    defaultValue: "https://api.example.com"
) ?? "https://api.example.com"
```

#### JSON Configuration

```swift
let themeConfig = client?.getJSONFlag(
    key: "theme_config", 
    defaultValue: [:]
) ?? [:]
```

### Event Tracking

#### Simple Events

```swift
client?.trackEvent(name: "button_clicked")
```

#### Events with Properties

```swift
client?.trackEvent(
    name: "purchase_completed",
    properties: [
        "product_id": "123",
        "price": 29.99,
        "currency": "USD",
        "category": "premium"
    ]
)
```

#### User Journey Events

```swift
// Screen navigation
client?.trackEvent(
    name: "screen_viewed",
    properties: [
        "screen_name": "product_detail",
        "product_id": "123",
        "source": "search_results"
    ]
)

// User interactions
client?.trackEvent(
    name: "cta_clicked",
    properties: [
        "cta_text": "Buy Now",
        "placement": "product_detail",
        "user_segment": "premium"
    ]
)
```

### Config Listeners

#### Add Config Listeners

```swift
// Listen for specific config changes
client?.addConfigListener(key: "theme_mode") { (newValue: String) in
    DispatchQueue.main.async {
        self.updateTheme(newValue)
    }
}

// Listen for feature flag changes
client?.addFeatureFlagListener(key: "dark_mode_enabled") { isEnabled in
    DispatchQueue.main.async {
        self.toggleDarkMode(isEnabled)
    }
}

// Listen for all flag changes
client?.addAllFlagsListener { changedFlags in
    print("Flags changed: \(changedFlags)")
}
```

#### Remove Listeners

```swift
client?.removeFeatureFlagListener(key: "dark_mode_enabled")
client?.removeAllFlagsListener()
```

### User Management

#### Update User Properties

```swift
// Set user ID
client?.setUserId(userId: "user_123")

// Add user properties
client?.addUserProperty(key: "subscription_tier", value: "premium")
client?.addUserProperty(key: "onboarding_completed", value: true)

// Add multiple properties
client?.addUserProperties(properties: [
    "age_group": "25-34",
    "location": "US",
    "signup_date": Date()
])
```

#### User Context

```swift
// Add evaluation context
let context = EvaluationContext(key: "device_context")
    .addAttribute(key: "device_type", value: "iPhone")
    .addAttribute(key: "os_version", value: "17.0")

client?.addContext(context)
```

### Session Management

#### Session Information

```swift
// Get current session ID
let sessionId = client?.getCurrentSessionId()

// Get session data
let sessionData = client?.getCurrentSessionData()

// Force session rotation
let newSessionId = client?.forceSessionRotation()

// Update session activity
client?.updateSessionActivity()
```

#### Session Listeners

```swift
client?.addSessionRotationListener(MySessionListener())

class MySessionListener: SessionRotationListener {
    func onSessionRotated(oldSessionId: String?, newSessionId: String, reason: RotationReason) {
        print("Session rotated: \(oldSessionId) -> \(newSessionId)")
    }
    
    func onSessionRestored(sessionId: String) {
        print("Session restored: \(sessionId)")
    }
    
    func onSessionError(error: String) {
        print("Session error: \(error)")
    }
}
```

## API Reference

### CFClient

The main client class for interacting with CustomFit.

#### Initialization

```swift
// Initialize singleton
static func initialize(config: CFConfig, user: CFUser) -> CFClient

// Get singleton instance
static func getInstance() -> CFClient?

// Check if initialized
static func isInitialized() -> Bool
```

#### Feature Flags

```swift
// Boolean flags
func getBooleanFeatureFlag(key: String, defaultValue: Bool) -> Bool

// Generic feature values
func getFeatureFlag<T>(key: String, defaultValue: T) -> T

// All flags
func getAllFlags() -> [String: Any]

// Refresh features
func refreshFeatures(completion: ((CFResult<Bool>) -> Void)?)
```

#### Configuration

```swift
// String configuration
func getStringFlag(key: String, defaultValue: String) -> String

// Integer configuration
func getIntFlag(key: String, defaultValue: Int) -> Int

// Double configuration
func getDoubleFlag(key: String, defaultValue: Double) -> Double

// JSON configuration
func getJSONFlag(key: String, defaultValue: [String: Any]) -> [String: Any]
```

#### Event Tracking

```swift
// Track events
func trackEvent(name: String, properties: [String: Any]?)

// Track config requests
func trackConfigRequest(config: [String: Any], customerUserId: String, sessionId: String) -> CFResult<Bool>
```

#### Listeners

```swift
// Config listeners
func addConfigListener<T>(key: String, listener: @escaping (T) -> Void)
func removeConfigListener<T>(key: String, listener: @escaping (T) -> Void)
func clearConfigListeners(key: String)

// Feature flag listeners
func addFeatureFlagListener(key: String, listener: @escaping (Bool) -> Void)
func addFeatureValueListener<T>(key: String, listener: @escaping (T) -> Void)
func removeFeatureFlagListener(key: String)

// All flags listeners
func addAllFlagsListener(listener: @escaping ([String: Any]) -> Void)
func removeAllFlagsListener()

// Connection status listeners
func addConnectionStatusListener(listener: @escaping (ConnectionStatus, ConnectionInformation) -> Void)
```

#### User Management

```swift
// User ID
func setUserId(userId: String)

// User properties
func addUserProperty(key: String, value: Any)
func addUserProperties(properties: [String: Any])
func getUserProperties() -> [String: Any]

// Specialized properties
func addStringProperty(key: String, value: String)
func addNumberProperty(key: String, value: NSNumber)
func addBooleanProperty(key: String, value: Bool)
func addDateProperty(key: String, value: Date)
func addGeoPointProperty(key: String, lat: Double, lon: Double)
func addJsonProperty(key: String, value: [String: Any])
```

#### Session Management

```swift
// Session information
func getCurrentSessionId() -> String
func getCurrentSessionData() -> SessionData?
func forceSessionRotation() -> String?
func updateSessionActivity()
func onUserAuthenticationChange(userId: String?)

// Session statistics
func getSessionStatistics() -> [String: Any]

// Session listeners
func addSessionRotationListener(_ listener: SessionRotationListener)
func removeSessionRotationListener(_ listener: SessionRotationListener)
```

#### Lifecycle

```swift
// Shutdown
func shutdown()

// Logging
func setLogLevel(level: Logger.LogLevel)
func getLogLevel() -> Logger.LogLevel
```

### CFConfig

Configuration builder for the SDK.

```swift
// Create builder
static func builder(_ clientKey: String) -> CFConfigBuilder

// Build configuration
func build() -> CFConfig
```

### CFUser

User configuration for the SDK.

```swift
// Initialize
init(user_customer_id: String)

// User properties
func addProperty(key: String, value: Any) -> CFUser
func withAttribute(key: String, value: Any) -> CFUser
func withProperties(_ properties: [String: Any]) -> CFUser

// User identifiers
func withUserId(_ userId: String) -> CFUser
func withDeviceId(_ deviceId: String) -> CFUser
func withAnonymousId(_ anonymousId: String) -> CFUser

// User state
func makeAnonymous(_ anonymous: Bool) -> CFUser

// Context
func addContext(_ context: EvaluationContext) -> CFUser
func withContext(_ context: EvaluationContext) -> CFUser
```

## Advanced Usage

### Custom HTTP Client

```swift
// Implement custom HTTP client
class MyHTTPClient: HttpClientInterface {
    func performRequest(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> HttpResponse {
        // Custom implementation
    }
}

// Use with SDK
let config = CFConfig.builder(clientKey)
    .customHttpClient(MyHTTPClient())
    .build()
```

### Offline Mode

```swift
// Enable offline mode
let config = CFConfig.builder(clientKey)
    .offlineMode(true)
    .build()

// Check offline status
let isOffline = client?.getConfig().offlineMode
```

### Background Processing

```swift
// Handle app state changes
func applicationDidEnterBackground() {
    // SDK automatically handles background state
    // Polling intervals will be adjusted automatically
}

func applicationWillEnterForeground() {
    // SDK will resume normal polling
    // Immediate config check will be performed
}
```

### Performance Optimization

```swift
// Optimize for battery life
let config = CFConfig.builder(clientKey)
    .useReducedPollingWhenBatteryLow(true)
    .reducedPollingIntervalMs(300000) // 5 minutes
    .build()

// Disable background polling for performance
let config = CFConfig.builder(clientKey)
    .disableBackgroundPolling(true)
    .build()
```

## Best Practices

### 1. Initialization

- Initialize the SDK as early as possible in your app lifecycle
- Use the singleton pattern with `CFClient.initialize()`
- Handle initialization errors gracefully

```swift
@main
struct MyApp: App {
    @State private var isSDKInitialized = false
    
    init() {
        initializeSDK()
    }
    
    private func initializeSDK() {
        do {
            let config = CFConfig.builder("your_client_key")
                .debugLoggingEnabled(BuildConfig.DEBUG)
                .build()
            
            let user = CFUser(user_customer_id: UserManager.getCurrentUserId())
            
            CFClient.initialize(config: config, user: user)
            isSDKInitialized = true
        } catch {
            print("Failed to initialize CustomFit SDK: \(error)")
            // Handle gracefully, maybe use local defaults
        }
    }
}
```

### 2. Feature Flag Usage

- Always provide meaningful default values
- Use feature flags for gradual rollouts
- Keep flag names descriptive and consistent

```swift
struct FeatureFlags {
    static func isNewCheckoutEnabled() -> Bool {
        return CFClient.getInstance()?.getBooleanFeatureFlag(
            key: "new_checkout_flow_enabled",
            defaultValue: false
        ) ?? false
    }
    
    static func getMaxRetries() -> Int {
        return CFClient.getInstance()?.getFeatureFlag(
            key: "network_max_retries",
            defaultValue: 3
        ) ?? 3
    }
}
```

### 3. Event Tracking

- Use consistent event naming conventions
- Include relevant context in event properties
- Avoid tracking PII (personally identifiable information)

```swift
class AnalyticsHelper {
    static func trackUserAction(_ action: String, properties: [String: Any] = [:]) {
        var enrichedProperties = properties
        enrichedProperties["app_version"] = Bundle.main.appVersion
        enrichedProperties["platform"] = "ios"
        enrichedProperties["timestamp"] = Date().timeIntervalSince1970
        
        CFClient.getInstance()?.trackEvent(
            name: action,
            properties: enrichedProperties
        )
    }
}
```

### 4. Config Listeners

- Use config listeners for real-time UI updates
- Update UI on the main thread
- Remove listeners when no longer needed

```swift
class ThemeManager: ObservableObject {
    @Published var isDarkMode = false
    
    init() {
        setupConfigListener()
    }
    
    private func setupConfigListener() {
        CFClient.getInstance()?.addConfigListener(key: "dark_mode_enabled") { [weak self] (isEnabled: Bool) in
            DispatchQueue.main.async {
                self?.isDarkMode = isEnabled
            }
        }
    }
    
    deinit {
        CFClient.getInstance()?.clearConfigListeners(key: "dark_mode_enabled")
    }
}
```

### 5. Error Handling

- Always check if the SDK is initialized
- Handle network failures gracefully
- Provide fallback behavior

```swift
extension CFClient {
    static func safeGetBooleanFlag(key: String, defaultValue: Bool) -> Bool {
        guard let client = getInstance() else {
            return defaultValue
        }
        return client.getBooleanFeatureFlag(key: key, defaultValue: defaultValue)
    }
}
```

### 6. Testing

- Use dependency injection for testability
- Mock the SDK in unit tests
- Test both enabled and disabled feature states

```swift
protocol FeatureFlagProvider {
    func getBooleanFlag(key: String, defaultValue: Bool) -> Bool
}

class CustomFitFeatureFlagProvider: FeatureFlagProvider {
    func getBooleanFlag(key: String, defaultValue: Bool) -> Bool {
        return CFClient.getInstance()?.getBooleanFeatureFlag(
            key: key, 
            defaultValue: defaultValue
        ) ?? defaultValue
    }
}

class MockFeatureFlagProvider: FeatureFlagProvider {
    var flags: [String: Bool] = [:]
    
    func getBooleanFlag(key: String, defaultValue: Bool) -> Bool {
        return flags[key] ?? defaultValue
    }
}
```

## Troubleshooting

### Common Issues

#### 1. SDK Not Initializing

**Symptoms**: SDK methods return nil or default values

**Solutions**:
- Check your client key is correct
- Verify network connectivity
- Check console logs for initialization errors
- Ensure you're calling `initialize()` before using other methods

```swift
// Check initialization status
if !CFClient.isInitialized() {
    print("SDK not initialized")
    // Re-initialize or handle gracefully
}
```

#### 2. Config Values Not Updating

**Symptoms**: Feature flags don't change when updated in dashboard

**Solutions**:
- Check network connectivity
- Verify polling intervals in configuration
- Use config listeners for real-time updates
- Force a manual refresh

```swift
// Force refresh
CFClient.getInstance()?.refreshFeatures { result in
    switch result {
    case .success:
        print("Config refreshed successfully")
    case .error(let message, _, _, _):
        print("Failed to refresh config: \(message)")
    }
}
```

#### 3. Events Not Being Tracked

**Symptoms**: Events don't appear in CustomFit dashboard

**Solutions**:
- Check network connectivity
- Verify flush intervals
- Check event properties are serializable
- Monitor console logs for event tracking

```swift
// Check if events are being tracked
CFClient.getInstance()?.trackEvent(
    name: "test_event",
    properties: ["debug": true]
)
```

#### 4. High Battery Usage

**Symptoms**: App uses excessive battery

**Solutions**:
- Enable battery optimization features
- Increase polling intervals
- Disable background polling if not needed

```swift
let config = CFConfig.builder(clientKey)
    .useReducedPollingWhenBatteryLow(true)
    .backgroundPollingIntervalMs(300000) // 5 minutes
    .sdkSettingsCheckIntervalMs(60000)   // 1 minute
    .build()
```

### Debugging

#### Enable Debug Logging

```swift
let config = CFConfig.builder(clientKey)
    .debugLoggingEnabled(true)
    .logLevel("DEBUG")
    .build()
```

#### Monitor SDK Status

```swift
// Check connection status
CFClient.getInstance()?.addConnectionStatusListener { status, info in
    print("Connection status: \(status)")
    print("Connection info: \(info)")
}

// Monitor session statistics
let stats = CFClient.getInstance()?.getSessionStatistics()
print("Session stats: \(stats)")
```

### Logging

The SDK provides comprehensive logging to help with debugging:

- **SYSTEM**: Critical system messages
- **ERROR**: Error conditions
- **WARNING**: Warning conditions  
- **INFO**: General information
- **DEBUG**: Detailed debug information

Filter logs in Xcode console by searching for `Customfit.ai-SDK`.

## Examples

### Complete SwiftUI App

```swift
import SwiftUI
import CustomFitSwiftSDK

@main
struct MyApp: App {
    init() {
        setupCustomFit()
    }
    
    private func setupCustomFit() {
        let config = CFConfig.builder("your_client_key_here")
            .debugLoggingEnabled(true)
            .sdkSettingsCheckIntervalMs(30000)
            .build()
        
        let user = CFUser(user_customer_id: "user_123")
            .addProperty(key: "platform", value: "ios")
            .addProperty(key: "app_version", value: "1.0.0")
        
        CFClient.initialize(config: config, user: user)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var featureFlags = FeatureFlagManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("CustomFit Demo")
                    .font(.largeTitle)
                    .bold()
                
                if featureFlags.isNewUIEnabled {
                    NewFeatureView()
                } else {
                    LegacyView()
                }
                
                Button("Track Event") {
                    CFClient.getInstance()?.trackEvent(
                        name: "button_clicked",
                        properties: [
                            "screen": "main",
                            "feature": "demo_button"
                        ]
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

class FeatureFlagManager: ObservableObject {
    @Published var isNewUIEnabled = false
    @Published var welcomeMessage = "Welcome!"
    
    init() {
        loadInitialValues()
        setupListeners()
    }
    
    private func loadInitialValues() {
        guard let client = CFClient.getInstance() else { return }
        
        isNewUIEnabled = client.getBooleanFeatureFlag(
            key: "new_ui_enabled",
            defaultValue: false
        )
        
        welcomeMessage = client.getFeatureFlag(
            key: "welcome_message",
            defaultValue: "Welcome!"
        )
    }
    
    private func setupListeners() {
        CFClient.getInstance()?.addFeatureFlagListener(key: "new_ui_enabled") { [weak self] isEnabled in
            DispatchQueue.main.async {
                self?.isNewUIEnabled = isEnabled
            }
        }
        
        CFClient.getInstance()?.addConfigListener(key: "welcome_message") { [weak self] (message: String) in
            DispatchQueue.main.async {
                self?.welcomeMessage = message
            }
        }
    }
}

struct NewFeatureView: View {
    var body: some View {
        VStack {
            Text("🎉 New Feature!")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("This is the new improved UI")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct LegacyView: View {
    var body: some View {
        VStack {
            Text("Legacy UI")
                .font(.title2)
            
            Text("This is the current UI")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}
```

### UIKit Integration

```swift
import UIKit
import CustomFitSwiftSDK

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        setupCustomFit()
        return true
    }
    
    private func setupCustomFit() {
        let config = CFConfig.builder("your_client_key_here")
            .debugLoggingEnabled(true)
            .build()
        
        let user = CFUser(user_customer_id: getCurrentUserId())
            .addProperty(key: "platform", value: "ios")
        
        CFClient.initialize(config: config, user: user)
    }
    
    private func getCurrentUserId() -> String {
        // Get user ID from your user management system
        return "user_123"
    }
}

class ViewController: UIViewController {
    @IBOutlet weak var featureButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFeatureFlags()
        setupConfigListeners()
    }
    
    private func setupFeatureFlags() {
        guard let client = CFClient.getInstance() else { return }
        
        let isFeatureEnabled = client.getBooleanFeatureFlag(
            key: "new_feature_enabled",
            defaultValue: false
        )
        
        featureButton.isHidden = !isFeatureEnabled
        
        let statusMessage = client.getFeatureFlag(
            key: "status_message",
            defaultValue: "Ready"
        )
        
        statusLabel.text = statusMessage
    }
    
    private func setupConfigListeners() {
        CFClient.getInstance()?.addFeatureFlagListener(key: "new_feature_enabled") { [weak self] isEnabled in
            DispatchQueue.main.async {
                self?.featureButton.isHidden = !isEnabled
            }
        }
        
        CFClient.getInstance()?.addConfigListener(key: "status_message") { [weak self] (message: String) in
            DispatchQueue.main.async {
                self?.statusLabel.text = message
            }
        }
    }
    
    @IBAction func featureButtonTapped(_ sender: UIButton) {
        CFClient.getInstance()?.trackEvent(
            name: "feature_button_tapped",
            properties: [
                "screen": "main",
                "user_id": getCurrentUserId()
            ]
        )
    }
    
    deinit {
        CFClient.getInstance()?.clearConfigListeners(key: "new_feature_enabled")
        CFClient.getInstance()?.clearConfigListeners(key: "status_message")
    }
}
```

## Support

- **Documentation**: [CustomFit Docs](https://docs.customfit.ai)
- **API Reference**: [Swift SDK API](https://docs.customfit.ai/swift-sdk)
- **Support**: [support@customfit.ai](mailto:support@customfit.ai)
- **GitHub Issues**: [Report Issues](https://github.com/customfit/customfit-swift-sdk/issues)

## License

This SDK is licensed under the MIT License. See [LICENSE](LICENSE) file for details.

---

**CustomFit Swift SDK** - Empower your iOS apps with feature flags and dynamic configuration management. 