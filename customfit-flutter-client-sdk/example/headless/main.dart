// A headless test file for CustomFit Flutter SDK
// Similar to main.kt in the Kotlin SDK

import 'dart:async';
import 'dart:io';
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';
// Import feature flag listener directly from the source
import 'package:customfit_flutter_client_sdk/src/client/listener/feature_flag_change_listener.dart';

// Client key from Main.kt
const String CLIENT_KEY =
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek';

void main() async {
  final timestamp = () => DateTime.now().toString().split('.')[0];

  print('[${timestamp()}] Starting CustomFit Flutter SDK Headless Test');

  // Create a user to match Main.kt
  final user = CFUser(
    userCustomerId: 'user123',
    anonymous: false,
    properties: {
      'name': 'john',
    },
  );

  // Create a config with the builder pattern to match Main.kt settings
  final config = CFConfig.builder(CLIENT_KEY)
      .setSdkSettingsCheckIntervalMs(20000)
      .setBackgroundPollingIntervalMs(20000)
      .setReducedPollingIntervalMs(20000)
      .setSummariesFlushTimeSeconds(3)
      .setSummariesFlushIntervalMs(3000)
      .setEventsFlushTimeSeconds(3)
      .setEventsFlushIntervalMs(3000)
      .setDebugLoggingEnabled(true)
      .build();

  print('\n[${timestamp()}] Test config for SDK settings check:');
  print(
      '[${timestamp()}] - SDK Settings Check Interval: ${config.sdkSettingsCheckIntervalMs}ms');

  print('\n[${timestamp()}] Initializing CFClient with test config...');

  try {
    // Initialize the SDK using CFClient.create instead of init
    final cfClient = CFClient.create(config, user);

    print(
        '[${timestamp()}] Debug logging enabled - watch for SDK settings checks in logs');
    print('[${timestamp()}] Waiting for initial SDK settings check...');

    // Simulate waiting for SDK settings check to complete (3 seconds)
    await Future.delayed(const Duration(seconds: 3));

    print('[${timestamp()}] Initial SDK settings check complete.');

    print(
        '\n[${timestamp()}] Testing event tracking is disabled to reduce POST requests...');

    // Set up flag listener for 'hero_text' as in Main.kt
    final flagChangeListener =
        _HeroTextListener(onChanged: (flagKey, oldValue, newValue) {
      print('[${timestamp()}] CHANGE DETECTED: $flagKey updated to: $newValue');
    });
    cfClient.listenerManager
        .registerFeatureFlagListener('hero_text', flagChangeListener);

    print('\n[${timestamp()}] --- PHASE 1: Normal SDK Settings Checks ---');
    for (int i = 1; i <= 3; i++) {
      print('\n[${timestamp()}] Check cycle $i...');

      print('[${timestamp()}] About to track event-$i for cycle $i');
      final trackResult =
          await cfClient.trackEvent('event-$i', properties: {'source': 'app'});
      print(
          '[${timestamp()}] Result of tracking event-$i: ${trackResult.isSuccess}');
      print('[${timestamp()}] Tracked event-$i for cycle $i');

      print('[${timestamp()}] Waiting for SDK settings check...');
      await Future.delayed(const Duration(seconds: 5));

      final currentValue =
          cfClient.configManager.getString('hero_text', 'default-value');
      print('[${timestamp()}] Value after check cycle $i: $currentValue');
    }

    // Clean shutdown
    print('\n[${timestamp()}] Shutting down CFClient...');
    await cfClient.shutdown();

    print('\n[${timestamp()}] Test completed after all check cycles');
    print('[${timestamp()}] Test complete. Press Enter to exit...');
    stdin.readLineSync();
  } catch (e) {
    print('Error during test: $e');
    exit(1);
  }
}

// Implement the FeatureFlagChangeListener interface
class _HeroTextListener implements FeatureFlagChangeListener {
  final Function(String, dynamic, dynamic)? onChanged;

  _HeroTextListener({this.onChanged});

  @override
  void onFeatureFlagChanged(
      String flagKey, dynamic oldValue, dynamic newValue) {
    if (onChanged != null) {
      onChanged!(flagKey, oldValue, newValue);
    } else {
      print('Feature flag "$flagKey" changed: $oldValue -> $newValue');
    }
  }
}
