# CustomFit React Native SDK Documentation

[![Version](https://img.shields.io/badge/version-1.1.1-blue.svg)](https://github.com/customfit/react-native-sdk)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![React Native](https://img.shields.io/badge/react--native-0.70+-blue.svg)](https://reactnative.dev/)
[![TypeScript](https://img.shields.io/badge/typescript-4.9+-blue.svg)](https://www.typescriptlang.org/)

CustomFit React Native SDK enables seamless integration of real-time feature flags, user analytics, and personalization capabilities into your React Native applications. Built with performance, reliability, and developer experience in mind.

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
The SDK maintains persistent connections to receive instant flag updates, ensuring your application responds immediately to configuration changes without requiring app restarts.

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
- React Native 0.70 or higher
- TypeScript 4.9 or higher (recommended)
- iOS 12+ / Android API level 21+

### npm
```bash
npm install @customfit/react-native-sdk
```

### yarn
```bash
yarn add @customfit/react-native-sdk
```

### iOS Setup
Run pod install for iOS dependencies:
```bash
cd ios && pod install
```

### Android Setup
No additional setup required for Android.

## Quick Start

### 1. Initialize the SDK

```typescript
import { CFClient, CFConfig, CFUser } from '@customfit/react-native-sdk';

// Create configuration
const config = CFConfig.builder('your-client-key-here')
  .debugLoggingEnabled(true)
  .eventsFlushIntervalMs(5000)
  .build();

// Create user
const user = CFUser.builder('user123')
  .property('plan', 'premium')
  .property('age', 25)
  .anonymous(false)
  .build();

// Initialize client (async)
const initializeSDK = async () => {
  try {
    const client = await CFClient.initialize(config, user);
    console.log('CustomFit SDK initialized successfully!');
    return client;
  } catch (error) {
    console.error('Failed to initialize SDK:', error);
  }
};
```

### 2. Use Feature Flags

```typescript
// Get a boolean feature flag
const newUIEnabled = client.getBoolean('new_ui_enabled', false);

// Get a string configuration
const welcomeMessage = client.getString('welcome_message', 'Welcome!');

// Get a number value
const maxRetries = client.getNumber('max_retries', 3);

// Get JSON configuration
const themeConfig = client.getJson('theme_config', { color: 'blue' });
```

### 3. Track Events

```typescript
// Track a simple event
await client.trackEvent('button_clicked', { button_id: 'login' });

// Track with detailed properties
await client.trackEvent('purchase_completed', {
  product_id: 'prod_123',
  amount: 99.99,
  currency: 'USD',
  payment_method: 'credit_card'
});
```

## Configuration

The `CFConfig` class provides extensive customization options using the builder pattern:

```typescript
const config = CFConfig.builder('your-client-key')
  // Logging
  .debugLoggingEnabled(true)
  .loggingEnabled(true)
  .logLevel('DEBUG')
  
  // Event tracking
  .eventsQueueSize(100)
  .eventsFlushTimeSeconds(30)
  .eventsFlushIntervalMs(5000)
  
  // Summary tracking
  .summariesQueueSize(100)
  .summariesFlushTimeSeconds(5)
  .summariesFlushIntervalMs(5000)
  
  // Network settings
  .networkConnectionTimeoutMs(10000)
  .networkReadTimeoutMs(15000)
  
  // Background behavior
  .backgroundPollingIntervalMs(60000)
  .disableBackgroundPolling(false)
  
  // Retry configuration
  .maxRetryAttempts(3)
  .retryInitialDelayMs(1000)
  .retryMaxDelayMs(30000)
  .retryBackoffMultiplier(2.0)
  
  // Offline support
  .offlineMode(false)
  
  // Auto environment detection
  .autoEnvAttributesEnabled(true)
  
  .build();
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `debugLoggingEnabled` | Enable detailed debug logging | `false` |
| `eventsQueueSize` | Maximum events in memory queue | `100` |
| `eventsFlushIntervalMs` | Automatic event flush interval | `30000` |
| `summariesFlushIntervalMs` | Summary data flush interval | `5000` |
| `networkConnectionTimeoutMs` | Network connection timeout | `10000` |
| `backgroundPollingIntervalMs` | Config polling when app in background | `300000` |
| `maxRetryAttempts` | Maximum retry attempts for failed requests | `3` |
| `offlineMode` | Start in offline mode | `false` |
| `autoEnvAttributesEnabled` | Auto-detect device/app context | `false` |

## User Management

### Creating Users

```typescript
// Identified user with properties
const user = CFUser.builder('user123')
  .property('email', 'user@example.com')
  .property('plan', 'premium')
  .property('age', 28)
  .property('beta_tester', true)
  .property('signup_date', new Date())
  .property('preferences', {
    theme: 'dark',
    notifications: true
  })
  .anonymous(false)
  .build();

// Anonymous user
const anonymousUser = CFUser.builder(`anonymous_${Date.now()}`)
  .anonymousId(`anon-${Date.now()}`)
  .property('source', 'mobile_app')
  .anonymous(true)
  .build();
```

### Updating User Properties

```typescript
// Add single property
client.addUserProperty('subscription_tier', 'pro');
client.addUserProperty('login_count', 15);
client.addUserProperty('verified_email', true);

// Add multiple properties
client.addUserProperties({
  last_activity: new Date(),
  device_type: 'mobile',
  app_version: '2.1.0'
});
```

### User Contexts

```typescript
import { EvaluationContext, ContextType } from '@customfit/react-native-sdk';

// Add evaluation contexts for targeting
const locationContext: EvaluationContext = {
  type: ContextType.LOCATION,
  key: 'current_location',
  properties: {
    country: 'US',
    state: 'CA',
    city: 'San Francisco'
  }
};

const deviceContext: EvaluationContext = {
  type: ContextType.DEVICE,
  key: 'device_info',
  properties: {
    platform: 'ios',
    version: '16.0',
    model: 'iPhone 14'
  }
};

// Add contexts to user
const userWithContext = user
  .withContext(locationContext)
  .withContext(deviceContext);
```

## Feature Flags

### Basic Flag Retrieval

```typescript
// Boolean flags
const isNewFeatureEnabled = client.getBoolean('new_feature', false);
const showBetaFeatures = client.getBoolean('beta_features', false);

// String flags
const apiEndpoint = client.getString('api_endpoint', 'https://api.example.com');
const welcomeMessage = client.getString('welcome_text', 'Welcome!');

// Number flags
const maxFileSize = client.getNumber('max_file_size_mb', 10);
const retryAttempts = client.getNumber('retry_attempts', 3);

// JSON flags
const featureConfig = client.getJson('feature_config', {
  enabled: true,
  max_users: 100
});
```

### Flag Callbacks

```typescript
// Get value with callback
const theme = client.getString('app_theme', 'light', (value) => {
  console.log('Current theme:', value);
  applyTheme(value);
});

const maxRetries = client.getNumber('max_retries', 3, (value) => {
  updateRetryPolicy(value);
});
```

### Get All Flags

```typescript
const allFlags = client.getAllFlags();
console.log('Current flags:', allFlags);
```

## Event Tracking

### Simple Event Tracking

```typescript
// Basic event
await client.trackEvent('user_login');

// Event with properties
await client.trackEvent('purchase_completed', {
  product_id: 'prod_123',
  amount: 99.99,
  currency: 'USD',
  payment_method: 'credit_card'
});
```

### Event Result Handling

```typescript
import { CFResult } from '@customfit/react-native-sdk';

const result = await client.trackEvent('user_action', { action: 'click' });

if (result.isSuccess) {
  console.log('Event tracked successfully:', result.data);
} else {
  console.error('Failed to track event:', result.error?.message);
}
```

### React Hooks Integration

```typescript
import React, { useEffect } from 'react';

const MyComponent: React.FC = () => {
  useEffect(() => {
    // Track screen view
    client.trackEvent('screen_viewed', {
      screen_name: 'MyComponent',
      timestamp: new Date().toISOString()
    });
  }, []);

  const handleButtonPress = async () => {
    await client.trackEvent('button_pressed', {
      button_id: 'submit',
      screen: 'MyComponent'
    });
  };

  return (
    // Your component JSX
  );
};
```

## Session Management

The SDK automatically manages user sessions with configurable rotation policies.

### Getting Session Information

```typescript
// Get current session ID
const sessionId = await client.getCurrentSessionId();

// Get detailed session data
const sessionData = await client.getCurrentSessionData();
if (sessionData) {
  console.log('Session:', sessionData.sessionId);
  console.log('Started:', sessionData.startTime);
  console.log('Last activity:', sessionData.lastActivityTime);
}

// Get session statistics
const stats = await client.getSessionStatistics();
console.log('Session stats:', stats);
```

### Manual Session Control

```typescript
// Force session rotation
const newSessionId = await client.forceSessionRotation();
console.log('New session:', newSessionId);

// Update activity (call on user interactions)
await client.updateSessionActivity();

// Handle authentication changes
await client.onUserAuthenticationChange('new_user_id');
```

### Session Listeners

```typescript
import { SessionRotationListener, RotationReason } from '@customfit/react-native-sdk';

const sessionListener: SessionRotationListener = {
  onSessionRotated: (oldSessionId, newSessionId, reason) => {
    console.log(`Session rotated: ${oldSessionId} -> ${newSessionId} (${reason.description})`);
    // Update analytics, clear caches, etc.
  },
  
  onSessionRestored: (sessionId) => {
    console.log('Session restored:', sessionId);
  },
  
  onSessionError: (error) => {
    console.error('Session error:', error);
  }
};

client.addSessionRotationListener(sessionListener);
```

## Listeners & Callbacks

### Feature Flag Change Listeners

```typescript
import { FeatureFlagChangeListener } from '@customfit/react-native-sdk';

// Listen to specific flag changes
const flagListener: FeatureFlagChangeListener<boolean> = (oldValue, newValue) => {
  console.log('Feature flag changed:', oldValue, '->', newValue);
  handleFeatureChange(newValue);
};

client.addFeatureFlagListener('my_feature', flagListener);

// Type-safe listeners
client.addConfigListener<boolean>('dark_mode', (isEnabled) => {
  updateUITheme(isEnabled);
});

client.addConfigListener<string>('api_url', (url) => {
  updateApiEndpoint(url);
});
```

### All Flags Listener

```typescript
import { AllFlagsListener } from '@customfit/react-native-sdk';

const allFlagsListener: AllFlagsListener = (flags) => {
  console.log('Flags updated:', Object.keys(flags).length, 'flags');
  Object.entries(flags).forEach(([key, value]) => {
    console.log(`  ${key} = ${value}`);
  });
};

client.addAllFlagsListener(allFlagsListener);
```

### Connection Status Listeners

```typescript
import { ConnectionStatusListener, ConnectionStatus } from '@customfit/react-native-sdk';

const connectionListener: ConnectionStatusListener = {
  onConnectionStatusChanged: (status) => {
    switch (status) {
      case ConnectionStatus.CONNECTED:
        console.log('Connected to CustomFit');
        break;
      case ConnectionStatus.DISCONNECTED:
        console.log('Disconnected from CustomFit');
        break;
      case ConnectionStatus.CONNECTING:
        console.log('Connecting...');
        break;
      case ConnectionStatus.ERROR:
        console.log('Connection error');
        break;
    }
  }
};

client.addConnectionStatusListener(connectionListener);

// Get current connection info
const connectionInfo = client.getConnectionInformation();
console.log('Connection:', connectionInfo.status, 'Type:', connectionInfo.networkType);
```

## Offline Support

The SDK provides robust offline capabilities with automatic synchronization when connectivity is restored.

### Offline Mode Control

```typescript
// Check if offline
const isOffline = client.isOffline();

// Enable offline mode
client.setOfflineMode(true);

// Restore online mode
client.setOfflineMode(false);
```

### Offline Configuration

```typescript
const config = CFConfig.builder('your-client-key')
  .offlineMode(true)  // Start in offline mode
  .build();
```

### Offline Behavior

- **Feature flags**: Return cached values or defaults
- **Events**: Queued locally and sent when online
- **Configuration updates**: Resume when connectivity restored
- **Automatic synchronization**: Seamless transition between offline/online

## Advanced Features

### Force Configuration Refresh

```typescript
// Force refresh from server (ignores cache)
const result = await client.forceRefresh();
if (result.isSuccess) {
  console.log('Configuration refreshed successfully');
} else {
  console.error('Failed to refresh:', result.error?.message);
}
```

### Runtime Configuration Updates

```typescript
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

### React Native Specific Features

```typescript
import { AppState, NetInfo } from 'react-native';

// Automatic app state handling
AppState.addEventListener('change', (nextAppState) => {
  if (nextAppState === 'active') {
    client.onAppForeground();
  } else if (nextAppState === 'background') {
    client.onAppBackground();
  }
});

// Network connectivity handling
const unsubscribe = NetInfo.addEventListener((state) => {
  if (state.isConnected) {
    client.setOfflineMode(false);
  } else {
    client.setOfflineMode(true);
  }
});
```

### Circuit Breaker Reset

```typescript
// Reset circuit breakers for network operations
client.resetCircuitBreakers();
```

## Error Handling

The SDK uses `CFResult<T>` for standardized error handling:

```typescript
import { CFResult } from '@customfit/react-native-sdk';

// Pattern 1: Direct checking
const result = await client.trackEvent('user_action');
if (result.isSuccess) {
  console.log('Success:', result.data);
} else {
  console.error('Error:', result.error?.message);
  result.error?.exception && console.error(result.error.exception);
}

// Pattern 2: Functional style
result
  .onSuccess((data) => {
    console.log('Event tracked:', data.eventId);
  })
  .onError((error) => {
    console.error('Failed:', error.message);
    handleError(error);
  });

// Pattern 3: Extract values
const eventData = result.getOrNull();
const eventOrDefault = result.getOrDefault(defaultEventData);
const eventOrElse = result.getOrElse((error) => {
  logError(error);
  return createFallbackEvent();
});
```

### Error Categories

```typescript
import { ErrorCategory } from '@customfit/react-native-sdk';

// Error categories for different handling strategies
switch (error.category) {
  case ErrorCategory.NETWORK:
    // Network issues - retry logic
    scheduleRetry();
    break;
  case ErrorCategory.VALIDATION:
    // Invalid input - fix and retry
    fixInputAndRetry();
    break;
  case ErrorCategory.AUTHENTICATION:
    // Auth issues - refresh token
    refreshAuthToken();
    break;
  case ErrorCategory.INTERNAL:
    // SDK issues - report bug
    reportIssue(error);
    break;
}
```

## Best Practices

### 1. Initialization

```typescript
// ✅ Good: Initialize once, use globally
class SDKManager {
  private static instance: CFClient | null = null;
  
  static async initialize(config: CFConfig, user: CFUser): Promise<CFClient> {
    if (!this.instance) {
      this.instance = await CFClient.initialize(config, user);
    }
    return this.instance;
  }
  
  static getInstance(): CFClient {
    if (!this.instance) {
      throw new Error('SDK not initialized');
    }
    return this.instance;
  }
}

// Usage
const client = await SDKManager.initialize(config, user);
```

### 2. React Hook Integration

```typescript
import React, { createContext, useContext, useEffect, useState } from 'react';

const CustomFitContext = createContext<CFClient | null>(null);

export const CustomFitProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [client, setClient] = useState<CFClient | null>(null);
  
  useEffect(() => {
    const initSDK = async () => {
      const cfClient = await CFClient.initialize(config, user);
      setClient(cfClient);
    };
    
    initSDK();
  }, []);
  
  return (
    <CustomFitContext.Provider value={client}>
      {children}
    </CustomFitContext.Provider>
  );
};

export const useCustomFit = () => {
  const client = useContext(CustomFitContext);
  if (!client) {
    throw new Error('useCustomFit must be used within CustomFitProvider');
  }
  return client;
};
```

### 3. Feature Flag Hooks

```typescript
import { useState, useEffect } from 'react';

export const useFeatureFlag = <T>(flagKey: string, defaultValue: T): T => {
  const client = useCustomFit();
  const [value, setValue] = useState<T>(defaultValue);
  
  useEffect(() => {
    // Get initial value
    const initialValue = client.getFeatureFlag(flagKey, defaultValue);
    setValue(initialValue);
    
    // Listen for changes
    const listener = (newValue: T) => setValue(newValue);
    client.addConfigListener(flagKey, listener);
    
    return () => {
      client.removeConfigListener(flagKey, listener);
    };
  }, [client, flagKey, defaultValue]);
  
  return value;
};

// Usage in components
const MyComponent: React.FC = () => {
  const isFeatureEnabled = useFeatureFlag('new_feature', false);
  const welcomeMessage = useFeatureFlag('welcome_message', 'Welcome!');
  
  return (
    <View>
      {isFeatureEnabled && <NewFeature />}
      <Text>{welcomeMessage}</Text>
    </View>
  );
};
```

### 4. Event Tracking

```typescript
// ✅ Good: Use meaningful event names and properties
await client.trackEvent('purchase_completed', {
  product_category: 'electronics',
  revenue: 99.99,
  payment_method: 'credit_card',
  first_purchase: true
});

// ❌ Avoid: Generic events without context
await client.trackEvent('click', { type: 'button' });
```

### 5. Resource Management

```typescript
// ✅ Good: Cleanup on app shutdown
const App: React.FC = () => {
  useEffect(() => {
    return () => {
      // Cleanup when app unmounts
      CFClient.shutdown();
    };
  }, []);
  
  return <YourApp />;
};
```

## API Reference

### CFClient

#### Initialization
- `static async initialize(config: CFConfig, user: CFUser): Promise<CFClient>`
- `static shutdown(): void`

#### Feature Flags
- `getFeatureFlag<T>(key: string, defaultValue: T): T`
- `getString(key: string, fallbackValue: string, callback?: (value: string) => void): string`
- `getNumber(key: string, fallbackValue: number, callback?: (value: number) => void): number`
- `getBoolean(key: string, fallbackValue: boolean, callback?: (value: boolean) => void): boolean`
- `getJson(key: string, fallbackValue: Record<string, any>, callback?: (value: Record<string, any>) => void): Record<string, any>`
- `getAllFlags(): Record<string, any>`

#### Event Tracking
- `trackEvent(eventName: string, properties?: Record<string, any>): Promise<CFResult<EventData>>`

#### User Management
- `addUserProperty(key: string, value: any): void`
- `addUserProperties(properties: Record<string, any>): void`

#### Session Management
- `getCurrentSessionId(): Promise<string>`
- `getCurrentSessionData(): Promise<SessionData | null>`
- `forceSessionRotation(): Promise<string | null>`
- `updateSessionActivity(): Promise<void>`

#### Listeners
- `addConfigListener<T>(key: string, listener: (value: T) => void): void`
- `removeConfigListener<T>(key: string, listener: (value: T) => void): void`
- `addFeatureFlagListener<T>(flagKey: string, listener: FeatureFlagChangeListener<T>): void`
- `addAllFlagsListener(listener: AllFlagsListener): void`
- `addConnectionStatusListener(listener: ConnectionStatusListener): void`

#### Offline Support
- `isOffline(): boolean`
- `setOfflineMode(offline: boolean): void`

#### Configuration Updates
- `forceRefresh(): Promise<CFResult<boolean>>`
- `resetCircuitBreakers(): void`

### CFConfig.Builder

Configuration builder methods for customizing SDK behavior.

### CFUser.Builder

User builder methods for setting user properties and contexts.

## Troubleshooting

### Common Issues

#### 1. Initialization Failures

```typescript
// Problem: Client not initializing
// Solution: Check client key format and network connectivity
try {
  const client = await CFClient.initialize(config, user);
  console.log('SDK initialized successfully');
} catch (error) {
  console.error('Init failed:', error.message);
  // Check client key, network, etc.
}
```

#### 2. Feature Flags Not Updating

```typescript
// Problem: Flags returning default values
// Solution: Verify initialization and check logs
const result = await client.forceRefresh();
if (!result.isSuccess) {
  console.error('Failed to refresh:', result.error?.message);
}

// Check if offline
if (client.isOffline()) {
  client.setOfflineMode(false);
}
```

#### 3. Events Not Being Sent

```typescript
// Problem: Events stuck in queue
// Solution: Check network and force flush
const result = await client.trackEvent('test_event');
if (!result.isSuccess) {
  console.error('Event error:', result.error?.message);
  // Check network connectivity
  if (!client.isOffline()) {
    // Events will be sent when connectivity is restored
  }
}
```

### Metro Bundler Issues

If you encounter bundling issues with React Native:

```javascript
// metro.config.js
module.exports = {
  resolver: {
    assetExts: ['bin', 'txt', 'jpg', 'png', 'json'],
    sourceExts: ['js', 'json', 'ts', 'tsx'],
  },
  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: true,
      },
    }),
  },
};
```

### Debug Logging

Enable debug logging to troubleshoot issues:

```typescript
const config = CFConfig.builder('your-client-key')
  .debugLoggingEnabled(true)
  .loggingEnabled(true)
  .logLevel('DEBUG')
  .build();
```

### Performance Monitoring

```typescript
// Monitor session statistics
const stats = await client.getSessionStatistics();
console.log('Session stats:', stats);

// Monitor connection status
const connectionInfo = client.getConnectionInformation();
console.log('Connection:', connectionInfo.status);

// Monitor memory usage
console.log('All flags count:', Object.keys(client.getAllFlags()).length);
```

---

## Support

For technical support, documentation updates, or feature requests:

- **Documentation**: [https://docs.customfit.ai](https://docs.customfit.ai)
- **GitHub Issues**: [https://github.com/customfit/react-native-sdk/issues](https://github.com/customfit/react-native-sdk/issues)
- **Support Email**: support@customfit.ai

## License

This SDK is released under the MIT License. See [LICENSE](LICENSE) file for details.

---

*This documentation is for CustomFit React Native SDK v1.1.1. For the latest updates, visit our [documentation site](https://docs.customfit.ai).* 