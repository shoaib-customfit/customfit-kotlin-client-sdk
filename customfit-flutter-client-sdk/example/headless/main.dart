// A headless test file for CustomFit Flutter SDK
// Similar to main.kt in the Kotlin SDK

import 'dart:async';
import 'dart:io';
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';

// Replace with your actual client key
const String CLIENT_KEY = 'your-client-key-here';

void main() async {
  print('Starting CustomFit Flutter SDK Headless Test');

  // Create a user
  final user = CFUser(
    userCustomerId: 'test-user-${DateTime.now().millisecondsSinceEpoch}',
    properties: {
      'email': 'test@example.com',
      'name': 'Test User',
      'age': 30,
      'premium': true,
    },
  );

  // Create a config with the builder pattern
  final config = CFConfig.builder(CLIENT_KEY)
      .setEventsQueueSize(20)
      .setEventsFlushTimeSeconds(15)
      .setLoggingEnabled(true)
      .setDebugLoggingEnabled(true)
      .setAutoEnvAttributesEnabled(true)
      .build();

  // Initialize the SDK
  print('Initializing CFClient...');
  final cfClient = await initializeSDK(config, user);

  // Set up listeners
  setupListeners(cfClient);

  // Test feature flag evaluation
  await testFeatureFlags(cfClient);

  // Test event tracking
  await testEventTracking(cfClient);

  // Wait for a bit to allow events to be processed
  await Future.delayed(const Duration(seconds: 5));

  // Clean shutdown
  print('Shutting down CFClient...');
  await cfClient.shutdown();

  print('Test completed successfully');
  exit(0);
}

Future<CFClient> initializeSDK(CFConfig config, CFUser user) async {
  try {
    // Create a factory method for CFClient since it uses a private constructor
    // In a real implementation, CFClient would have a public factory method
    final cfClient = createCFClient(config, user);

    // Wait for initialization to complete
    await Future.delayed(const Duration(seconds: 2));

    print('CFClient initialized successfully');
    return cfClient;
  } catch (e) {
    print('Error initializing CFClient: $e');
    exit(1);
  }
}

// Factory method to create CFClient (since it has a private constructor)
CFClient createCFClient(CFConfig config, CFUser user) {
  // This is a workaround for the private constructor
  // In a real implementation, CFClient would have a public factory method
  // We're using dynamic to bypass the private constructor restriction
  // In a real implementation, you would use the public factory method
  final dynamic client = CFClient;
  return client._(config, user);
}

void setupListeners(CFClient cfClient) {
  // Add connection status listener
  cfClient.addConnectionStatusListener(_connectionStatusListener);

  // Add feature flag change listener for specific flag
  cfClient.listenerManager
      .registerFeatureFlagListener('test-flag', _featureFlagChangeListener);

  // Add all flags listener
  cfClient.listenerManager.registerAllFlagsListener(_allFlagsListener);

  print('Listeners set up successfully');
}

Future<void> testFeatureFlags(CFClient cfClient) async {
  print('\n--- Testing Feature Flags ---');

  // Get a string flag
  final stringFlag =
      cfClient.configManager.getString('string-flag', 'default-value');
  print('String flag value: $stringFlag');

  // Get a boolean flag
  final boolFlag = cfClient.configManager.getBoolean('bool-flag', false);
  print('Boolean flag value: $boolFlag');

  // Get a number flag
  final numberFlag = cfClient.configManager.getNumber('number-flag', 0);
  print('Number flag value: $numberFlag');

  // Get a JSON flag
  final jsonFlag =
      cfClient.configManager.getJson('json-flag', {'default': true});
  print('JSON flag value: $jsonFlag');

  // Get all flags
  final allFlags = cfClient.configManager.getAllFlags();
  print('All flags: $allFlags');
}

Future<void> testEventTracking(CFClient cfClient) async {
  print('\n--- Testing Event Tracking ---');

  // Track a simple event
  final result1 = await cfClient.trackEvent('test_event');
  print(
      'Simple event tracking result: ${result1.isSuccess ? 'Success' : 'Failed'}');

  // Track an event with properties
  final result2 =
      await cfClient.trackEvent('test_event_with_props', properties: {
    'category': 'test',
    'value': 123,
    'items': ['item1', 'item2'],
  });
  print(
      'Event with properties tracking result: ${result2.isSuccess ? 'Success' : 'Failed'}');

  // Force flush events
  await cfClient.eventTracker.flush();
  print('Events flushed');
}

// Listener implementations
void _connectionStatusListener(
    ConnectionStatus status, ConnectionInformation info) {
  print('Connection status changed: $status');
  print(
      'Connection info: ${info.isOfflineMode ? 'Offline' : 'Online'}, failures: ${info.failureCount}');
}

// Implement the FeatureFlagChangeListener interface
class TestFeatureFlagChangeListener implements FeatureFlagChangeListener {
  @override
  void onFeatureFlagChanged(
      String flagKey, dynamic oldValue, dynamic newValue) {
    print('Feature flag "$flagKey" changed: $oldValue -> $newValue');
  }
}

// Implement the AllFlagsListener interface
class TestAllFlagsListener implements AllFlagsListener {
  @override
  void onAllFlagsChanged(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {
    print('All flags changed');
    print('Old flags count: ${oldFlags.length}');
    print('New flags count: ${newFlags.length}');
  }
}

// Create instances of the listeners
final _featureFlagChangeListener = TestFeatureFlagChangeListener();
final _allFlagsListener = TestAllFlagsListener();
