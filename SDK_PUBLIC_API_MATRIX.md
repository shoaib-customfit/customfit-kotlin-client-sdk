# SDK Public API Matrix

This document provides a comprehensive comparison of all public functions exposed across the four CustomFit SDKs: Kotlin, Swift, Flutter, and React Native.

## Main Client Class APIs

### Core Initialization & Singleton Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `initialize(config, user)` | ✅ `init()` | ✅ `initialize()` | ✅ `init()` | ✅ `initialize()` | `CFClient.init(config, user)` | Primary initialization |
| `getInstance()` | ✅ | ✅ | ✅ | ✅ | `CFClient.getInstance()` | Get singleton instance |
| `isInitialized()` | ✅ | ✅ | ✅ | ✅ | `CFClient.isInitialized()` | Check if initialized |
| `isInitializing()` | ✅ | ✅ | ✅ | ✅ | `CFClient.isInitializing()` | Check if in progress |
| `shutdownSingleton()` | ✅ | ✅ | ✅ | ✅ | `CFClient.shutdownSingleton()` | Shutdown singleton |
| `reinitialize()` | ✅ | ✅ | ✅ | ✅ | `CFClient.reinitialize(config, user)` | Force reinit |
| `createDetached()` | ✅ | ✅ | ✅ | ✅ | `CFClient.createDetached(config, user)` | Non-singleton instance |
| `createMinimalClient()` | ❌ | ✅ | ❌ | ❌ | `CFClient.createMinimalClient(config, user)` | Swift-specific |
| `shutdown()` | ✅ | ✅ | ✅ | ✅ | `client.shutdown()` | Instance shutdown |
| `close()` | ❌ | ❌ | ❌ | ✅ | `client.close()` | Alias for shutdown |

### Configuration Value Access

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `getString(key, default)` | ✅ | ✅ | ✅ | ✅ | `client.getString("key", "default")` | Get string config |
| `getNumber(key, default)` | ✅ | ✅ | ✅ | ✅ | `client.getNumber("key", 42)` | Get number config |
| `getBoolean(key, default)` | ✅ | ✅ | ✅ | ✅ | `client.getBoolean("key", false)` | Get boolean config |
| `getJson(key, default)` | ✅ | ✅ | ✅ | ✅ | `client.getJson("key", {})` | Get JSON config |
| `getFeatureFlag(key, default)` | ❌ | ✅ | ❌ | ✅ | `client.getFeatureFlag("key", false)` | Generic feature flag |
| `getFeatureValue(key, default)` | ❌ | ❌ | ❌ | ✅ | `client.getFeatureValue("key", "default")` | Alias for feature flag |
| `getAllFlags()` | ✅ | ✅ | ✅ | ✅ | `client.getAllFlags()` | Get all configurations |
| `getAllFeatures()` | ❌ | ❌ | ❌ | ✅ | `client.getAllFeatures()` | Alias for getAllFlags |

### Event Tracking

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `trackEvent(name, properties)` | ✅ | ✅ | ✅ | ✅ | `client.trackEvent("click", {"button": "signup"})` | Basic event tracking |
| `trackEvent(name, builder)` | ✅ | ❌ | ❌ | ❌ | `client.trackEvent("click") { put("button", "signup") }` | Builder pattern (Kotlin) |
| `trackScreenView(screen)` | ❌ | ❌ | ❌ | ✅ | `client.trackScreenView("home")` | Screen view tracking |
| `trackFeatureUsage(feature, props)` | ❌ | ❌ | ❌ | ✅ | `client.trackFeatureUsage("dark_mode", {"enabled": true})` | Feature usage tracking |
| `flushEvents()` | ✅ | ✅ | ✅ | ✅ | `client.flushEvents()` | Manual flush events |
| `flushSummaries()` | ❌ | ❌ | ❌ | ✅ | `client.flushSummaries()` | Manual flush summaries |

### User Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `addUserProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | `client.addUserProperty("age", 25)` | Add single property |
| `addStringProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | `client.addStringProperty("name", "John")` | Type-specific property |
| `addNumberProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | `client.addNumberProperty("score", 100)` | Type-specific property |
| `addBooleanProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | `client.addBooleanProperty("premium", true)` | Type-specific property |
| `addDateProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | `client.addDateProperty("signup", Date())` | Type-specific property |
| `addGeoPointProperty(key, lat, lon)` | ✅ | ✅ | ❌ | ❌ | `client.addGeoPointProperty("location", 37.7749, -122.4194)` | Geo property |
| `addJsonProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | `client.addJsonProperty("preferences", {"theme": "dark"})` | JSON property |
| `addUserProperties(properties)` | ✅ | ✅ | ❌ | ❌ | `client.addUserProperties({"age": 25, "city": "SF"})` | Bulk properties |
| `getUserProperties()` | ✅ | ✅ | ❌ | ❌ | `client.getUserProperties()` | Get all properties |
| `setUserAttribute(key, value)` | ❌ | ❌ | ❌ | ✅ | `client.setUserAttribute("age", 25)` | Set single attribute |
| `setUserAttributes(attributes)` | ❌ | ❌ | ❌ | ✅ | `client.setUserAttributes({"age": 25, "city": "SF"})` | Set multiple attributes |
| `setUser(user)` | ❌ | ❌ | ❌ | ✅ | `client.setUser(newUser)` | Replace user |
| `getUser()` | ❌ | ❌ | ❌ | ✅ | `client.getUser()` | Get current user |
| `incrementAppLaunchCount()` | ✅ | ✅ | ❌ | ✅ | `client.incrementAppLaunchCount()` | Increment launch count |

### Context Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `addContext(context)` | ✅ | ✅ | ❌ | ❌ | `client.addContext(locationContext)` | Add evaluation context |
| `removeContext(type, key)` | ✅ | ✅ | ❌ | ❌ | `client.removeContext(ContextType.LOCATION, "user_location")` | Remove context |
| `getContexts()` | ✅ | ✅ | ❌ | ❌ | `client.getContexts()` | Get all contexts |
| `setDeviceContext(context)` | ✅ | ✅ | ❌ | ❌ | `client.setDeviceContext(deviceInfo)` | Set device context |
| `getDeviceContext()` | ✅ | ✅ | ❌ | ❌ | `client.getDeviceContext()` | Get device context |
| `setApplicationInfo(info)` | ✅ | ✅ | ❌ | ❌ | `client.setApplicationInfo(appInfo)` | Set app info |
| `getApplicationInfo()` | ✅ | ✅ | ❌ | ❌ | `client.getApplicationInfo()` | Get app info |

### Listener Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `addConfigListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | `client.addConfigListener("dark_mode", callback)` | Config change listener |
| `removeConfigListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | `client.removeConfigListener("dark_mode", callback)` | Remove config listener |
| `clearConfigListeners(key)` | ✅ | ✅ | ❌ | ✅ | `client.clearConfigListeners("dark_mode")` | Clear all for key |
| `registerFeatureFlagListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | `client.registerFeatureFlagListener("flag", listener)` | Feature flag listener |
| `unregisterFeatureFlagListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | `client.unregisterFeatureFlagListener("flag", listener)` | Remove flag listener |
| `registerAllFlagsListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.registerAllFlagsListener(listener)` | All flags listener |
| `unregisterAllFlagsListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.unregisterAllFlagsListener(listener)` | Remove all flags listener |
| `addFeatureFlagListener(key, listener)` | ❌ | ❌ | ❌ | ✅ | `client.addFeatureFlagListener("flag", listener)` | Alias for register |
| `removeFeatureFlagListener(key, listener)` | ❌ | ❌ | ❌ | ✅ | `client.removeFeatureFlagListener("flag", listener)` | Alias for unregister |
| `addAllFlagsListener(listener)` | ❌ | ❌ | ❌ | ✅ | `client.addAllFlagsListener(listener)` | Alias for register |
| `removeAllFlagsListener(listener)` | ❌ | ❌ | ❌ | ✅ | `client.removeAllFlagsListener(listener)` | Alias for unregister |

### Connection Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `getConnectionInformation()` | ✅ | ✅ | ❌ | ✅ | `client.getConnectionInformation()` | Get connection status |
| `addConnectionStatusListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.addConnectionStatusListener(listener)` | Connection listener |
| `removeConnectionStatusListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.removeConnectionStatusListener(listener)` | Remove connection listener |
| `isOffline()` | ✅ | ✅ | ❌ | ✅ | `client.isOffline()` | Check offline status |
| `setOffline()` | ✅ | ✅ | ❌ | ❌ | `client.setOffline()` | Set offline mode |
| `setOnline()` | ✅ | ✅ | ❌ | ❌ | `client.setOnline()` | Set online mode |
| `setOfflineMode(offline)` | ❌ | ❌ | ❌ | ✅ | `client.setOfflineMode(true)` | Set offline mode bool |

### Configuration Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `forceRefresh()` | ❌ | ❌ | ❌ | ✅ | `client.forceRefresh()` | Force config refresh |
| `fetchConfigs()` | ❌ | ❌ | ✅ | ❌ | `client.fetchConfigs()` | Manual config fetch |
| `getMutableConfig()` | ❌ | ❌ | ❌ | ✅ | `client.getMutableConfig()` | Get mutable config |
| `awaitSdkSettingsCheck()` | ✅ | ❌ | ❌ | ✅ | `client.awaitSdkSettingsCheck()` | Wait for SDK settings |

### Runtime Configuration Updates

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `updateSdkSettingsCheckInterval(ms)` | ✅ | ✅ | ❌ | ✅ | `client.updateSdkSettingsCheckInterval(30000)` | Update settings interval |
| `updateEventsFlushInterval(ms)` | ✅ | ✅ | ❌ | ✅ | `client.updateEventsFlushInterval(60000)` | Update events interval |
| `updateSummariesFlushInterval(ms)` | ❌ | ❌ | ❌ | ✅ | `client.updateSummariesFlushInterval(120000)` | Update summaries interval |
| `updateNetworkConnectionTimeout(ms)` | ✅ | ✅ | ❌ | ✅ | `client.updateNetworkConnectionTimeout(30000)` | Update connection timeout |
| `updateNetworkReadTimeout(ms)` | ✅ | ✅ | ❌ | ✅ | `client.updateNetworkReadTimeout(15000)` | Update read timeout |
| `setDebugLoggingEnabled(enabled)` | ✅ | ✅ | ❌ | ✅ | `client.setDebugLoggingEnabled(true)` | Toggle debug logging |
| `setLoggingEnabled(enabled)` | ❌ | ❌ | ❌ | ✅ | `client.setLoggingEnabled(false)` | Toggle logging |

### Environment & Device

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `enableAutoEnvAttributes()` | ✅ | ✅ | ❌ | ✅ | `client.enableAutoEnvAttributes()` | Enable auto env attributes |
| `disableAutoEnvAttributes()` | ❌ | ❌ | ❌ | ✅ | `client.disableAutoEnvAttributes()` | Disable auto env attributes |
| `getEnvironmentAttributes()` | ❌ | ❌ | ❌ | ✅ | `client.getEnvironmentAttributes()` | Get env attributes |

### Lifecycle Management

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `pause()` | ❌ | ❌ | ❌ | ✅ | `client.pause()` | Pause SDK operations |
| `resume()` | ❌ | ❌ | ❌ | ✅ | `client.resume()` | Resume SDK operations |

### Metrics & Monitoring

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `getMetrics()` | ❌ | ❌ | ❌ | ✅ | `client.getMetrics()` | Get performance metrics |

## Session Management APIs

### Core Session Operations

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `getCurrentSessionId()` | ✅ | ✅ | ✅ | ✅ | `client.getCurrentSessionId()` | Get current session ID |
| `getCurrentSessionData()` | ✅ | ✅ | ✅ | ✅ | `client.getCurrentSessionData()` | Get session metadata |
| `getCurrentSession()` | ❌ | ❌ | ❌ | ✅ | `client.getCurrentSession()` | Alias for session data |
| `updateSessionActivity()` | ✅ | ✅ | ✅ | ✅ | `client.updateSessionActivity()` | Update activity timestamp |
| `forceSessionRotation()` | ✅ | ✅ | ✅ | ✅ | `client.forceSessionRotation()` | Manual rotation |
| `getSessionStatistics()` | ✅ | ✅ | ✅ | ✅ | `client.getSessionStatistics()` | Get session stats |

### Session Event Handling

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `onUserAuthenticationChange(userId)` | ✅ | ✅ | ✅ | ✅ | `client.onUserAuthenticationChange("user123")` | Handle auth changes |
| `onAppBackground()` | ✅ | ✅ | ✅ | ✅ | `sessionManager.onAppBackground()` | Handle background |
| `onAppForeground()` | ✅ | ✅ | ✅ | ✅ | `sessionManager.onAppForeground()` | Handle foreground |
| `onNetworkChange()` | ❌ | ❌ | ❌ | ✅ | `sessionManager.onNetworkChange()` | Handle network change |

### Session Listeners

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `addSessionRotationListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.addSessionRotationListener(listener)` | Add rotation listener |
| `removeSessionRotationListener(listener)` | ✅ | ✅ | ✅ | ✅ | `client.removeSessionRotationListener(listener)` | Remove rotation listener |

### SessionManager Singleton

| Function | Kotlin | Swift | Flutter | React Native | Usage Example | Notes |
|----------|--------|-------|---------|--------------|---------------|-------|
| `SessionManager.initialize(config)` | ✅ | ✅ | ✅ | ✅ | `SessionManager.initialize(sessionConfig)` | Initialize singleton |
| `SessionManager.getInstance()` | ✅ | ✅ | ✅ | ✅ | `SessionManager.getInstance()` | Get singleton |
| `SessionManager.shutdown()` | ✅ | ✅ | ✅ | ✅ | `SessionManager.shutdown()` | Shutdown singleton |

## Analysis & Recommendations

### 🔴 Critical Inconsistencies (Should be standardized)

1. **User Management**: Kotlin/Swift use `addUserProperty()` while React Native uses `setUserAttribute()`
2. **Feature Flag Access**: Mixed naming between `getFeatureFlag()`, `getBoolean()`, etc.
3. **Listener Management**: Some SDKs have both `register/unregister` and `add/remove` patterns
4. **Configuration Management**: Inconsistent refresh methods across SDKs

### 🟡 Medium Priority Inconsistencies (Consider standardizing)

1. **Context Management**: Missing from Flutter and React Native
2. **Environment Attributes**: Not fully implemented in all SDKs
3. **Runtime Configuration Updates**: Missing from Flutter
4. **Lifecycle Management**: Only in React Native

### 🟢 Minor Inconsistencies (Platform-specific, acceptable)

1. **Async Patterns**: Different based on platform conventions
2. **Type Safety**: Varies based on language capabilities
3. **Builder Patterns**: Kotlin-specific features

### Recommendations for Standardization

#### High Priority (API Consistency)
1. **Standardize user management methods** across all SDKs
2. **Align feature flag access methods** to consistent naming
3. **Unify listener management patterns** (prefer `add/remove` over `register/unregister`)
4. **Standardize configuration refresh methods**

#### Medium Priority (Feature Parity)
1. **Add context management** to Flutter and React Native
2. **Complete environment attributes** implementation in all SDKs
3. **Add runtime configuration updates** to Flutter
4. **Consider lifecycle management** for other SDKs

#### Low Priority (Nice to Have)
1. **Add convenience methods** like `trackScreenView()` to other SDKs
2. **Add metrics access** to other SDKs
3. **Consider builder patterns** for other platforms where appropriate

### Functions That Should Be Made Private

Based on the analysis, consider making these functions private:

#### CFClient Internal Methods
- `createDetached()` - Should be internal factory method
- `createMinimalClient()` - Debug/testing only, should be internal
- Configuration update methods that directly modify state without validation

#### SessionManager Internal Methods
- Individual storage methods (`storeCurrentSession()`, `loadStoredSession()`)
- Internal rotation logic methods
- Background/foreground handlers should be internal to CFClient integration

The public API should focus on the core user-facing functionality while keeping implementation details private. 