# CustomFit Flutter SDK

A Flutter SDK for integrating with CustomFit's feature flagging and event tracking services.

## Features

- Feature flag management
- A/B testing
- Event tracking
- User context management
- Offline support
- Cross-platform compatibility (iOS, Android, Web)

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  customfit_flutter_sdk: ^0.1.0
```

## Usage

### Initialize the SDK

```dart
import 'package:customfit_flutter_sdk/customfit_flutter_sdk.dart';

void main() async {
  // Initialize the SDK
  await CustomFit.initialize(
    clientKey: 'your_client_key',
    config: CFConfig(
      offlineMode: false,
      debugLoggingEnabled: true,
    ),
  );
  
  runApp(MyApp());
}
```

### Feature Flags

```dart
// Check if a feature is enabled
bool isEnabled = await CustomFit.isFeatureEnabled('feature_name');

// Get feature configuration with default value
Map<String, dynamic> config = await CustomFit.getFeatureConfig(
  'feature_name',
  defaultValue: {'key': 'default_value'},
);
```

### Track Events

```dart
// Track a simple event
CustomFit.trackEvent('button_click');

// Track an event with properties
CustomFit.trackEvent(
  'purchase',
  properties: {
    'product_id': 'abc123',
    'price': 29.99,
    'currency': 'USD',
  },
);
```

## License

[MIT License](LICENSE)
