# SDK Public API Matrix

This document provides a comprehensive comparison of all public functions exposed across the four CustomFit SDKs: Kotlin, Swift, Flutter, and React Native.

## Main Client Class APIs

### Core Initialization & Singleton Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `initialize(config, user)` | ✅ `initialize()` | ✅ `initialize()` | ✅ `initialize()` | ✅ `initialize()` | `CFClient.initialize(config, user)` | Primary initialization |
| `getInstance()` | ✅ | ✅ | ✅ | ✅ | `CFClient.getInstance()` | Get singleton instance |
| `isInitialized()` | ✅ | ✅ | ✅ | ✅ | `CFClient.isInitialized()` | Check initialization status |
| `isInitializing()` | ✅ | ✅ | ✅ | ✅ | `CFClient.isInitializing()` | Check if initialization in progress |
| `shutdown()` | ✅ | ✅ | ✅ | ✅ | `CFClient.shutdown()` | Cleanup and shutdown |
| `reinitialize(config, user)` | ✅ | ✅ | ✅ | ✅ | `CFClient.reinitialize(config, user)` | Reinitialize with new config |
| `createDetached(config, user)` | ✅ | ✅ | ✅ | ✅ | `CFClient.createDetached(config, user)` | Create non-singleton instance |

### Feature Flag Evaluation

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `getFeatureFlag(key, defaultValue)` | ✅ | ✅ | ✅ | ✅ | `client.getFeatureFlag("feature", false)` | Generic flag getter |
| `getBoolean(key, defaultValue)` | ✅ | ✅ | ✅ | ✅ | `client.getBoolean("flag", false)` | Boolean flag |
| `getString(key, defaultValue)` | ✅ | ✅ | ✅ | ✅ | `client.getString("config", "default")` | String flag |
| `getNumber(key, defaultValue)` | ✅ | ✅ | ✅ | ✅ | `client.getNumber("limit", 100)` | Number flag |
| `getJson(key, defaultValue)` | ✅ | ✅ | ✅ | ✅ | `client.getJson("config", {})` | JSON object flag |
| `getAllFlags()` | ✅ | ✅ | ✅ | ✅ | `client.getAllFlags()` | Get all flags |

### User Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `setUser(user)` | ✅ | ✅ | ✅ | ✅ | `client.setUser(user)` | Set current user |
| `getUser()` | ✅ | ✅ | ✅ | ✅ | `client.getUser()` | Get current user |
| `addUserProperty(key, value)` | ✅ | ✅ | ✅ | ✅ | `client.addUserProperty("age", 25)` | Add generic property |
| `addStringProperty(key, value)` | ✅ | ✅ | ✅ | ✅ | `client.addStringProperty("name", "John")` | Add string property |
| `addNumberProperty(key, value)` | ✅ | ✅ | ✅ | ✅ | `client.addNumberProperty("age", 25)` | Add number property |
| `addBooleanProperty(key, value)` | ✅ | ✅ | ✅ | ✅ | `client.addBooleanProperty("premium", true)` | Add boolean property |
| `addDateProperty(key, value)` | ✅ | ✅ | ✅ | ✅ | `client.addDateProperty("signup", date)` | Add date property |
| `addGeoPointProperty(key, lat, lon)` | ✅ | ✅ | ✅ | ✅ | `client.addGeoPointProperty("location", 40.7, -74.0)` | Add geo location |
| `addJsonProperty(key, value)` | ✅ | ✅ | ✅ | ✅ | `client.addJsonProperty("metadata", obj)` | Add JSON object |
| `addUserProperties(properties)` | ✅ | ✅ | ✅ | ✅ | `client.addUserProperties(props)` | Add multiple properties |
| `getUserProperties()` | ✅ | ✅ | ✅ | ✅ | `client.getUserProperties()` | Get all user properties |

### Context Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `addContext(context)` | ✅ | ✅ | ✅ | ✅ | `client.addContext(context)` | Add evaluation context |
| `removeContext(type, key)` | ✅ | ✅ `removeContext(key)` | ✅ | ✅ | `client.removeContext(type, key)` | Remove context by type/key |
| `getContexts()` | ✅ | ✅ | ✅ | ✅ | `client.getContexts()` | Get all contexts |

### Event Tracking

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `trackEvent(name, properties)` | ✅ | ✅ | ✅ | ✅ | `client.trackEvent("click", props)` | Track custom event |
| `trackScreenView(screenName, properties)` | ✅ | ✅ | ✅ | ✅ | `client.trackScreenView("home", props)` | Track screen view |
| `trackFeatureUsage(featureName, properties)` | ✅ | ✅ | ✅ | ✅ | `client.trackFeatureUsage("search", props)` | Track feature usage |

### Configuration & Refresh

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `forceRefresh()` | ✅ | ✅ | ✅ | ✅ | `client.forceRefresh()` | Force config refresh |
| `awaitSdkSettingsCheck()` | ✅ | ✅ | ✅ | ✅ | `client.awaitSdkSettingsCheck()` | Wait for SDK settings |

### Runtime Configuration Updates

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `updateSdkSettingsCheckInterval(intervalMs)` | ✅ | ✅ | ✅ | ✅ (placeholder) | `client.updateSdkSettingsCheckInterval(30000)` | Update settings check interval |
| `updateEventsFlushInterval(intervalMs)` | ✅ | ✅ | ✅ | ✅ (placeholder) | `client.updateEventsFlushInterval(10000)` | Update events flush interval |
| `updateSummariesFlushInterval(intervalMs)` | ✅ | ✅ | ✅ | ✅ (placeholder) | `client.updateSummariesFlushInterval(15000)` | Update summaries flush interval |
| `updateNetworkConnectionTimeout(timeoutMs)` | ✅ | ✅ | ✅ | ✅ (placeholder) | `client.updateNetworkConnectionTimeout(5000)` | Update connection timeout |
| `updateNetworkReadTimeout(timeoutMs)` | ✅ | ✅ | ✅ | ✅ (placeholder) | `client.updateNetworkReadTimeout(10000)` | Update read timeout |
| `setDebugLoggingEnabled(enabled)` | ✅ | ✅ | ✅ | ✅ (placeholder) | `client.setDebugLoggingEnabled(true)` | Enable/disable debug logging |
| `setLoggingEnabled(enabled)` | ✅ | ✅ | ✅ | ✅ (placeholder) | `client.setLoggingEnabled(false)` | Enable/disable logging |

### Offline Mode & Connection Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `setOfflineMode(offline)` | ✅ | ✅ | ✅ | ✅ | `client.setOfflineMode(true)` | Enable/disable offline mode |
| `isOffline()` | ✅ | ✅ | ✅ | ✅ | `client.isOffline()` | Check offline status |
| `getConnectionInformation()` | ✅ | ✅ | ✅ | ✅ | `client.getConnectionInformation()` | Get connection status |

### Lifecycle Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `pause()` | ✅ | ✅ | ✅ | ✅ | `client.pause()` | Pause SDK operations |
| `resume()` | ✅ | ✅ | ✅ | ✅ | `client.resume()` | Resume SDK operations |
| `incrementAppLaunchCount()` | ✅ | ✅ | ✅ | ✅ | `client.incrementAppLaunchCount()` | Track app launches |

### Environment & Device Information

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `enableAutoEnvironmentAttributes()` | ✅ | ✅ | ✅ | ✅ | `client.enableAutoEnvironmentAttributes()` | Auto-collect device info |

### Listener Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `addFeatureFlagListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | `client.addFeatureFlagListener("flag", listener)` | Listen to flag changes |
| `removeFeatureFlagListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | `client.removeFeatureFlagListener("flag", listener)` | Remove flag listener |
| `addAllFlagsListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.addAllFlagsListener(listener)` | Listen to all flag changes |
| `removeAllFlagsListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.removeAllFlagsListener(listener)` | Remove all flags listener |
| `addConnectionStatusListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.addConnectionStatusListener(listener)` | Listen to connection changes |
| `removeConnectionStatusListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.removeConnectionStatusListener(listener)` | Remove connection listener |

### Session Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `getCurrentSessionId()` | ✅ | ✅ | ✅ | ✅ | `client.getCurrentSessionId()` | Get current session ID |
| `getCurrentSessionData()` | ✅ | ✅ | ✅ | ✅ | `client.getCurrentSessionData()` | Get session metadata |
| `forceSessionRotation()` | ✅ | ✅ | ✅ | ✅ | `client.forceSessionRotation()` | Force new session |
| `updateSessionActivity()` | ✅ | ✅ | ✅ | ✅ | `client.updateSessionActivity()` | Update session activity |
| `onUserAuthenticationChange(userId)` | ✅ | ✅ | ✅ | ✅ | `client.onUserAuthenticationChange(userId)` | Handle auth changes |
| `getSessionStatistics()` | ✅ | ✅ | ✅ | ✅ | `client.getSessionStatistics()` | Get session stats |
| `addSessionRotationListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.addSessionRotationListener(listener)` | Listen to session changes |
| `removeSessionRotationListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.removeSessionRotationListener(listener)` | Remove session listener |

### Performance & Metrics

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `getMetrics()` | ✅ | ✅ | ✅ | ✅ | `client.getMetrics()` | Get performance metrics |

## Implementation Status Summary

### ✅ Fully Implemented
- **Core Initialization**: All SDKs have complete singleton management
- **Feature Flag Evaluation**: All flag types supported across all SDKs
- **Event Tracking**: Complete event tracking capabilities
- **Session Management**: Full session lifecycle management
- **Listener Management**: Comprehensive listener support

### 🔄 Recently Added/Updated
- **User Management**: Flutter SDK now has complete user property management
- **Context Management**: Swift SDK now has context management APIs
- **Runtime Configuration**: All SDKs now support runtime config updates (React Native has placeholders)
- **Offline Mode**: Standardized across all SDKs

### 📝 Notes
- **React Native Runtime Config**: Methods are implemented as placeholders pending MutableConfig implementation
- **Swift Context Management**: Uses simplified approach with key-based removal
- **Type Safety**: All SDKs maintain type safety for their respective languages
- **Error Handling**: Consistent error handling patterns across all SDKs

## Platform-Specific Considerations

### Kotlin
- Uses coroutines for async operations
- Comprehensive error handling with ErrorHandler
- Full MutableConfig support for runtime updates

### Swift
- Uses async/await for modern Swift concurrency
- Immutable config pattern requires full reconstruction for updates
- Strong type safety with Swift generics

### Flutter
- Dart-native async/await patterns
- copyWith pattern for config updates
- Comprehensive error handling

### React Native
- TypeScript interfaces for type safety
- Promise-based async operations
- Placeholder runtime config pending MutableConfig implementation

This matrix represents the current state after implementing the high and medium priority improvements requested. 