import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_flutter_client_sdk/src/config/core/cf_config.dart';

void main() {
  group('CFConfig Tests', () {
    test('should create CFConfig with default values', () {
      final config = CFConfig.fromClientKey('test-client-key');

      expect(config.clientKey, equals('test-client-key'));
      expect(config.eventsQueueSize, equals(100));
      expect(config.eventsFlushTimeSeconds, equals(60));
      expect(config.eventsFlushIntervalMs, equals(1000));
      expect(config.summariesQueueSize, equals(100));
      expect(config.summariesFlushTimeSeconds, equals(60));
      expect(config.summariesFlushIntervalMs, equals(60000));
      expect(config.sdkSettingsCheckIntervalMs, equals(300000));
      expect(config.networkConnectionTimeoutMs, equals(10000));
      expect(config.networkReadTimeoutMs, equals(10000));
      expect(config.logLevel, equals('DEBUG'));
      expect(config.backgroundPollingIntervalMs, equals(3600000));
      expect(config.reducedPollingIntervalMs, equals(7200000));
      expect(config.maxStoredEvents, equals(100));
      expect(config.loggingEnabled, isTrue);
      expect(config.debugLoggingEnabled, isFalse);
      expect(config.offlineMode, isFalse);
      expect(config.autoEnvAttributesEnabled, isFalse);
    });

    test('should create CFConfig using builder pattern', () {
      final config = Builder('test-key')
          .setEventsQueueSize(50)
          .setEventsFlushTimeSeconds(60)
          .setMaxRetryAttempts(5)
          .setLoggingEnabled(false)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(true)
          .setAutoEnvAttributesEnabled(true)
          .build();

      expect(config.clientKey, equals('test-key'));
      expect(config.eventsQueueSize, equals(50));
      expect(config.eventsFlushTimeSeconds, equals(60));
      expect(config.maxRetryAttempts, equals(5));
      expect(config.loggingEnabled, isFalse);
      expect(config.debugLoggingEnabled, isTrue);
      expect(config.offlineMode, isTrue);
      expect(config.autoEnvAttributesEnabled, isTrue);
    });

    test('should set all builder properties correctly', () {
      final config = Builder('test-key')
          .setEventsQueueSize(100)
          .setEventsFlushTimeSeconds(120)
          .setEventsFlushIntervalMs(60000)
          .setMaxRetryAttempts(7)
          .setRetryInitialDelayMs(2000)
          .setRetryMaxDelayMs(60000)
          .setRetryBackoffMultiplier(2.0)
          .setSummariesQueueSize(20)
          .setSummariesFlushTimeSeconds(90)
          .setSummariesFlushIntervalMs(45000)
          .setSdkSettingsCheckIntervalMs(120000)
          .setNetworkConnectionTimeoutMs(15000)
          .setNetworkReadTimeoutMs(45000)
          .setLogLevel('debug')
          .setDisableBackgroundPolling(true)
          .setBackgroundPollingIntervalMs(600000)
          .setUseReducedPollingWhenBatteryLow(false)
          .setReducedPollingIntervalMs(1800000)
          .setMaxStoredEvents(2000)
          .build();

      expect(config.eventsQueueSize, equals(100));
      expect(config.eventsFlushTimeSeconds, equals(120));
      expect(config.eventsFlushIntervalMs, equals(60000));
      expect(config.maxRetryAttempts, equals(7));
      expect(config.retryInitialDelayMs, equals(2000));
      expect(config.retryMaxDelayMs, equals(60000));
      expect(config.retryBackoffMultiplier, equals(2.0));
      expect(config.summariesQueueSize, equals(20));
      expect(config.summariesFlushTimeSeconds, equals(90));
      expect(config.summariesFlushIntervalMs, equals(45000));
      expect(config.sdkSettingsCheckIntervalMs, equals(120000));
      expect(config.networkConnectionTimeoutMs, equals(15000));
      expect(config.networkReadTimeoutMs, equals(45000));
      expect(config.logLevel, equals('debug'));
      expect(config.disableBackgroundPolling, isTrue);
      expect(config.backgroundPollingIntervalMs, equals(600000));
      expect(config.useReducedPollingWhenBatteryLow, isFalse);
      expect(config.reducedPollingIntervalMs, equals(1800000));
      expect(config.maxStoredEvents, equals(2000));
    });

    test('should create builder from static method', () {
      final builder = CFConfig.builder('test-key');
      
      expect(builder, isA<Builder>());
      expect(builder.clientKey, equals('test-key'));
    });

    test('should throw error for empty client key', () {
      expect(
        () => Builder(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should extract dimension ID from valid JWT token', () {
      // This is a mock JWT token with dimension_id in payload
      // In real implementation, you'd use a proper JWT library
      const validToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkaW1lbnNpb25faWQiOiJ0ZXN0LWRpbWVuc2lvbi0xMjMiLCJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      
      final config = CFConfig.fromClientKey(validToken);
      
      expect(config.dimensionId, equals('test-dimension-123'));
    });

    test('should return null dimension ID for invalid token', () {
      const invalidToken = 'invalid-token';
      
      final config = CFConfig.fromClientKey(invalidToken);
      
      expect(config.dimensionId, isNull);
    });

    test('should return null dimension ID for malformed token', () {
      const malformedToken = 'part1.part2'; // Missing part3
      
      final config = CFConfig.fromClientKey(malformedToken);
      
      expect(config.dimensionId, isNull);
    });

    test('should handle builder fluent API chaining', () {
      final config = Builder('test-key')
          .setEventsQueueSize(25)
          .setLoggingEnabled(false)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(true)
          .setMaxRetryAttempts(10)
          .build();

      expect(config.eventsQueueSize, equals(25));
      expect(config.loggingEnabled, isFalse);
      expect(config.debugLoggingEnabled, isTrue);
      expect(config.offlineMode, isTrue);
      expect(config.maxRetryAttempts, equals(10));
    });

    test('should maintain immutability of built config', () {
      final builder = Builder('test-key')
          .setEventsQueueSize(50);
      
      final config1 = builder.build();
      
      // Modify builder after first build
      builder.setEventsQueueSize(100);
      final config2 = builder.build();

      // First config should remain unchanged
      expect(config1.eventsQueueSize, equals(50));
      expect(config2.eventsQueueSize, equals(100));
    });

    test('should handle network configuration', () {
      final config = Builder('test-key')
          .setNetworkConnectionTimeoutMs(5000)
          .setNetworkReadTimeoutMs(15000)
          .build();

      expect(config.networkConnectionTimeoutMs, equals(5000));
      expect(config.networkReadTimeoutMs, equals(15000));
    });

    test('should handle retry configuration', () {
      final config = Builder('test-key')
          .setMaxRetryAttempts(5)
          .setRetryInitialDelayMs(500)
          .setRetryMaxDelayMs(10000)
          .setRetryBackoffMultiplier(2.5)
          .build();

      expect(config.maxRetryAttempts, equals(5));
      expect(config.retryInitialDelayMs, equals(500));
      expect(config.retryMaxDelayMs, equals(10000));
      expect(config.retryBackoffMultiplier, equals(2.5));
    });

    test('should handle summary configuration', () {
      final config = Builder('test-key')
          .setSummariesQueueSize(15)
          .setSummariesFlushTimeSeconds(45)
          .setSummariesFlushIntervalMs(22500)
          .build();

      expect(config.summariesQueueSize, equals(15));
      expect(config.summariesFlushTimeSeconds, equals(45));
      expect(config.summariesFlushIntervalMs, equals(22500));
    });

    test('should handle background operation settings', () {
      final config = Builder('test-key')
          .setDisableBackgroundPolling(true)
          .setBackgroundPollingIntervalMs(180000)
          .setUseReducedPollingWhenBatteryLow(false)
          .setReducedPollingIntervalMs(600000)
          .build();

      expect(config.disableBackgroundPolling, isTrue);
      expect(config.backgroundPollingIntervalMs, equals(180000));
      expect(config.useReducedPollingWhenBatteryLow, isFalse);
      expect(config.reducedPollingIntervalMs, equals(600000));
    });

    test('should handle storage configuration', () {
      final config = Builder('test-key')
          .setMaxStoredEvents(5000)
          .build();

      expect(config.maxStoredEvents, equals(5000));
    });

    test('should handle log level configuration', () {
      final config = Builder('test-key')
          .setLogLevel('error')
          .build();

      expect(config.logLevel, equals('error'));
    });

    test('should use default values for unset properties', () {
      final config = CFConfig.builder('test-client-key')
          .setDebugLoggingEnabled(true)
          .build();

      expect(config.clientKey, equals('test-client-key'));
      expect(config.eventsQueueSize, equals(100));
      expect(config.eventsFlushTimeSeconds, equals(60));
      expect(config.eventsFlushIntervalMs, equals(1000));
      expect(config.summariesQueueSize, equals(100));
      expect(config.summariesFlushTimeSeconds, equals(60));
      expect(config.summariesFlushIntervalMs, equals(60000));
      expect(config.sdkSettingsCheckIntervalMs, equals(300000));
      expect(config.networkConnectionTimeoutMs, equals(10000));
      expect(config.networkReadTimeoutMs, equals(10000));
      expect(config.logLevel, equals('DEBUG'));
      expect(config.backgroundPollingIntervalMs, equals(3600000));
      expect(config.reducedPollingIntervalMs, equals(7200000));
      expect(config.maxStoredEvents, equals(100));
      expect(config.loggingEnabled, isTrue);
      expect(config.debugLoggingEnabled, isTrue);
      expect(config.offlineMode, isFalse);
      expect(config.autoEnvAttributesEnabled, isFalse);
    });
  });
} 