import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_flutter_client_sdk/src/config/core/cf_config.dart';
import 'package:customfit_flutter_client_sdk/src/core/model/cf_user.dart';
import 'package:customfit_flutter_client_sdk/src/client/cf_client.dart';

void main() {
  // Initialize Flutter bindings for testing
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Local Storage Configuration Tests', () {
    late CFUser testUser;

    setUp(() async {
      // Ensure clean state before each test
      await CFClient.shutdownSingleton();

      // Create a test user
      testUser = CFUser(userCustomerId: 'test-user-123');
    });

    tearDown(() async {
      await CFClient.shutdownSingleton();
    });

    test('should have correct default local storage settings', () {
      // When: Creating a default config
      final config = CFConfig.builder('test-client-key').build();

      // Then: Should have proper default local storage settings
      expect(config.localStorageEnabled, isTrue);
      expect(config.configCacheTtlSeconds, equals(86400)); // 24 hours
      expect(config.eventCacheTtlSeconds, equals(3600)); // 1 hour
      expect(config.summaryCacheTtlSeconds, equals(3600)); // 1 hour
      expect(config.maxCacheSizeMb, equals(50)); // 50 MB
      expect(config.persistCacheAcrossRestarts, isTrue);
      expect(config.useStaleWhileRevalidate, isTrue);
    });

    test('should allow customizing local storage settings', () {
      // When: Creating a config with custom local storage settings
      final config = CFConfig.builder('test-client-key')
          .setLocalStorageEnabled(false)
          .setConfigCacheTtlSeconds(7200) // 2 hours
          .setEventCacheTtlSeconds(1800) // 30 minutes
          .setSummaryCacheTtlSeconds(1800) // 30 minutes
          .setMaxCacheSizeMb(100) // 100 MB
          .setPersistCacheAcrossRestarts(false)
          .setUseStaleWhileRevalidate(false)
          .build();

      // Then: Should have the custom settings
      expect(config.localStorageEnabled, isFalse);
      expect(config.configCacheTtlSeconds, equals(7200));
      expect(config.eventCacheTtlSeconds, equals(1800));
      expect(config.summaryCacheTtlSeconds, equals(1800));
      expect(config.maxCacheSizeMb, equals(100));
      expect(config.persistCacheAcrossRestarts, isFalse);
      expect(config.useStaleWhileRevalidate, isFalse);
    });

    test('should validate local storage configuration parameters', () {
      // When/Then: Should throw ArgumentError for invalid cache TTL
      expect(
        () => CFConfig.builder('test-client-key')
            .setConfigCacheTtlSeconds(-1)
            .build(),
        throwsArgumentError,
      );

      expect(
        () => CFConfig.builder('test-client-key')
            .setEventCacheTtlSeconds(-1)
            .build(),
        throwsArgumentError,
      );

      expect(
        () => CFConfig.builder('test-client-key')
            .setSummaryCacheTtlSeconds(-1)
            .build(),
        throwsArgumentError,
      );

      expect(
        () => CFConfig.builder('test-client-key')
            .setMaxCacheSizeMb(0)
            .build(),
        throwsArgumentError,
      );

      expect(
        () => CFConfig.builder('test-client-key')
            .setMaxCacheSizeMb(-1)
            .build(),
        throwsArgumentError,
      );
    });

    test('should work with local storage disabled', () async {
      // Given: Config with local storage disabled
      final config = CFConfig.builder('test-client-key')
          .setDebugLoggingEnabled(true)
          .setOfflineMode(true) // Use offline mode for testing
          .setDisableBackgroundPolling(true) // Disable background polling
          .setLocalStorageEnabled(false) // Disable local storage
          .build();

      expect(config.localStorageEnabled, isFalse);

      // When: Initializing CFClient
      final client = await CFClient.initialize(config, testUser);

      // Then: Should initialize successfully without local storage
      expect(client, isNotNull);
      expect(CFClient.isInitialized(), isTrue);
    });

    test('should work with local storage enabled', () async {
      // Given: Config with local storage enabled
      final config = CFConfig.builder('test-client-key')
          .setDebugLoggingEnabled(true)
          .setOfflineMode(true) // Use offline mode for testing
          .setDisableBackgroundPolling(true) // Disable background polling
          .setLocalStorageEnabled(true) // Enable local storage
          .setConfigCacheTtlSeconds(3600) // 1 hour
          .build();

      expect(config.localStorageEnabled, isTrue);

      // When: Initializing CFClient
      final client = await CFClient.initialize(config, testUser);

      // Then: Should initialize successfully with local storage
      expect(client, isNotNull);
      expect(CFClient.isInitialized(), isTrue);
    });

    test('should support copyWith for local storage settings', () {
      // Given: Original config
      final originalConfig = CFConfig.builder('test-client-key')
          .setLocalStorageEnabled(true)
          .setConfigCacheTtlSeconds(3600)
          .build();

      // When: Creating a copy with modified local storage settings
      final modifiedConfig = originalConfig.copyWith(
        localStorageEnabled: false,
        configCacheTtlSeconds: 7200,
        maxCacheSizeMb: 100,
      );

      // Then: Should have the modified settings
      expect(modifiedConfig.localStorageEnabled, isFalse);
      expect(modifiedConfig.configCacheTtlSeconds, equals(7200));
      expect(modifiedConfig.maxCacheSizeMb, equals(100));
      
      // And: Should preserve other settings
      expect(modifiedConfig.clientKey, equals(originalConfig.clientKey));
      expect(modifiedConfig.eventsQueueSize, equals(originalConfig.eventsQueueSize));
    });

    test('should have consistent defaults with other SDKs', () {
      // When: Creating a default config
      final config = CFConfig.builder('test-client-key').build();

      // Then: Should have consistent defaults with Swift/Kotlin SDKs
      expect(config.eventsQueueSize, equals(100));
      expect(config.eventsFlushTimeSeconds, equals(60));
      expect(config.eventsFlushIntervalMs, equals(1000));
      expect(config.maxRetryAttempts, equals(3));
      expect(config.retryInitialDelayMs, equals(1000));
      expect(config.retryMaxDelayMs, equals(30000));
      expect(config.retryBackoffMultiplier, equals(2.0));
      expect(config.summariesQueueSize, equals(100));
      expect(config.summariesFlushTimeSeconds, equals(60));
      expect(config.summariesFlushIntervalMs, equals(60000));
      expect(config.sdkSettingsCheckIntervalMs, equals(300000)); // 5 minutes
      expect(config.networkConnectionTimeoutMs, equals(10000));
      expect(config.networkReadTimeoutMs, equals(10000));
      expect(config.logLevel, equals('DEBUG'));
      expect(config.backgroundPollingIntervalMs, equals(3600000)); // 1 hour
      expect(config.reducedPollingIntervalMs, equals(7200000)); // 2 hours
      expect(config.maxStoredEvents, equals(100));
      expect(config.autoEnvAttributesEnabled, isFalse);
    });

    test('should support mutable config updates for local storage', () {
      // Given: Original config
      final originalConfig = CFConfig.builder('test-client-key')
          .setLocalStorageEnabled(true)
          .setConfigCacheTtlSeconds(3600)
          .build();

      final mutableConfig = MutableCFConfig(originalConfig);

      // When: Updating local storage settings
      mutableConfig.updateLocalStorageEnabled(false);
      mutableConfig.updateConfigCacheTtl(7200);

      // Then: Should have the updated settings
      expect(mutableConfig.config.localStorageEnabled, isFalse);
      expect(mutableConfig.config.configCacheTtlSeconds, equals(7200));
    });
  });
} 