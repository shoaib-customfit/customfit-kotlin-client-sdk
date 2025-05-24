import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_flutter_client_sdk/src/config/core/cf_config.dart';
import 'package:customfit_flutter_client_sdk/src/core/model/cf_user.dart';
import 'package:customfit_flutter_client_sdk/src/client/cf_client.dart';

void main() {
  // Initialize Flutter bindings for testing
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('CustomFit Flutter SDK - Simple Functionality Test Suite', () => {
    setUp(() async {
      // Clean up any existing singleton instances
      try {
        await CFClient.shutdownSingleton();
      } catch (e) {
        // Ignore cleanup errors
      }
    }),

    tearDown(() async {
      // Clean up after each test
      try {
        await CFClient.shutdownSingleton();
      } catch (e) {
        // Ignore cleanup errors
      }
    }),

    group('CFConfig Creation Tests', () {
      test('should create CFConfig with valid client key', () {
        // When
        final config = CFConfig.fromClientKey('test-client-key');

        // Then
        expect(config.clientKey, equals('test-client-key'));
        expect(config.eventsQueueSize, equals(10));
        expect(config.eventsFlushTimeSeconds, equals(30));
        expect(config.loggingEnabled, isTrue);
        expect(config.debugLoggingEnabled, isFalse);
        expect(config.offlineMode, isFalse);
      });

      test('should create CFConfig with builder pattern', () {
        // When
        final config = CFConfig.builder('test-client-key')
            .setEventsQueueSize(50)
            .setEventsFlushTimeSeconds(60)
            .setMaxRetryAttempts(5)
            .setLoggingEnabled(false)
            .setDebugLoggingEnabled(true)
            .setOfflineMode(true)
            .build();

        // Then
        expect(config.clientKey, equals('test-client-key'));
        expect(config.eventsQueueSize, equals(50));
        expect(config.eventsFlushTimeSeconds, equals(60));
        expect(config.maxRetryAttempts, equals(5));
        expect(config.loggingEnabled, isFalse);
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.offlineMode, isTrue);
      });

      test('should validate builder parameters', () {
        // Test invalid queue size
        expect(
          () => CFConfig.builder('test-key').setEventsQueueSize(0).build(),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => CFConfig.builder('test-key').setEventsQueueSize(-1).build(),
          throwsA(isA<ArgumentError>()),
        );

        // Test invalid flush time
        expect(
          () => CFConfig.builder('test-key').setEventsFlushTimeSeconds(0).build(),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => CFConfig.builder('test-key').setEventsFlushTimeSeconds(-1).build(),
          throwsA(isA<ArgumentError>()),
        );

        // Test invalid retry attempts
        expect(
          () => CFConfig.builder('test-key').setMaxRetryAttempts(-1).build(),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle extreme configuration values', () {
        // Test maximum values
        final maxConfig = CFConfig.builder('test-client-key')
            .setEventsQueueSize(2147483647) // Max int
            .setEventsFlushTimeSeconds(2147483647)
            .setMaxRetryAttempts(2147483647)
            .setNetworkConnectionTimeoutMs(2147483647)
            .setNetworkReadTimeoutMs(2147483647)
            .build();

        expect(maxConfig, isNotNull);
        expect(maxConfig.eventsQueueSize, equals(2147483647));

        // Test minimum valid values
        final minConfig = CFConfig.builder('test-client-key')
            .setEventsQueueSize(1)
            .setEventsFlushTimeSeconds(1)
            .setMaxRetryAttempts(0)
            .setNetworkConnectionTimeoutMs(1)
            .setNetworkReadTimeoutMs(1)
            .build();

        expect(minConfig, isNotNull);
        expect(minConfig.eventsQueueSize, equals(1));
        expect(minConfig.eventsFlushTimeSeconds, equals(1));
        expect(minConfig.maxRetryAttempts, equals(0));
      });
    }),

    group('CFUser Creation Tests', () {
      test('should create CFUser with valid user ID', () {
        // When
        final user = CFUser(userCustomerId: 'test-user-123');

        // Then
        expect(user.userCustomerId, equals('test-user-123'));
        expect(user.anonymous, isFalse);
      });

      test('should create CFUser with properties', () {
        // When
        final user = CFUser(
          userCustomerId: 'test-user-123',
          properties: {
            'platform': 'flutter-test',
            'version': '1.0.0',
            'isTestUser': true,
          },
        );

        // Then
        expect(user.userCustomerId, equals('test-user-123'));
        expect(user.properties['platform'], equals('flutter-test'));
        expect(user.properties['version'], equals('1.0.0'));
        expect(user.properties['isTestUser'], equals(true));
      });

      test('should create anonymous user', () {
        // When
        final user = CFUser(anonymous: true);

        // Then
        expect(user.anonymous, isTrue);
        expect(user.userCustomerId, isNull);
      });

      test('should handle user with various property types', () {
        // When
        final user = CFUser(
          userCustomerId: 'test-user',
          properties: {
            'string': 'test',
            'number': 42,
            'boolean': true,
            'null_value': null,
            'list': [1, 2, 3],
            'map': {'nested': 'value'},
          },
        );

        // Then
        expect(user.properties['string'], equals('test'));
        expect(user.properties['number'], equals(42));
        expect(user.properties['boolean'], equals(true));
        expect(user.properties['null_value'], isNull);
        expect(user.properties['list'], equals([1, 2, 3]));
        expect(user.properties['map'], equals({'nested': 'value'}));
      });
    }),

    group('Client Initialization Tests', () {
      test('should initialize CFClient with configuration and user', () async {
        // Given
        final config = CFConfig.builder('test-client-key')
            .setOfflineMode(true)
            .setDebugLoggingEnabled(true)
            .build();
        final user = CFUser(userCustomerId: 'test-user-123');

        // When
        final client = await CFClient.initialize(config, user);

        // Then
        expect(client, isNotNull);
      });

      test('should handle client singleton behavior', () async {
        // Given
        final config = CFConfig.builder('test-client-key')
            .setOfflineMode(true)
            .build();
        final user = CFUser(userCustomerId: 'test-user-123');

        // When
        final client1 = await CFClient.initialize(config, user);
        final client2 = await CFClient.initialize(config, user);

        // Then
        expect(identical(client1, client2), isTrue);
      });

      test('should handle client operations', () async {
        // Given
        final config = CFConfig.builder('test-client-key')
            .setOfflineMode(true)
            .build();
        final user = CFUser(userCustomerId: 'test-user-123');
        final client = await CFClient.initialize(config, user);

        // When & Then - Should not throw errors
        expect(() => client.getString('test_flag', 'default'), returnsNormally);
        expect(() => client.getBoolean('test_bool', false), returnsNormally);
        expect(() => client.getNumber('test_number', 42), returnsNormally);
        expect(() => client.getJson('test_json', {}), returnsNormally);
      });
    }),

    group('Event Tracking Tests', () {
      test('should track events without errors', () async {
        // Given
        final config = CFConfig.builder('test-client-key')
            .setOfflineMode(true)
            .build();
        final user = CFUser(userCustomerId: 'test-user-123');
        final client = await CFClient.initialize(config, user);

        // When & Then - Should not throw errors
        expect(() => client.trackEvent('test_event'), returnsNormally);
        expect(() => client.trackEvent('test_event_with_props', properties: {'key': 'value'}), returnsNormally);
      });

      test('should handle various event property types', () async {
        // Given
        final config = CFConfig.builder('test-client-key')
            .setOfflineMode(true)
            .build();
        final user = CFUser(userCustomerId: 'test-user-123');
        final client = await CFClient.initialize(config, user);

        final properties = {
          'string_prop': 'test_string',
          'number_prop': 42,
          'boolean_prop': true,
          'null_prop': null,
          'list_prop': [1, 2, 3],
          'map_prop': {'nested': 'value'},
        };

        // When & Then - Should not throw errors
        expect(() => client.trackEvent('mixed_types_event', properties: properties), returnsNormally);
      });

      test('should handle edge case event names', () async {
        // Given
        final config = CFConfig.builder('test-client-key')
            .setOfflineMode(true)
            .build();
        final user = CFUser(userCustomerId: 'test-user-123');
        final client = await CFClient.initialize(config, user);

        final edgeCaseNames = [
          'event with spaces',
          'event-with-dashes',
          'event_with_underscores',
          'event.with.dots',
          'event123with456numbers',
          'EventWithCamelCase',
          '🎉emoji_event🚀',
        ];

        // When & Then - Should not throw errors
        for (final eventName in edgeCaseNames) {
          expect(() => client.trackEvent(eventName), returnsNormally);
        }
      });

      test('should handle Unicode characters', () async {
        // Given
        final config = CFConfig.builder('test-client-key')
            .setOfflineMode(true)
            .build();
        final user = CFUser(userCustomerId: 'test-user-123');
        final client = await CFClient.initialize(config, user);

        final unicodeProperties = {
          'chinese': '你好世界',
          'arabic': 'مرحبا بالعالم',
          'emoji': '🌍🚀💫',
          'japanese': 'こんにちは世界',
          'russian': 'Привет мир',
        };

        // When & Then - Should not throw errors
        expect(() => client.trackEvent('unicode_test', properties: unicodeProperties), returnsNormally);
      });
    }),

    group('Configuration Edge Cases', () {
      test('should handle special client keys', () {
        final specialKeys = [
          'key-with-dashes',
          'key_with_underscores',
          'key.with.dots',
          'key123with456numbers',
          'KeyWithCamelCase',
          'very_long_client_key_that_exceeds_normal_length_expectations',
        ];

        for (final key in specialKeys) {
          final config = CFConfig.fromClientKey(key);
          expect(config.clientKey, equals(key));
        }
      });

      test('should handle all boolean combinations', () {
        final booleanCombinations = [
          [true, true, true],
          [true, true, false],
          [true, false, true],
          [true, false, false],
          [false, true, true],
          [false, true, false],
          [false, false, true],
          [false, false, false],
        ];

        for (final combination in booleanCombinations) {
          final config = CFConfig.builder('test-key')
              .setLoggingEnabled(combination[0])
              .setDebugLoggingEnabled(combination[1])
              .setOfflineMode(combination[2])
              .build();

          expect(config.loggingEnabled, equals(combination[0]));
          expect(config.debugLoggingEnabled, equals(combination[1]));
          expect(config.offlineMode, equals(combination[2]));
        }
      });

      test('should handle builder method chaining', () {
        // Test that all builder methods return the builder instance for chaining
        final builder = CFConfig.builder('test-key');

        expect(builder.setEventsQueueSize(10), equals(builder));
        expect(builder.setEventsFlushTimeSeconds(30), equals(builder));
        expect(builder.setMaxRetryAttempts(3), equals(builder));
        expect(builder.setLoggingEnabled(true), equals(builder));
        expect(builder.setDebugLoggingEnabled(false), equals(builder));
        expect(builder.setOfflineMode(false), equals(builder));
      });

      test('should handle configuration consistency across multiple builds', () {
        // Build the same configuration multiple times
        final configs = List.generate(10, (index) {
          return CFConfig.builder('test-key')
              .setEventsQueueSize(50)
              .setLoggingEnabled(true)
              .setOfflineMode(false)
              .build();
        });

        // All configs should have the same values
        for (final config in configs) {
          expect(config.clientKey, equals('test-key'));
          expect(config.eventsQueueSize, equals(50));
          expect(config.loggingEnabled, isTrue);
          expect(config.offlineMode, isFalse);
        }

        // But should be different instances
        for (int i = 0; i < configs.length - 1; i++) {
          expect(identical(configs[i], configs[i + 1]), isFalse);
        }
      });
    }),

    group('User Edge Cases', () {
      test('should handle user with Unicode properties', () {
        final unicodeUser = CFUser(
          userCustomerId: 'test-user-🚀',
          properties: {
            'name_chinese': '张三',
            'name_arabic': 'أحمد',
            'name_emoji': '🎉 John 🎊',
          },
        );

        expect(unicodeUser.userCustomerId, equals('test-user-🚀'));
        expect(unicodeUser.properties['name_chinese'], equals('张三'));
        expect(unicodeUser.properties['name_arabic'], equals('أحمد'));
        expect(unicodeUser.properties['name_emoji'], equals('🎉 John 🎊'));
      });

      test('should handle user with complex nested properties', () {
        final complexUser = CFUser(
          userCustomerId: 'complex-user',
          properties: {
            'profile': {
              'personal': {
                'name': 'John Doe',
                'age': 30,
                'preferences': {
                  'theme': 'dark',
                  'notifications': true,
                  'languages': ['en', 'es', 'fr'],
                },
              },
              'professional': {
                'title': 'Software Engineer',
                'company': 'Tech Corp',
                'skills': ['Flutter', 'Dart', 'JavaScript'],
              },
            },
            'metadata': {
              'created_at': DateTime.now().toIso8601String(),
              'version': '1.0.0',
              'features_enabled': ['feature_a', 'feature_b'],
            },
          },
        );

        expect(complexUser.userCustomerId, equals('complex-user'));
        expect(complexUser.properties['profile'], isA<Map>());
        expect(complexUser.properties['metadata'], isA<Map>());
      });
    }),

    group('Performance Tests', () {
      test('should handle multiple rapid operations', () async {
        // Given
        final config = CFConfig.builder('test-client-key')
            .setOfflineMode(true)
            .build();
        final user = CFUser(userCustomerId: 'test-user-123');
        final client = await CFClient.initialize(config, user);

        // When & Then - Should not throw errors
        expect(() {
          for (int i = 0; i < 100; i++) {
            client.getString('test_flag_$i', 'default');
            client.getBoolean('test_bool_$i', false);
            client.trackEvent('test_event_$i');
          }
        }, returnsNormally);
      });

      test('should handle large property objects', () async {
        // Given
        final config = CFConfig.builder('test-client-key')
            .setOfflineMode(true)
            .build();
        final user = CFUser(userCustomerId: 'test-user-123');
        final client = await CFClient.initialize(config, user);

        final largeProperties = <String, dynamic>{};
        for (int i = 0; i < 100; i++) {
          largeProperties['prop_$i'] = 'value_$i';
        }

        // When & Then - Should not throw errors
        expect(() => client.trackEvent('large_props_test', properties: largeProperties), returnsNormally);
      });
    }),
  });
} 