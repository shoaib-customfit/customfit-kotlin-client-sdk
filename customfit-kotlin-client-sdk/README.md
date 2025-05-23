# CustomFit Kotlin Client SDK

This repository contains the CustomFit Kotlin Client SDK, which is designed to help developers easily integrate CustomFit personalization features into their Kotlin applications.

## Feature Parity

The SDK has been designed with cross-platform feature parity in mind, with implementations in:

- Kotlin (primary reference implementation)
- Swift
- Flutter

All implementations maintain 100% feature parity, with consistent APIs and behavior across platforms.

## Key Components

The SDK is structured around several key components:

- **CFClient**: Main entry point for applications to interact with the SDK
- **ConfigManager**: Manages feature flags and configuration values
- **ListenerManager**: Manages event listeners for configuration changes and connectivity
- **EventTracker**: Tracks user events and sends them to the server
- **SummaryManager**: Manages analytics summaries for feature usage
- **ConnectionManager**: Manages network connectivity and connection status
- **CircuitBreaker**: Prevents cascading failures with three-state operation (open/closed/half-open)
- **RetryPolicy**: Provides robust retry mechanisms with exponential backoff and jitter
- **BackgroundTaskManager**: Schedules and manages background tasks with constraints
- **NetworkConnectivityMonitor**: Monitors network state changes in detail
- **BackgroundStateMonitor**: Monitors app foreground/background transitions and battery state

## Advanced Features

The SDK includes several advanced features to ensure robustness:

### Thread Safety

All components use proper thread synchronization with locks and atomic operations to ensure thread-safe operation, which is especially important for mobile applications that need to handle UI interactions while performing background tasks.

### Resilient Networking

- **Circuit Breaker Pattern**: Prevents cascading failures when services are down
- **Exponential Backoff with Jitter**: Smart retry mechanism minimizes retry storms
- **Connection State Monitoring**: Adapts behavior based on network availability
- **Graceful Degradation**: Falls back to cached values when offline

### Background Operation

- **Lifecycle Management**: Adapts behavior based on app state (foreground/background)
- **Battery Awareness**: Reduces activity when battery is low
- **Background Task Scheduling**: Intelligent scheduling with constraints

### Persistence and Caching

- **Event Storage**: Persists events when offline and sends them when connectivity is restored
- **Config Caching**: Maintains operation with cached values when offline
- **ETag/Last-Modified Support**: Efficient server communication with conditional requests

### Performance Optimization

- **Queue Management**: Efficient queue implementations with overflow handling
- **Batched Operations**: Groups operations for efficiency
- **Summary Merging**: Optimizes payloads by merging similar summaries
- **Memory Efficiency**: Careful resource management

## Configuration

The `CFConfig` class provides extensive configuration options:

```swift
// Create configuration with builder pattern
let config = CFConfig.Builder(clientKey: "your-client-key")
    .eventsQueueSize(100)
    .eventsFlushTimeSeconds(60)
    .networkConnectionTimeoutMs(10000)
    .offlineMode(false)
    .build()

// Initialize the SDK
let cfClient = CFClient.getInstance(config: config)
```

## Usage Examples

### Feature Flags

```swift
// Check a feature flag
let isFeatureEnabled = cfClient.getFeatureFlag(key: "my-feature", defaultValue: false)

// Listen for changes to a feature flag
cfClient.addFeatureFlagListener(key: "my-feature") { isEnabled in
    print("Feature flag changed: \(isEnabled)")
}
```

### Event Tracking

```swift
// Track a screen view
cfClient.trackScreenView(screenName: "Home Screen")

// Track a custom event
cfClient.trackEvent(name: "button_click", properties: ["button_id": "login"])

// Track feature usage
cfClient.trackFeatureUsage(featureId: "my-feature")
```

### User Management

```swift
// Set user ID
cfClient.setUserId(userId: "user123")

// Set user attributes
cfClient.setUserAttributes(attributes: [
    "age": 25,
    "plan": "premium"
])
```

## Latest Enhancements

The Swift implementation has been fully enhanced to match Kotlin's capabilities:

- **Comprehensive Thread Safety**: All components now have proper synchronization
- **Enhanced Network Connectivity**: Improved detection of network types and transitions
- **Robust Circuit Breaker**: Full implementation of the circuit breaker pattern with configurable parameters
- **Advanced Retry Mechanisms**: Exponential backoff with jitter for optimal retry behavior
- **Background Task Management**: iOS-optimized background task scheduling that respects system constraints
- **Memory Optimization**: Improved memory management for low-memory situations
- **Expanded Metrics**: More comprehensive telemetry for performance monitoring
- **Enhanced Config Caching**: Added support for delta updates and compressed configs

## Compatibility

The SDK supports:

- iOS 12+
- macOS 10.14+
- tvOS 12+
- watchOS 5+

## License

This project is licensed under the MIT License - see the LICENSE file for details.
