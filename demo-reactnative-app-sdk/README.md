# CustomFit React Native SDK Demo App

A comprehensive demo React Native application that **replicates the Flutter demo app functionality** and showcases the CustomFit React Native Client SDK features.

## Overview

This demo app is designed to match the Flutter demo app exactly, demonstrating:

- **🏗️ Provider Pattern** - React Context for state management (equivalent to Flutter's ChangeNotifierProvider)
- **🧭 Multi-Screen Navigation** - React Navigation with HomeScreen and SecondScreen
- **🎯 Real-time Feature Flag Updates** - Live listeners that update the UI when flags change
- **📊 Event Tracking** - Specific event names with platform prefixes (`reactnative_*`)
- **🌐 Offline Mode Toggle** - Connection management with visual indicators
- **🔄 Configuration Refresh** - Manual config refresh with loading states
- **⚡ Mock SDK Integration** - Simulates real SDK behavior (due to compilation issues)

## Features Matching Flutter App

### 🎯 **Feature Flags**
- `hero_text` - Dynamic title text that updates in real-time
- `enhanced_toast` - Boolean flag that changes toast behavior

### 📱 **Screens**
- **HomeScreen** - Main screen with SDK controls and feature demonstrations
- **SecondScreen** - Secondary screen for navigation testing

### 🔄 **Real-time Updates**
- Feature flag listeners that trigger UI updates
- Configuration change notifications (Alert dialogs)
- Automatic refresh with visual feedback

### 📊 **Event Tracking**
- `reactnative_toast_button_interaction` - Toast button clicks
- `reactnative_screen_navigation` - Screen navigation events  
- `reactnative_config_manual_refresh` - Manual config refresh events

## Prerequisites

- **React Native CLI** 0.73.0 or higher
- **Node.js** 18.0 or higher
- **npm** or **yarn** package manager
- **Android Studio** (for Android development)
- **Xcode** (for iOS development)
- **iOS Simulator** or **Android Emulator**

## Getting Started

### 1. Install Dependencies

```bash
# Install React Native dependencies
npm install

# For iOS (macOS only)
cd ios && pod install && cd ..
```

### 2. Start Metro Bundler

```bash
npm start
```

### 3. Run the App

#### Android
```bash
# Make sure you have an Android emulator running or device connected
npm run android
```

#### iOS (macOS only)
```bash
# Make sure you have iOS Simulator running
npm run ios
```

## App Architecture

### 📁 **Project Structure**
```
demo-reactnative-app-sdk/
├── App.tsx                           # Main app with navigation setup
├── src/
│   ├── providers/
│   │   └── CustomFitProvider.tsx     # Context provider (like Flutter's ChangeNotifierProvider)
│   └── screens/
│       ├── HomeScreen.tsx            # Main screen (matches Flutter HomeScreen)
│       └── SecondScreen.tsx          # Second screen (matches Flutter SecondScreen)
├── package.json                      # Dependencies and scripts
└── README.md                         # This file
```

### 🏗️ **Provider Pattern**
The `CustomFitProvider` uses React Context to manage global state, similar to Flutter's `ChangeNotifierProvider`:

```typescript
// Provider setup (equivalent to Flutter's ChangeNotifierProvider)
<CustomFitProvider>
  <NavigationContainer>
    <Stack.Navigator>
      <Stack.Screen name="HomeScreen" component={HomeScreen} />
      <Stack.Screen name="SecondScreen" component={SecondScreen} />
    </Stack.Navigator>
  </NavigationContainer>
</CustomFitProvider>

// Using the provider (equivalent to Flutter's Consumer)
const customFit = useCustomFit();
```

### 🎯 **Feature Flag Integration**

```typescript
// Real-time feature flag updates
const customFit = useCustomFit();

// Display dynamic title from feature flag
<Text>{customFit.heroText}</Text>

// Use enhanced toast behavior
const message = customFit.enhancedToast 
  ? 'Enhanced toast feature enabled!' 
  : 'Button clicked!';
```

### 📊 **Event Tracking**

```typescript
// Track events with React Native prefix
await customFit.trackEvent('reactnative_toast_button_interaction', {
  action: 'click',
  feature: 'toast_message',
  platform: 'react_native'
});
```

### 🔄 **Configuration Management**

```typescript
// Manual configuration refresh
const success = await customFit.refreshFeatureFlags('reactnative_config_manual_refresh');

// Real-time config change notifications
useEffect(() => {
  if (customFit.hasNewConfigMessage) {
    Alert.alert('Configuration Updated', customFit.lastConfigChangeMessage);
  }
}, [customFit.hasNewConfigMessage]);
```

## Comparison with Flutter App

| Feature | Flutter Implementation | React Native Implementation |
|---------|----------------------|---------------------------|
| **State Management** | `ChangeNotifierProvider` | React Context (`CustomFitProvider`) |
| **Navigation** | `Navigator.push()` | React Navigation (`navigation.navigate()`) |
| **Notifications** | `SnackBar` | `Alert.alert()` |
| **Loading States** | `CircularProgressIndicator` | `ActivityIndicator` |
| **Event Tracking** | `flutter_*` prefix | `reactnative_*` prefix |
| **Feature Flags** | Real SDK integration | Mock SDK (due to compilation issues) |

## Mock SDK Implementation

Due to TypeScript compilation issues in the React Native SDK, this demo uses a mock implementation that simulates the real SDK behavior:

```typescript
// Mock SDK that simulates real behavior
const mockClient = {
  getString: (key: string, defaultValue: string) => { /* ... */ },
  getBoolean: (key: string, defaultValue: boolean) => { /* ... */ },
  addConfigListener: (key: string, callback: Function) => { /* ... */ },
  fetchConfigs: () => Promise<boolean> => { /* ... */ },
  // ... other methods
};
```

### 🔄 **Real SDK Integration**
To use the actual SDK (once compilation issues are fixed):

1. **Install the SDK**:
   ```bash
   npm install customfit-reactnative-client-sdk
   ```

2. **Replace mock imports**:
   ```typescript
   // Replace mock SDK with real imports
   import { CFClient, CFConfig, CFUser } from 'customfit-reactnative-client-sdk';
   ```

3. **Update provider implementation**:
   ```typescript
   // Use real SDK instead of mock
   const cfClient = CFClient.create(config, user);
   ```

## Development

### Running Tests

```bash
npm test
```

### Linting

```bash
npm run lint
```

### Building

```bash
# Android
npm run android

# iOS  
npm run ios
```

## Troubleshooting

### Common Issues

1. **Metro bundler issues**
   ```bash
   npx react-native start --reset-cache
   ```

2. **Navigation errors**
   ```bash
   # Make sure React Navigation dependencies are installed
   npm install @react-navigation/native @react-navigation/stack
   ```

3. **Provider context errors**
   - Ensure components are wrapped in `CustomFitProvider`
   - Check that `useCustomFit()` is called within provider scope

### Debug Mode

The demo app includes comprehensive console logging:
- SDK initialization status
- Feature flag updates
- Event tracking confirmations  
- Configuration changes
- Error messages and stack traces

Check the Metro bundler console or device logs for detailed information.

## SDK Documentation

For complete SDK documentation, refer to:
- [CustomFit React Native SDK Documentation](../customfit-reactnative-client-sdk/README.md)
- [SDK Feature Specification](../SDK_FEATURE_SPECIFICATION.md)
- [Flutter Demo App](../demo-flutter-app-sdk/) - Reference implementation

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the SDK documentation
3. Compare with the Flutter demo app implementation
4. Check console logs for error details
5. Ensure all prerequisites are met

## License

This demo app is part of the CustomFit Mobile SDKs project.
