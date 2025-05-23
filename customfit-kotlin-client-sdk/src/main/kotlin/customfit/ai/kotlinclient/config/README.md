# Configuration Package

This package contains all configuration-related components for the CustomFit Kotlin Client SDK.

## Package Structure

- `/config/core/` - Core configuration classes
  - `CFConfig.kt` - Data class representing immutable configuration
  - `MutableCFConfig.kt` - Wrapper for dynamic configuration updates

- `/config/change/` - Configuration change management
  - `CFConfigChangeManager.kt` - Observer pattern for config changes

## Usage

### Core Configuration

Use `CFConfig` for initializing the SDK with specific configuration values:

```kotlin
val config = CFConfig.Builder(clientKey)
    .debugLoggingEnabled(true)
    .eventsFlushIntervalMs(5000L)
    .build()
```

### Mutable Configuration

Use `MutableCFConfig` for making runtime changes to configuration:

```kotlin
mutableConfig.setOfflineMode(true)
mutableConfig.setDebugLoggingEnabled(false)
```

### Change Management

Use `CFConfigChangeManager` to observe configuration changes:

```kotlin
CFConfigChangeManager.registerConfigChange("feature_flag_key", observer)
```

## Migration Notes

This package structure was created to improve organization by consolidating all config-related code under a unified package. 