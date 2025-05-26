# CustomFit React Native SDK

A comprehensive React Native SDK for feature flags, A/B testing, and analytics that matches the functionality of Kotlin and Swift SDKs.

## Features

✅ **Feature Flags** - Get feature flags with fallback values  
✅ **A/B Testing** - Run experiments and track results  
✅ **Analytics** - Track events and user behavior  
✅ **Real-time Config** - Fetch configurations with caching  
✅ **Offline Support** - Work seamlessly offline  
✅ **Battery Optimization** - Reduce polling when battery is low  
✅ **TypeScript Support** - Full TypeScript definitions  
✅ **React Hooks** - Easy React integration (coming soon)  

## Installation

```bash
npm install @customfit/react-native-sdk
# or
yarn add @customfit/react-native-sdk
```

### Dependencies

The SDK requires these peer dependencies:

```bash
npm install @react-native-async-storage/async-storage @react-native-community/netinfo
```

## Quick Start

```typescript
import { CFClient, CFConfig, CFUser } from '@customfit/react-native-sdk';

// 1. Create configuration
const config = CFConfig.builder('your-client-key')
  .debugLoggingEnabled(true)
  .offlineMode(false)
  .summariesFlushIntervalMs(3000) // 3 seconds
  .build();

// 2. Create user
const user = CFUser.builder('user-123')
  .anonymousId('anon-456')
  .property('plan', 'premium')
  .build();

// 3. Initialize client
const client = CFClient.init(config, user);

// 4. Get feature flags
const heroText = client.getFeatureFlag('hero_text', 'default-text');
const isPremiumEnabled = client.getFeatureFlag('premium_features', false);

// 5. Track events
client.trackEvent('button_click', { button: 'hero_cta' });
```

## Configuration

The SDK supports extensive configuration options matching Kotlin and Swift SDKs:

```typescript
const config = CFConfig.builder('your-client-key')
  // Event tracking
  .eventsQueueSize(100)
  .eventsFlushIntervalMs(1000)
  .maxStoredEvents(100)
  
  // Summary tracking
  .summariesQueueSize(100)
  .summariesFlushIntervalMs(60000)
  
  // Network settings
  .networkConnectionTimeoutMs(10000)
  .maxRetryAttempts(3)
  .retryBackoffMultiplier(2.0)
  
  // Background behavior
  .disableBackgroundPolling(false)
  .useReducedPollingWhenBatteryLow(true)
  .reducedPollingIntervalMs(7200000) // 2 hours
  
  // Logging
  .loggingEnabled(true)
  .debugLoggingEnabled(__DEV__)
  .logLevel('DEBUG')
  
  // Offline mode
  .offlineMode(false)
  
  .build();
```

## User Management

```typescript
// Create user with builder pattern
const user = CFUser.builder('customer-123')
  .anonymousId('anon-456')
  .deviceId('device-789')
  .anonymous(false)
  .properties({
    plan: 'premium',
    region: 'us-east',
    signup_date: '2023-01-01'
  })
  .property('last_login', new Date().toISOString())
  .build();

// Update user attributes
client.setUserAttribute('plan', 'enterprise');
client.setUserAttributes({ region: 'eu-west', plan: 'enterprise' });
```

## Feature Flags

```typescript
// Get feature flags with type safety
const heroText: string = client.getFeatureFlag('hero_text', 'Welcome!');
const maxItems: number = client.getFeatureFlag('max_items', 10);
const isPremium: boolean = client.getFeatureFlag('premium_enabled', false);

// Get all feature flags
const allFlags = client.getAllFeatures();
console.log(allFlags); // { hero_text: "Welcome!", max_items: 10, premium_enabled: true }
```

## Event Tracking

```typescript
// Track simple events
client.trackEvent('page_view');

// Track events with properties
client.trackEvent('purchase', {
  item_id: 'product-123',
  price: 29.99,
  currency: 'USD',
  category: 'electronics'
});

// Track screen views
client.trackScreenView('home_screen');

// Track feature usage
client.trackFeatureUsage('premium_feature');
```

## Listeners

```typescript
// Listen to feature flag changes
client.addFeatureFlagListener('hero_text', (newValue, oldValue) => {
  console.log(`Hero text changed from ${oldValue} to ${newValue}`);
});

// Listen to all flag changes
client.addAllFlagsListener((flags) => {
  console.log('All flags updated:', flags);
});

// Listen to connection status
client.addConnectionStatusListener((status) => {
  console.log('Connection status:', status);
});
```

## React Hooks (Coming Soon)

```typescript
import { useFeatureFlag, useFeatureValue, useCustomFit } from '@customfit/react-native-sdk';

function MyComponent() {
  // Hook for feature flags
  const isPremiumEnabled = useFeatureFlag('premium_enabled', false);
  const heroText = useFeatureValue('hero_text', 'Welcome!');
  
  // Hook for SDK status
  const { isInitialized, isOffline } = useCustomFit();
  
  return (
    <View>
      <Text>{heroText}</Text>
      {isPremiumEnabled && <PremiumFeature />}
      {isOffline && <OfflineIndicator />}
    </View>
  );
}
```

## Advanced Usage

### Offline Mode

```typescript
// Enable offline mode
const config = CFConfig.builder('key')
  .offlineMode(true)
  .build();

// Check offline status
if (client.isOffline()) {
  console.log('SDK is in offline mode');
}

// Toggle offline mode
client.setOfflineMode(false);
```

### Manual Cache Control

```typescript
// Force refresh configuration
await client.forceRefresh();

// Flush events manually
const result = client.flushEvents();
if (result.isSuccess) {
  console.log(`Flushed ${result.data} events`);
}

// Flush summaries manually
const summaryResult = client.flushSummaries();
```

### Performance Monitoring

```typescript
// Get performance metrics
const metrics = client.getMetrics();
console.log({
  totalEvents: metrics.totalEvents,
  totalSummaries: metrics.totalSummaries,
  averageResponseTime: metrics.averageResponseTime,
  failureRate: metrics.failureRate
});
```

## Architecture

The React Native SDK follows the same architecture as Kotlin and Swift SDKs:

```
src/
├── analytics/          # Event and summary tracking
│   ├── event/
│   └── summary/
├── client/             # Main client and managers
│   ├── listener/
│   └── managers/
├── config/             # Configuration management
│   ├── change/
│   └── core/
├── constants/          # SDK constants
├── core/               # Core utilities and models
│   ├── error/
│   ├── model/
│   ├── types/
│   └── util/
├── logging/            # Logging system
├── network/            # HTTP client and fetchers
│   └── connection/
├── platform/           # Platform-specific code
├── utils/              # Utility functions
└── hooks/              # React hooks (coming soon)
```

## Error Handling

```typescript
import { CFResult, ErrorCategory } from '@customfit/react-native-sdk';

// All SDK operations return CFResult
const result = client.flushEvents();
if (result.isSuccess) {
  console.log('Success:', result.data);
} else {
  console.error('Error:', result.error?.message);
  console.error('Category:', result.error?.category);
}
```

## Logging

The SDK includes comprehensive logging with the same prefix system as other SDKs:

```
[HH:mm:ss.SSS] Customfit.ai-SDK [React Native] [INFO] SDK initialized successfully
[HH:mm:ss.SSS] 📡 Customfit.ai-SDK [React Native] [INFO] API POLL: Fetching config...
[HH:mm:ss.SSS] 📊 Customfit.ai-SDK [React Native] [DEBUG] SUMMARY: Periodic flush triggered
[HH:mm:ss.SSS] 🔔 Customfit.ai-SDK [React Native] [INFO] TRACK: Event tracked successfully
[HH:mm:ss.SSS] 🔧 Customfit.ai-SDK [React Native] [INFO] CONFIG UPDATE: hero_text: "New Value"
```

## TypeScript Support

The SDK is built with TypeScript and provides comprehensive type definitions:

```typescript
import type { 
  CFConfig, 
  CFUser, 
  CFResult, 
  EventData, 
  SummaryData,
  ConnectionStatus,
  LogLevel 
} from '@customfit/react-native-sdk';
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📧 Email: support@customfit.ai
- 📖 Documentation: https://docs.customfit.ai
- 🐛 Issues: https://github.com/customfit/react-native-sdk/issues 

## API Endpoints & Configuration

### Core API Endpoints

The SDK uses the following API endpoints:

- **Base URL**: `https://api.customfit.ai`
- **User Configs**: `POST /v1/users/configs?cfenc={clientKey}`
- **Events**: `POST /v1/cfe?cfenc={clientKey}`
- **Summaries**: `POST /v1/summaries?cfenc={clientKey}`

### Important Notes

⚠️ **API Method**: The user configs endpoint uses `POST` method with user data as payload, not `GET` with Bearer token authorization.

✅ **Correct Implementation**: 
```typescript
// POST /v1/users/configs?cfenc={clientKey}
// Body: { user: userData }
```

❌ **Incorrect Implementation**:
```typescript
// GET /users/configs
// Headers: { Authorization: "Bearer {token}" }
```

### Cross-Platform Consistency

All SDKs (Kotlin, Flutter, Swift, React Native) use the same API endpoints and methods for consistency. If you experience issues:

1. Verify the API endpoint configuration
2. Check that POST method is used for user configs
3. Ensure client key is passed as query parameter (`cfenc`)
4. Confirm user data is sent in request body

## Web Platform Support

### React Native Web Integration

The SDK supports React Native Web with additional configuration:

#### Webpack Configuration

```javascript
// webpack.config.js
const path = require('path');

module.exports = {
  // ... existing config
  resolve: {
    alias: {
      'react-native$': 'react-native-web',
      '@react-native-async-storage/async-storage': 
        path.resolve(__dirname, 'src/polyfills/AsyncStoragePolyfill.js'),
      '@react-native-community/netinfo': 
        path.resolve(__dirname, 'src/polyfills/NetInfoPolyfill.js'),
    },
    extensions: ['.web.js', '.js', '.json', '.web.jsx', '.jsx'],
  },
  // CORS proxy for development
  devServer: {
    proxy: {
      '/v1': {
        target: 'https://api.customfit.ai',
        changeOrigin: true,
        secure: true,
      },
    },
  },
};
```

#### Required Polyfills

Create polyfills for React Native modules:

**AsyncStorage Polyfill**:
```typescript
// src/polyfills/AsyncStoragePolyfill.js
export default {
  getItem: (key) => Promise.resolve(localStorage.getItem(key)),
  setItem: (key, value) => Promise.resolve(localStorage.setItem(key, value)),
  removeItem: (key) => Promise.resolve(localStorage.removeItem(key)),
  clear: () => Promise.resolve(localStorage.clear()),
};
```

**NetInfo Polyfill**:
```typescript
// src/polyfills/NetInfoPolyfill.js
export default {
  fetch: () => Promise.resolve({
    isConnected: navigator.onLine,
    type: navigator.onLine ? 'wifi' : 'none',
  }),
  addEventListener: (listener) => {
    window.addEventListener('online', () => listener({ isConnected: true }));
    window.addEventListener('offline', () => listener({ isConnected: false }));
  },
};
```

### CORS Considerations

When running in web browsers, you may encounter CORS issues. Solutions:

1. **Development**: Use webpack proxy (shown above)
2. **Production**: Ensure your server has proper CORS headers
3. **Troubleshooting**: Check browser console for CORS errors

## Troubleshooting

### Common Issues

#### API Connection Problems

**Symptoms**: 
- Feature flags not updating
- Connection timeouts
- Circuit breaker in OPEN state

**Solutions**:
1. Verify API endpoint configuration
2. Check internet connectivity
3. Ensure correct client key format
4. Review API method usage (POST vs GET)

#### Web Platform Issues

**Symptoms**:
- Module resolution errors
- AsyncStorage/NetInfo undefined
- Webpack build failures

**Solutions**:
1. Add required polyfills
2. Configure webpack aliases
3. Check React Native Web compatibility

#### Circuit Breaker Issues

**Symptoms**:
- Persistent offline state
- Failed API calls not recovering

**Solutions**:
```typescript
// Force refresh after fixing configuration
await client.forceRefresh();

// Check connection status
const connectionInfo = client.getConnectionInformation();
console.log('Connection status:', connectionInfo);
```

### Debug Mode

Enable debug logging for detailed troubleshooting:

```typescript
const config = CFConfig.builder('your-client-key')
  .debugLoggingEnabled(true)
  .logLevel('DEBUG')
  .build();
```

Debug logs include:
- API request/response details
- Circuit breaker state changes
- Configuration updates
- Network connectivity status