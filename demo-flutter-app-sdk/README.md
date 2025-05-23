# CustomFit Flutter SDK Demo App

A demo Flutter application showcasing the CustomFit Flutter Client SDK features and capabilities.

## Overview

This demo app demonstrates how to integrate and use the CustomFit Flutter SDK in a Flutter application. It includes examples of:

- SDK initialization and configuration
- User management and identification
- Feature flag retrieval and usage
- Event tracking and analytics
- Offline mode and error handling
- Real-time configuration updates

## Prerequisites

- Flutter SDK 3.2.3 or higher
- Dart 3.0.0 or higher
- Android Studio / VS Code with Flutter extensions
- iOS development tools (for iOS builds)

## Getting Started

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Run the App**
   ```bash
   # For development
   flutter run
   
   # For specific platform
   flutter run -d android
   flutter run -d ios
   flutter run -d chrome  # for web
   ```

3. **Build the App**
   ```bash
   # Android APK
   flutter build apk
   
   # iOS
   flutter build ios
   
   # Web
   flutter build web
   ```

## Configuration

The demo app uses a sample client key for demonstration purposes. In a real application, you would:

1. Replace the client key in the app with your actual CustomFit client key
2. Configure user identification based on your app's authentication system
3. Set up appropriate feature flags in your CustomFit dashboard

## Features Demonstrated

### SDK Initialization
- Basic SDK setup with configuration
- User identification and properties
- Environment attributes collection

### Feature Flags
- Boolean, string, number, and JSON feature flags
- Default value handling
- Real-time flag updates

### Analytics
- Custom event tracking
- User property updates
- Screen view tracking

### Advanced Features
- Offline mode handling
- Error recovery
- Performance monitoring
- Background/foreground state management

## Project Structure

```
lib/
├── main.dart              # App entry point
├── providers/             # State management
├── screens/               # UI screens
└── ...                    # Other app components
```

## SDK Integration

The app integrates the CustomFit Flutter SDK located at `../customfit-flutter-client-sdk`. The SDK provides:

- Comprehensive feature flag management
- Real-time configuration updates
- Analytics and event tracking
- Offline support and caching
- Error handling and recovery

## Development

For development and testing:

1. Make changes to the SDK in `../customfit-flutter-client-sdk`
2. Run `flutter pub get` to update dependencies
3. Test changes in the demo app
4. Use `flutter analyze` for code analysis
5. Run `flutter test` for unit tests

## Support

For questions about the CustomFit Flutter SDK or this demo app, please refer to the main SDK documentation or contact the development team.
