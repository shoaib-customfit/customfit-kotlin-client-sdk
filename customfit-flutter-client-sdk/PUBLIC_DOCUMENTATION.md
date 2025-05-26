# CustomFit Flutter SDK Documentation

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/customfit/flutter-sdk)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/flutter-3.0.0+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/dart-3.2.3+-blue.svg)](https://dart.dev)

CustomFit Flutter SDK enables seamless integration of real-time feature flags, user analytics, and personalization capabilities into your Flutter applications. Built with performance, reliability, and developer experience in mind.

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
- [Flutter Integration](#flutter-integration)
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
The SDK maintains persistent connections to receive instant flag updates, ensuring your Flutter app responds immediately to configuration changes without requiring restarts.

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
- Flutter 3.0.0 or higher
- Dart 3.2.3 or higher

### Add to pubspec.yaml
```yaml
dependencies:
  customfit_flutter_client_sdk: ^1.0.0
```

### Install Dependencies
```bash
flutter pub get
```

### Import the SDK
```dart
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';
```

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';

// Create configuration
final config = CFConfig.builder("your-client-key-here")
    .setDebugLoggingEnabled(true)
    .setEventsFlushIntervalMs(5000)
    .build();

// Create user
final user = CFUser(
  userCustomerId: "user123",
  properties: {
    'plan': 'premium',
    'age': 25,
  },
);

// Initialize client (async)
final client = await CFClient.initialize(config, user);

print("CustomFit SDK initialized successfully!");
```

### 2. Use Feature Flags

```dart
// Get a boolean feature flag
final newUIEnabled = client.getBoolean("new_ui_enabled", false);

// Get a string configuration
final welcomeMessage = client.getString("welcome_message", "Welcome!");

// Get a number value
final maxRetries = client.getNumber("max_retries", 3);

// Get JSON configuration
final themeConfig = client.getJson("theme_config", {"color": "blue"});
```

### 3. Track Events

```dart
// Track a simple event
await client.trackEvent("button_clicked", properties: {
  "button_id": "login",
});

// Track with rich properties
await client.trackEvent("page_viewed", properties: {
  "page_name": "dashboard",
  "load_time": 1.2,
  "first_visit": true,
});
```

## Configuration

The `CFConfig` class provides extensive customization options using the builder pattern:

```dart
final config = CFConfig.builder("your-client-key")
    // Logging
    .setDebugLoggingEnabled(true)
    .setLogLevel("DEBUG")
    
    // Event tracking
    .setEventsQueueSize(100)
    .setEventsFlushTimeSeconds(30)
    .setEventsFlushIntervalMs(5000)
    
    // Network settings
    .setNetworkConnectionTimeoutMs(10000)
    .setNetworkReadTimeoutMs(15000)
    
    // Background behavior
    .setBackgroundPollingIntervalMs(60000)
    .setUseReducedPollingWhenBatteryLow(true)
    .setReducedPollingIntervalMs(300000)
    
    // Retry configuration
    .setMaxRetryAttempts(3)
    .setRetryInitialDelayMs(1000)
    .setRetryMaxDelayMs(30000)
    .setRetryBackoffMultiplier(2.0)
    
    // Offline support
    .setOfflineMode(false)
    .setMaxStoredEvents(1000)
    
    // Auto environment detection
    .setAutoEnvAttributesEnabled(true)
    
    .build();
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `setDebugLoggingEnabled` | Enable detailed debug logging | `false` |
| `setEventsQueueSize` | Maximum events in memory queue | `100` |
| `setEventsFlushIntervalMs` | Automatic event flush interval | `30000` |
| `setNetworkConnectionTimeoutMs` | Network connection timeout | `10000` |
| `setBackgroundPollingIntervalMs` | Config polling when app in background | `3600000` |
| `setUseReducedPollingWhenBatteryLow` | Reduce polling on low battery | `true` |
| `setMaxRetryAttempts` | Maximum retry attempts for failed requests | `3` |
| `setOfflineMode` | Start in offline mode | `false` |
| `setAutoEnvAttributesEnabled` | Auto-detect device/app context | `false` |

## User Management

### Creating Users

```dart
// Identified user with properties
final user = CFUser(
  userCustomerId: "user123",
  properties: {
    'email': 'user@example.com',
    'plan': 'premium',
    'age': 28,
    'beta_tester': true,
    'signup_date': DateTime.now().millisecondsSinceEpoch,
    'preferences': {
      'theme': 'dark',
      'notifications': true,
    },
  },
);

// Anonymous user
final anonymousUser = CFUser(
  userCustomerId: "anonymous_123",
  anonymous: true,
  properties: {
    'source': 'mobile_app',
  },
);
```

### Updating User Properties

```dart
// Add single property
client.addStringProperty("subscription_tier", "pro");
client.addNumberProperty("login_count", 15);
client.addBooleanProperty("verified_email", true);

// Add multiple properties
client.addUserProperties({
  'last_activity': DateTime.now().millisecondsSinceEpoch,
  'device_type': 'mobile',
  'app_version': '2.1.0',
});
```

### User Contexts

```dart
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';

// Add evaluation contexts for targeting
final locationContext = EvaluationContext(
  type: ContextType.location,
  key: "current_location",
  attributes: {
    "country": "US",
    "state": "CA",
    "city": "San Francisco",
  },
);

final deviceContext = EvaluationContext(
  type: ContextType.device,
  key: "device_info",
  attributes: {
    "platform": "Android",
    "version": "13",
    "model": "Pixel 7",
  },
);

client.addContext(locationContext);
client.addContext(deviceContext);
```

## Feature Flags

### Basic Flag Retrieval

```dart
// Boolean flags
final isNewFeatureEnabled = client.getBoolean("new_feature", false);
final showBetaFeatures = client.getBoolean("beta_features", false);

// String flags
final apiEndpoint = client.getString("api_endpoint", "https://api.example.com");
final welcomeMessage = client.getString("welcome_text", "Welcome!");

// Number flags
final maxFileSize = client.getNumber("max_file_size_mb", 10);
final retryAttempts = client.getNumber("retry_attempts", 3);

// JSON flags
final featureConfig = client.getJson("feature_config", {
  "enabled": true,
  "max_users": 100,
});
```

### Generic Feature Flag Access

```dart
// Type-safe generic access
final feature = client.getFeatureFlag<bool>("my_feature", false);
final config = client.getFeatureFlag<Map<String, dynamic>>("config", {});
```

## Event Tracking

### Simple Event Tracking

```dart
// Basic event
await client.trackEvent("user_login");

// Event with properties
await client.trackEvent("purchase_completed", properties: {
  "product_id": "prod_123",
  "amount": 99.99,
  "currency": "USD",
  "payment_method": "credit_card",
});
```

### Rich Event Properties

```dart
await client.trackEvent("video_watched", properties: {
  "video_id": "vid_456",
  "duration_seconds": 120.5,
  "completed": true,
  "metadata": {
    "quality": "HD",
    "subtitles": true,
  },
});
```

### Event Result Handling

```dart
try {
  await client.trackEvent("user_action", properties: {"action": "click"});
  print("Event tracked successfully");
} catch (error) {
  print("Failed to track event: $error");
}
```

## Session Management

The SDK automatically manages user sessions with configurable rotation policies.

### Getting Session Information

```dart
// Get current session ID
final sessionId = client.getCurrentSessionId();

// Get detailed session data
final sessionData = client.getCurrentSessionData();
if (sessionData != null) {
  print("Session: ${sessionData.sessionId}");
  print("Started: ${sessionData.startTime}");
  print("Last activity: ${sessionData.lastActivityTime}");
}

// Get session statistics
final stats = client.getSessionStatistics();
print("Session stats: $stats");
```

### Manual Session Control

```dart
// Force session rotation
final newSessionId = await client.forceSessionRotation();
print("New session: $newSessionId");

// Update activity (call on user interactions)
await client.updateSessionActivity();

// Handle authentication changes
await client.onUserAuthenticationChange("new_user_id");
```

### Session Listeners

```dart
// Create a session listener
class MySessionListener implements SessionRotationListener {
  @override
  void onSessionRotated(String? oldSessionId, String newSessionId, RotationReason reason) {
    print("Session rotated: $oldSessionId -> $newSessionId (${reason.description})");
    // Update analytics, clear caches, etc.
  }
  
  @override
  void onSessionRestored(String sessionId) {
    print("Session restored: $sessionId");
  }
  
  @override
  void onSessionError(String error) {
    print("Session error: $error");
  }
}

final sessionListener = MySessionListener();
client.addSessionRotationListener(sessionListener);
```

## Listeners & Callbacks

### Feature Flag Change Listeners

```dart
// Listen to specific flag changes
client.addConfigListener<bool>("dark_mode", (isEnabled) {
  print("Dark mode changed: $isEnabled");
  updateUITheme(isEnabled);
});

client.addConfigListener<String>("api_url", (url) {
  print("API URL changed: $url");
  updateApiEndpoint(url);
});
```

### All Flags Listener

```dart
// Listen to all flag changes
client.addAllFlagsListener((oldFlags, newFlags) {
  print("Flags updated: ${newFlags.length} flags");
  newFlags.forEach((key, value) {
    print("  $key = $value");
  });
});
```

### Connection Status Listeners

```dart
// Listen to connection status changes
client.addConnectionStatusListener((status, info) {
  switch (status) {
    case ConnectionStatus.connected:
      print("Connected to CustomFit");
      break;
    case ConnectionStatus.disconnected:
      print("Disconnected from CustomFit");
      break;
    case ConnectionStatus.connecting:
      print("Connecting...");
      break;
    case ConnectionStatus.error:
      print("Connection error");
      break;
  }
});

// Get current connection info
final connectionInfo = client.getConnectionInformation();
print("Connection: ${connectionInfo.status}, Type: ${connectionInfo.networkType}");
```

## Offline Support

The SDK provides robust offline capabilities with automatic synchronization when connectivity is restored.

### Offline Mode Control

```dart
// Check if offline
final isOffline = client.isOffline();

// Enable offline mode
client.setOffline(true);

// Restore online mode
client.setOffline(false);
```

### Offline Configuration

```dart
final config = CFConfig.builder("your-client-key")
    .setOfflineMode(true)  // Start in offline mode
    .setMaxStoredEvents(1000)  // Max events to store offline
    .build();
```

### Offline Behavior

- **Feature flags**: Return cached values or defaults
- **Events**: Queued locally and sent when online
- **Configuration updates**: Resume when connectivity restored
- **Automatic synchronization**: Seamless transition between offline/online

## Advanced Features

### Force Configuration Refresh

```dart
// Force refresh from server (ignores cache)
final success = await client.forceRefresh();
print("Refresh successful: $success");
```

### Runtime Configuration Updates

```dart
// Update polling intervals
client.updateSdkSettingsCheckInterval(60000); // 1 minute

// Update event flush intervals
client.updateEventsFlushInterval(10000); // 10 seconds

// Update network timeouts
client.updateNetworkConnectionTimeout(15000);
client.updateNetworkReadTimeout(20000);

// Toggle logging
client.setDebugLoggingEnabled(true);
client.setLoggingEnabled(false);
```

### Background State Optimization

The SDK automatically optimizes behavior based on app state:

- **Foreground**: Normal polling and event tracking
- **Background**: Reduced polling frequency
- **Low battery**: Further reduced activity
- **No connectivity**: Offline mode with local queuing

## Error Handling

The SDK uses `CFResult<T>` for standardized error handling:

```dart
// Pattern 1: Try-catch
try {
  await client.trackEvent("user_action");
  print("Event tracked successfully");
} catch (error) {
  print("Failed to track event: $error");
}

// Pattern 2: Checking result
final result = await client.trackEvent("user_action");
result.fold(
  onSuccess: (data) => print("Event tracked: ${data.eventId}"),
  onError: (error) => print("Failed: $error"),
);
```

## Flutter Integration

### State Management Integration

#### Using Provider

```dart
class CustomFitProvider with ChangeNotifier {
  CFClient? _client;
  bool _darkMode = false;
  String _welcomeMessage = "Welcome!";

  bool get darkMode => _darkMode;
  String get welcomeMessage => _welcomeMessage;

  Future<void> initialize() async {
    final config = CFConfig.builder("your-client-key")
        .setDebugLoggingEnabled(true)
        .build();

    final user = CFUser(userCustomerId: "user123");
    
    _client = await CFClient.initialize(config, user);
    
    // Set up listeners
    _client!.addConfigListener<bool>("dark_mode", (value) {
      _darkMode = value;
      notifyListeners();
    });
    
    _client!.addConfigListener<String>("welcome_message", (value) {
      _welcomeMessage = value;
      notifyListeners();
    });
    
    // Update initial values
    _darkMode = _client!.getBoolean("dark_mode", false);
    _welcomeMessage = _client!.getString("welcome_message", "Welcome!");
    notifyListeners();
  }

  Future<void> trackEvent(String eventName, {Map<String, dynamic>? properties}) async {
    await _client?.trackEvent(eventName, properties: properties ?? {});
  }
}
```

#### Using Bloc

```dart
class FeatureFlagCubit extends Cubit<FeatureFlagState> {
  final CFClient _client;

  FeatureFlagCubit(this._client) : super(FeatureFlagState.initial()) {
    _setupListeners();
  }

  void _setupListeners() {
    _client.addConfigListener<bool>("new_feature", (enabled) {
      emit(state.copyWith(newFeatureEnabled: enabled));
    });
  }

  Future<void> refreshFlags() async {
    emit(state.copyWith(isLoading: true));
    final success = await _client.forceRefresh();
    emit(state.copyWith(isLoading: false, refreshSuccess: success));
  }
}
```

### Widget Integration

```dart
class FeatureFlagWidget extends StatelessWidget {
  final String flagKey;
  final Widget Function(bool enabled) builder;
  final bool defaultValue;

  const FeatureFlagWidget({
    Key? key,
    required this.flagKey,
    required this.builder,
    this.defaultValue = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomFitProvider>(
      builder: (context, provider, _) {
        final client = CFClient.getInstance();
        final isEnabled = client?.getBoolean(flagKey, defaultValue) ?? defaultValue;
        return builder(isEnabled);
      },
    );
  }
}

// Usage
FeatureFlagWidget(
  flagKey: "new_ui",
  builder: (enabled) => enabled 
    ? NewUIComponent() 
    : OldUIComponent(),
)
```

## Best Practices

### 1. Initialization

```dart
// ✅ Good: Initialize once in main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final config = CFConfig.builder("your-client-key").build();
  final user = CFUser(userCustomerId: "user123");
  
  await CFClient.initialize(config, user);
  
  runApp(MyApp());
}

// ✅ Access singleton anywhere
final client = CFClient.getInstance();
final isFeatureEnabled = client?.getBoolean("feature", false) ?? false;
```

### 2. State Management

```dart
// ✅ Good: Use proper state management
class MyProvider with ChangeNotifier {
  void setupListeners() {
    final client = CFClient.getInstance();
    client?.addConfigListener<String>("theme", (theme) {
      notifyListeners(); // Trigger UI rebuild
    });
  }
}

// ❌ Avoid: Direct widget polling
class BadWidget extends StatefulWidget {
  @override
  _BadWidgetState createState() => _BadWidgetState();
}

class _BadWidgetState extends State<BadWidget> {
  @override
  Widget build(BuildContext context) {
    // This polls on every build - inefficient!
    final client = CFClient.getInstance();
    final theme = client?.getString("theme", "light") ?? "light";
    return Container();
  }
}
```

### 3. Event Tracking

```dart
// ✅ Good: Use meaningful event names and properties
await client.trackEvent("purchase_completed", properties: {
  "product_category": "electronics",
  "revenue": 99.99,
  "payment_method": "credit_card",
  "first_purchase": true,
});

// ❌ Avoid: Generic events without context
await client.trackEvent("click", properties: {"type": "button"});
```

### 4. Resource Management

```dart
// ✅ Good: Cleanup in dispose
class MyProvider with ChangeNotifier {
  @override
  void dispose() {
    final client = CFClient.getInstance();
    client?.removeConfigListener("my_flag");
    super.dispose();
  }
}
```

### 5. Error Handling

```dart
// ✅ Good: Handle both success and error cases
try {
  await client.trackEvent("user_action");
  showSuccessMessage();
} catch (error) {
  logError(error);
  showFallbackUI();
}
```

## API Reference

### CFClient

#### Initialization
- `static Future<CFClient> initialize(CFConfig config, CFUser user)`
- `static CFClient? getInstance()`
- `static bool isInitialized()`
- `static Future<void> shutdownSingleton()`

#### Feature Flags
- `T getFeatureFlag<T>(String key, T defaultValue)`
- `String getString(String key, String defaultValue)`
- `num getNumber(String key, num defaultValue)`
- `bool getBoolean(String key, bool defaultValue)`
- `Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue)`

#### Event Tracking
- `Future<CFResult<void>> trackEvent(String eventType, {Map<String, dynamic>? properties})`

#### User Management
- `void addUserProperty(String key, dynamic value)`
- `void addStringProperty(String key, String value)`
- `void addNumberProperty(String key, num value)`
- `void addBooleanProperty(String key, bool value)`
- `void addUserProperties(Map<String, dynamic> properties)`

#### Session Management
- `String getCurrentSessionId()`
- `SessionData? getCurrentSessionData()`
- `Future<String?> forceSessionRotation()`
- `Future<void> updateSessionActivity()`

#### Listeners
- `void addConfigListener<T>(String key, void Function(T) listener)`
- `void addFeatureFlagListener(String flagKey, void Function(String, dynamic, dynamic) listener)`
- `void addAllFlagsListener(void Function(Map<String, dynamic>, Map<String, dynamic>) listener)`

#### Offline Support
- `bool isOffline()`
- `void setOffline(bool offline)`

### CFConfig.Builder

Configuration builder methods for customizing SDK behavior.

### CFUser

User model for setting user properties and contexts.

## Troubleshooting

### Common Issues

#### 1. Initialization Failures

```dart
// Problem: Client not initializing
// Solution: Check client key format and network connectivity
try {
  final client = await CFClient.initialize(config, user);
  print("Initialized successfully");
} catch (e) {
  print("Init failed: $e");
  // Check client key, network, etc.
}
```

#### 2. Feature Flags Not Updating

```dart
// Problem: Flags returning default values
// Solution: Verify initialization and check logs
final success = await client.forceRefresh();
if (!success) {
  print("Failed to refresh configs");
}

// Check if offline
if (client.isOffline()) {
  client.setOffline(false);
}
```

#### 3. Events Not Being Sent

```dart
// Problem: Events stuck in queue
// Solution: Check network and flush manually
try {
  await client.trackEvent("test_event");
  print("Event tracked successfully");
} catch (error) {
  print("Event error: $error");
  // Check network connectivity
  if (!client.isOffline()) {
    // Events will be sent when connectivity is restored
  }
}
```

### Debug Logging

Enable debug logging to troubleshoot issues:

```dart
final config = CFConfig.builder("your-client-key")
    .setDebugLoggingEnabled(true)
    .setLogLevel("DEBUG")
    .build();
```

### Performance Monitoring

```dart
// Monitor session statistics
final stats = client.getSessionStatistics();
print("Session stats: $stats");

// Monitor connection status
final connectionInfo = client.getConnectionInformation();
print("Connection: ${connectionInfo.status}");
```

---

## Support

For technical support, documentation updates, or feature requests:

- **Documentation**: [https://docs.customfit.ai](https://docs.customfit.ai)
- **GitHub Issues**: [https://github.com/customfit/flutter-sdk/issues](https://github.com/customfit/flutter-sdk/issues)
- **Support Email**: support@customfit.ai

## License

This SDK is released under the MIT License. See [LICENSE](LICENSE) file for details.

---

*This documentation is for CustomFit Flutter SDK v1.0.0. For the latest updates, visit our [documentation site](https://docs.customfit.ai).* 