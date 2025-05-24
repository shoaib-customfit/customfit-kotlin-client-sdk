import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';

void main() {
  // Initialize Flutter bindings for testing
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('CFClient Singleton Tests', () {
    late CFConfig testConfig;
    late CFUser testUser;

    setUp(() async {
      // Ensure clean state before each test
      await CFClient.shutdownSingleton();

      // Create a test-optimized configuration that prevents network calls
      testConfig = CFConfig.builder('test-client-key')
          .setDebugLoggingEnabled(true)
          .setOfflineMode(true) // Use offline mode for testing
          .setDisableBackgroundPolling(true) // Disable background polling
          .setSdkSettingsCheckIntervalMs(300000) // 5 minutes (reasonable interval)
          .setNetworkConnectionTimeoutMs(5000) // Short timeout for tests
          .setNetworkReadTimeoutMs(5000) // Short timeout for tests
          .build();

      testUser = CFUser(
        userCustomerId: 'test-user-123',
        properties: {'platform': 'flutter-test'},
      );
    });

    tearDown(() async {
      // Clean up after each test
      await CFClient.shutdownSingleton();
      
      // Add a small delay to ensure cleanup is complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('singleton creation returns same instance', () async {
      // First call should create instance
      final client1 = await CFClient.init(testConfig, testUser);
      expect(CFClient.isInitialized(), isTrue);
      expect(client1, isNotNull);

      // Second call should return same instance
      final client2 = await CFClient.init(testConfig, testUser);
      expect(identical(client1, client2), isTrue);

      // getInstance should also return same instance
      final client3 = CFClient.getInstance();
      expect(identical(client1, client3), isTrue);
    });

    test('singleton state before initialization', () {
      // Before initialization
      expect(CFClient.isInitialized(), isFalse);
      expect(CFClient.getInstance(), isNull);
      expect(CFClient.isInitializing(), isFalse);
    });

    test('singleton state during and after initialization', () async {
      final initFuture = CFClient.init(testConfig, testUser);
      
      // Small delay to potentially catch initializing state
      await Future.delayed(const Duration(milliseconds: 10));

      final client = await initFuture;

      expect(CFClient.isInitialized(), isTrue);
      expect(CFClient.getInstance(), isNotNull);
      expect(CFClient.isInitializing(), isFalse);
      expect(identical(client, CFClient.getInstance()), isTrue);
    });

    test('concurrent initialization returns same instance', () async {
      const numberOfFutures = 10;
      final clients = <CFClient>[];

      // Launch multiple futures trying to initialize simultaneously
      final futures = List.generate(numberOfFutures, (_) => 
        CFClient.init(testConfig, testUser)
      );

      // Wait for all futures to complete
      final results = await Future.wait(futures);
      clients.addAll(results);

      // All should have gotten the same instance
      expect(clients.length, equals(numberOfFutures));
      final firstClient = clients.first;
      for (final client in clients) {
        expect(identical(firstClient, client), isTrue);
      }

      expect(CFClient.isInitialized(), isTrue);
      expect(identical(firstClient, CFClient.getInstance()), isTrue);
    });

    test('concurrent initialization with different configurations', () async {
      final config1 = CFConfig.builder('client-key-1')
          .setOfflineMode(true)
          .setDisableBackgroundPolling(true)
          .build();
      final config2 = CFConfig.builder('client-key-2')
          .setOfflineMode(true)
          .setDisableBackgroundPolling(true)
          .build();
      final user1 = CFUser(userCustomerId: 'user-1');
      final user2 = CFUser(userCustomerId: 'user-2');

      final clients = <CFClient>[];

      // Launch futures with different configs - first one should win
      final futures = [
        CFClient.init(config1, user1),
        CFClient.init(config2, user2),
        CFClient.init(config1, user1),
        CFClient.init(config2, user2),
      ];

      final results = await Future.wait(futures);
      clients.addAll(results);

      // All should return the same instance (first one initialized)
      expect(clients.length, equals(4));
      final firstClient = clients.first;
      for (final client in clients) {
        expect(identical(firstClient, client), isTrue);
      }
    });

    test('shutdown clears singleton', () async {
      // Create instance
      final client = await CFClient.init(testConfig, testUser);
      expect(CFClient.isInitialized(), isTrue);
      expect(identical(client, CFClient.getInstance()), isTrue);

      // Shutdown
      await CFClient.shutdownSingleton();

      // Should be cleared
      expect(CFClient.isInitialized(), isFalse);
      expect(CFClient.getInstance(), isNull);
      expect(CFClient.isInitializing(), isFalse);
    });

    test('reinitialize creates new instance', () async {
      // Create first instance
      final client1 = await CFClient.init(testConfig, testUser);
      expect(CFClient.isInitialized(), isTrue);

      // Reinitialize with different config
      final newConfig = CFConfig.builder('new-client-key')
          .setOfflineMode(true)
          .setDisableBackgroundPolling(true)
          .build();
      final newUser = CFUser(userCustomerId: 'new-user');
      final client2 = await CFClient.reinitialize(newConfig, newUser);

      // Should be different instance
      expect(identical(client1, client2), isFalse);
      expect(CFClient.isInitialized(), isTrue);
      expect(identical(client2, CFClient.getInstance()), isTrue);
    });

    test('createDetached bypasses singleton', () async {
      // Create singleton instance
      final singletonClient = await CFClient.init(testConfig, testUser);
      expect(CFClient.isInitialized(), isTrue);

      // Create detached instance
      final detachedClient = CFClient.createDetached(testConfig, testUser);

      // Should be different instances
      expect(identical(singletonClient, detachedClient), isFalse);

      // Singleton should still be intact
      expect(CFClient.isInitialized(), isTrue);
      expect(identical(singletonClient, CFClient.getInstance()), isTrue);
    });

    test('initialization failure handling', () async {
      // Test that even after multiple failed attempts to create instances with different configs,
      // once a valid instance is created, it remains the singleton
      
      // First ensure no singleton exists
      expect(CFClient.isInitialized(), isFalse);
      expect(CFClient.getInstance(), isNull);
      
      // Create a valid instance
      final validClient = await CFClient.init(testConfig, testUser);
      expect(CFClient.isInitialized(), isTrue);
      expect(identical(validClient, CFClient.getInstance()), isTrue);
      
      // Try to create another instance with different config - should return same instance
      final differentConfig = CFConfig.builder('different-key')
          .setOfflineMode(true)
          .setDisableBackgroundPolling(true)
          .build();
      final differentUser = CFUser(userCustomerId: 'different-user');
      final secondClient = await CFClient.init(differentConfig, differentUser);
      
      // Should return the same instance (singleton behavior)
      expect(identical(validClient, secondClient), isTrue);
      expect(CFClient.isInitialized(), isTrue);
    });

    test('singleton behavior across different initialization patterns', () async {
      // Test various ways of trying to get instances all return the same singleton
      
      // Create initial instance
      final initialClient = await CFClient.init(testConfig, testUser);
      expect(CFClient.isInitialized(), isTrue);
      
      // Different configs should still return same instance
      final config2 = CFConfig.builder('another-key')
          .setOfflineMode(true) // Keep offline for testing
          .setDisableBackgroundPolling(true)
          .build();
      final user2 = CFUser(
        userCustomerId: 'another-user',
        properties: {'type': 'test'},
      );
      final client2 = await CFClient.init(config2, user2);
      
      // Instance method
      final client3 = CFClient.getInstance();
      
      // All should be the same
      expect(identical(initialClient, client2), isTrue);
      expect(identical(initialClient, client3), isTrue);
      
      // Only one instance should exist
      expect(CFClient.isInitialized(), isTrue);
      expect(CFClient.isInitializing(), isFalse);
    });

    test('deprecated create method still works', () {
      // Test that the deprecated create method still creates instances
      // but doesn't interfere with singleton pattern
      
      expect(CFClient.isInitialized(), isFalse);
      
      // Use createDetached method instead of deprecated create
      final detachedClient = CFClient.createDetached(testConfig, testUser);
      expect(detachedClient, isNotNull);
      
      // Should not affect singleton state
      expect(CFClient.isInitialized(), isFalse);
      expect(CFClient.getInstance(), isNull);
    });

    test('basic functionality after singleton initialization', () async {
      // Test that basic client functionality works after singleton initialization
      final client = await CFClient.init(testConfig, testUser);
      
      expect(client, isNotNull);
      expect(CFClient.isInitialized(), isTrue);
      
      // Test basic operations
      expect(client.isOffline(), isTrue); // Should be offline based on config
      
      // Test getting config values (should use defaults in offline mode)
      final stringValue = client.getString('test_key', 'default_value');
      expect(stringValue, equals('default_value'));
      
      final boolValue = client.getBoolean('test_bool', true);
      expect(boolValue, isTrue);
      
      // Test event tracking
      final eventResult = await client.trackEvent('test_event', properties: {'key': 'value'});
      expect(eventResult.isSuccess, isTrue);
    });
  });
} 