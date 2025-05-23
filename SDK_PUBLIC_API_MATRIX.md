# SDK Public API Matrix

This document provides a comprehensive comparison of all public functions exposed across the four CustomFit SDKs: Kotlin, Swift, Flutter, and React Native.

## Main Client Class APIs

### Core Initialization & Singleton Management

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `initialize(config, user)` | ✅ `init()` | ✅ `initialize()` | ✅ `init()` | ✅ `initialize()` | Primary initialization |
| `getInstance()` | ✅ | ✅ | ✅ | ✅ | Get singleton instance |
| `isInitialized()` | ✅ | ✅ | ✅ | ✅ | Check if initialized |
| `isInitializing()` | ✅ | ✅ | ✅ | ✅ | Check if in progress |
| `shutdownSingleton()` | ✅ | ✅ | ✅ | ✅ | Shutdown singleton |
| `reinitialize()` | ✅ | ✅ | ✅ | ✅ | Force reinit |
| `createDetached()` | ✅ | ✅ | ✅ | ✅ | Non-singleton instance |
| `createMinimalClient()` | ❌ | ✅ | ❌ | ❌ | Swift-specific |
| `shutdown()` | ✅ | ✅ | ✅ | ✅ | Instance shutdown |
| `close()` | ❌ | ❌ | ❌ | ✅ | Alias for shutdown |

### Configuration Value Access

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `getString(key, default)` | ✅ | ✅ | ✅ | ✅ | Get string config |
| `getNumber(key, default)` | ✅ | ✅ | ✅ | ✅ | Get number config |
| `getBoolean(key, default)` | ✅ | ✅ | ✅ | ✅ | Get boolean config |
| `getJson(key, default)` | ✅ | ✅ | ✅ | ✅ | Get JSON config |
| `getFeatureFlag(key, default)` | ❌ | ✅ | ❌ | ✅ | Generic feature flag |
| `getFeatureValue(key, default)` | ❌ | ❌ | ❌ | ✅ | Alias for feature flag |
| `getAllFlags()` | ✅ | ✅ | ✅ | ✅ | Get all configurations |
| `getAllFeatures()` | ❌ | ❌ | ❌ | ✅ | Alias for getAllFlags |

### Event Tracking

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `trackEvent(name, properties)` | ✅ | ✅ | ✅ | ✅ | Basic event tracking |
| `trackEvent(name, builder)` | ✅ | ❌ | ❌ | ❌ | Builder pattern (Kotlin) |
| `trackScreenView(screen)` | ❌ | ❌ | ❌ | ✅ | Screen view tracking |
| `trackFeatureUsage(feature, props)` | ❌ | ❌ | ❌ | ✅ | Feature usage tracking |
| `flushEvents()` | ✅ | ✅ | ✅ | ✅ | Manual flush events |
| `flushSummaries()` | ❌ | ❌ | ❌ | ✅ | Manual flush summaries |

### User Management

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `addUserProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | Add single property |
| `addStringProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | Type-specific property |
| `addNumberProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | Type-specific property |
| `addBooleanProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | Type-specific property |
| `addDateProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | Type-specific property |
| `addGeoPointProperty(key, lat, lon)` | ✅ | ✅ | ❌ | ❌ | Geo property |
| `addJsonProperty(key, value)` | ✅ | ✅ | ❌ | ❌ | JSON property |
| `addUserProperties(properties)` | ✅ | ✅ | ❌ | ❌ | Bulk properties |
| `getUserProperties()` | ✅ | ✅ | ❌ | ❌ | Get all properties |
| `setUserAttribute(key, value)` | ❌ | ❌ | ❌ | ✅ | Set single attribute |
| `setUserAttributes(attributes)` | ❌ | ❌ | ❌ | ✅ | Set multiple attributes |
| `setUser(user)` | ❌ | ❌ | ❌ | ✅ | Replace user |
| `getUser()` | ❌ | ❌ | ❌ | ✅ | Get current user |
| `incrementAppLaunchCount()` | ✅ | ✅ | ❌ | ✅ | Increment launch count |

### Context Management

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `addContext(context)` | ✅ | ✅ | ❌ | ❌ | Add evaluation context |
| `removeContext(type, key)` | ✅ | ✅ | ❌ | ❌ | Remove context |
| `getContexts()` | ✅ | ✅ | ❌ | ❌ | Get all contexts |
| `setDeviceContext(context)` | ✅ | ✅ | ❌ | ❌ | Set device context |
| `getDeviceContext()` | ✅ | ✅ | ❌ | ❌ | Get device context |
| `setApplicationInfo(info)` | ✅ | ✅ | ❌ | ❌ | Set app info |
| `getApplicationInfo()` | ✅ | ✅ | ❌ | ❌ | Get app info |

### Listener Management

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `addConfigListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | Config change listener |
| `removeConfigListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | Remove config listener |
| `clearConfigListeners(key)` | ✅ | ✅ | ❌ | ✅ | Clear all for key |
| `registerFeatureFlagListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | Feature flag listener |
| `unregisterFeatureFlagListener(key, listener)` | ✅ | ✅ | ✅ | ✅ | Remove flag listener |
| `registerAllFlagsListener(listener)` | ✅ | ✅ | ✅ | ✅ | All flags listener |
| `unregisterAllFlagsListener(listener)` | ✅ | ✅ | ✅ | ✅ | Remove all flags listener |
| `addFeatureFlagListener(key, listener)` | ❌ | ❌ | ❌ | ✅ | Alias for register |
| `removeFeatureFlagListener(key, listener)` | ❌ | ❌ | ❌ | ✅ | Alias for unregister |
| `addAllFlagsListener(listener)` | ❌ | ❌ | ❌ | ✅ | Alias for register |
| `removeAllFlagsListener(listener)` | ❌ | ❌ | ❌ | ✅ | Alias for unregister |

### Connection Management

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `getConnectionInformation()` | ✅ | ✅ | ❌ | ✅ | Get connection status |
| `addConnectionStatusListener(listener)` | ✅ | ✅ | ✅ | ✅ | Connection listener |
| `removeConnectionStatusListener(listener)` | ✅ | ✅ | ✅ | ✅ | Remove connection listener |
| `isOffline()` | ✅ | ✅ | ❌ | ✅ | Check offline status |
| `setOffline()` | ✅ | ✅ | ❌ | ❌ | Set offline mode |
| `setOnline()` | ✅ | ✅ | ❌ | ❌ | Set online mode |
| `setOfflineMode(offline)` | ❌ | ❌ | ❌ | ✅ | Set offline mode bool |

### Configuration Management

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `forceRefresh()` | ❌ | ❌ | ❌ | ✅ | Force config refresh |
| `fetchConfigs()` | ❌ | ❌ | ✅ | ❌ | Manual config fetch |
| `getMutableConfig()` | ❌ | ❌ | ❌ | ✅ | Get mutable config |
| `awaitSdkSettingsCheck()` | ✅ | ❌ | ❌ | ✅ | Wait for SDK settings |

### Runtime Configuration Updates

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `updateSdkSettingsCheckInterval(ms)` | ✅ | ✅ | ❌ | ✅ | Update settings interval |
| `updateEventsFlushInterval(ms)` | ✅ | ✅ | ❌ | ✅ | Update events interval |
| `updateSummariesFlushInterval(ms)` | ❌ | ❌ | ❌ | ✅ | Update summaries interval |
| `updateNetworkConnectionTimeout(ms)` | ✅ | ✅ | ❌ | ✅ | Update connection timeout |
| `updateNetworkReadTimeout(ms)` | ✅ | ✅ | ❌ | ✅ | Update read timeout |
| `setDebugLoggingEnabled(enabled)` | ✅ | ✅ | ❌ | ✅ | Toggle debug logging |
| `setLoggingEnabled(enabled)` | ❌ | ❌ | ❌ | ✅ | Toggle logging |

### Environment & Device

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `enableAutoEnvAttributes()` | ✅ | ✅ | ❌ | ✅ | Enable auto env attributes |
| `disableAutoEnvAttributes()` | ❌ | ❌ | ❌ | ✅ | Disable auto env attributes |
| `getEnvironmentAttributes()` | ❌ | ❌ | ❌ | ✅ | Get env attributes |

### Lifecycle Management

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `pause()` | ❌ | ❌ | ❌ | ✅ | Pause SDK operations |
| `resume()` | ❌ | ❌ | ❌ | ✅ | Resume SDK operations |

### Metrics & Monitoring

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `getMetrics()` | ❌ | ❌ | ❌ | ✅ | Get performance metrics |

## Session Management APIs

### Core Session Operations

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `getCurrentSessionId()` | ✅ | ✅ | ✅ | ✅ | Get current session ID |
| `getCurrentSessionData()` | ✅ | ✅ | ✅ | ✅ | Get session metadata |
| `getCurrentSession()` | ❌ | ❌ | ❌ | ✅ | Alias for session data |
| `updateSessionActivity()` | ✅ | ✅ | ✅ | ✅ | Update activity timestamp |
| `forceSessionRotation()` | ✅ | ✅ | ✅ | ✅ | Manual rotation |
| `getSessionStatistics()` | ✅ | ✅ | ✅ | ✅ | Get session stats |

### Session Event Handling

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `onUserAuthenticationChange(userId)` | ✅ | ✅ | ✅ | ✅ | Handle auth changes |
| `onAppBackground()` | ✅ | ✅ | ✅ | ✅ | Handle background |
| `onAppForeground()` | ✅ | ✅ | ✅ | ✅ | Handle foreground |
| `onNetworkChange()` | ❌ | ❌ | ❌ | ✅ | Handle network change |

### Session Listeners

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `addSessionRotationListener(listener)` | ✅ | ✅ | ✅ | ✅ | Add rotation listener |
| `removeSessionRotationListener(listener)` | ✅ | ✅ | ✅ | ✅ | Remove rotation listener |

### SessionManager Singleton

| Function | Kotlin | Swift | Flutter | React Native | Notes |
|----------|--------|-------|---------|--------------|-------|
| `SessionManager.initialize(config)` | ✅ | ✅ | ✅ | ✅ | Initialize singleton |
| `SessionManager.getInstance()` | ✅ | ✅ | ✅ | ✅ | Get singleton |
| `SessionManager.shutdown()` | ✅ | ✅ | ✅ | ✅ | Shutdown singleton |

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