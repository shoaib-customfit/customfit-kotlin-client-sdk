import 'package:flutter_test/flutter_test.dart';
import '../lib/src/core/model/cf_user.dart';
import '../lib/src/core/model/evaluation_context.dart';
import '../lib/src/core/model/context_type.dart';
import '../lib/src/core/model/device_context.dart';
import '../lib/src/core/model/application_info.dart';
import '../lib/src/core/model/private_attributes_request.dart';
import '../lib/src/config/core/cf_config.dart';

void main() {
  group('CustomFit Flutter SDK - Comprehensive Test Suite', () {
    
    // CFUser Tests
    group('CFUser Tests', () {
      test('Test CFUser creation with basic properties', () {
        final user = CFUser(
          userCustomerId: 'test-user-123',
          anonymous: false,
          properties: {'name': 'John Doe', 'age': 30},
        );

        expect(user.userCustomerId, equals('test-user-123'));
        expect(user.anonymous, isFalse);
        expect(user.properties['name'], equals('John Doe'));
        expect(user.properties['age'], equals(30));
        expect(user.contexts, isEmpty);
        expect(user.device, isNull);
        expect(user.application, isNull);
      });

      test('Test anonymous user creation', () {
        final user = CFUser(anonymous: true);

        expect(user.userCustomerId, isNull);
        expect(user.anonymous, isTrue);
        expect(user.properties, isEmpty);
      });

      test('Test CFUser property operations (immutability)', () {
        final originalUser = CFUser(userCustomerId: 'test-user');
        final updatedUser = originalUser.addProperty('newProp', 'newValue');

        // Original should be unchanged (immutability)
        expect(originalUser.properties.containsKey('newProp'), isFalse);
        
        // Updated user should have new property
        expect(updatedUser.properties['newProp'], equals('newValue'));
        expect(updatedUser.userCustomerId, equals('test-user'));
      });

      test('Test CFUser with device context', () {
        final deviceContext = DeviceContext(
          manufacturer: 'Google',
          model: 'Pixel 6',
          osName: 'Android',
          osVersion: '12',
        );
        final user = CFUser(userCustomerId: 'test-user', device: deviceContext);

        expect(user.device, isNotNull);
        expect(user.device!.manufacturer, equals('Google'));
        expect(user.device!.model, equals('Pixel 6'));
      });

      test('Test CFUser with application info', () {
        final appInfo = ApplicationInfo(
          appName: 'TestApp',
          versionName: '1.0.0',
          packageName: 'com.test.app',
        );
        final user = CFUser(userCustomerId: 'test-user', application: appInfo);

        expect(user.application, isNotNull);
        expect(user.application!.appName, equals('TestApp'));
        expect(user.application!.versionName, equals('1.0.0'));
      });

      test('Test CFUser with evaluation context', () {
        final context = EvaluationContext(
          type: ContextType.custom,
          key: 'test-context',
          properties: {'attr1': 'value1'},
        );
        final user = CFUser(userCustomerId: 'test-user', contexts: [context]);

        expect(user.contexts, hasLength(1));
        expect(user.contexts.first.key, equals('test-context'));
        expect(user.contexts.first.type, equals(ContextType.custom));
      });

      test('Test CFUser toMap conversion', () {
        final user = CFUser(
          userCustomerId: 'test-user',
          anonymous: false,
          properties: {'name': 'John', 'age': 25},
        );

        final userMap = user.toMap();

        expect(userMap['user_customer_id'], equals('test-user'));
        expect(userMap['anonymous'], isFalse);
        expect(userMap['properties']['name'], equals('John'));
        expect(userMap['properties']['age'], equals(25));
      });

      test('Test CFUser fromMap factory', () {
        final map = {
          'user_customer_id': 'test-user',
          'anonymous': false,
          'properties': {'name': 'John', 'age': 30},
          'contexts': [],
        };

        final user = CFUser.fromMap(map);

        expect(user.userCustomerId, equals('test-user'));
        expect(user.anonymous, isFalse);
        expect(user.properties['name'], equals('John'));
        expect(user.properties['age'], equals(30));
      });
    });

    // CFConfig Tests
    group('CFConfig Tests', () {
      test('Test CFConfig creation with default values', () {
        final config = CFConfig.fromClientKey('test-client-key');

        expect(config.clientKey, equals('test-client-key'));
        expect(config.eventsQueueSize, equals(10));
        expect(config.eventsFlushTimeSeconds, equals(30));
        expect(config.maxRetryAttempts, equals(3));
        expect(config.loggingEnabled, isTrue);
        expect(config.debugLoggingEnabled, isFalse);
        expect(config.offlineMode, isFalse);
      });

      test('Test CFConfig builder pattern', () {
        final config = Builder('test-key')
            .setEventsQueueSize(50)
            .setEventsFlushTimeSeconds(60)
            .setMaxRetryAttempts(5)
            .setLoggingEnabled(false)
            .setDebugLoggingEnabled(true)
            .setOfflineMode(true)
            .build();

        expect(config.clientKey, equals('test-key'));
        expect(config.eventsQueueSize, equals(50));
        expect(config.eventsFlushTimeSeconds, equals(60));
        expect(config.maxRetryAttempts, equals(5));
        expect(config.loggingEnabled, isFalse);
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.offlineMode, isTrue);
      });

      test('Test CFConfig builder validation', () {
        expect(
          () => Builder(''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Test CFConfig network settings', () {
        final config = Builder('test-key')
            .setNetworkConnectionTimeoutMs(5000)
            .setNetworkReadTimeoutMs(15000)
            .build();

        expect(config.networkConnectionTimeoutMs, equals(5000));
        expect(config.networkReadTimeoutMs, equals(15000));
      });
    });

    // DeviceContext Tests  
    group('DeviceContext Tests', () {
      test('Test DeviceContext creation', () {
        final deviceContext = DeviceContext(
          manufacturer: 'Samsung',
          model: 'Galaxy S21',
          osName: 'Android',
          osVersion: '11',
        );

        expect(deviceContext.manufacturer, equals('Samsung'));
        expect(deviceContext.model, equals('Galaxy S21'));
        expect(deviceContext.osName, equals('Android'));
        expect(deviceContext.osVersion, equals('11'));
      });

      test('Test DeviceContext toMap', () {
        final deviceContext = DeviceContext(
          manufacturer: 'Apple',
          model: 'iPhone 13',
          osName: 'iOS',
          osVersion: '15.0',
        );

        final map = deviceContext.toMap();

        expect(map['manufacturer'], equals('Apple'));
        expect(map['model'], equals('iPhone 13'));
        expect(map['os_name'], equals('iOS'));
        expect(map['os_version'], equals('15.0'));
      });

      test('Test DeviceContext fromMap', () {
        final map = {
          'manufacturer': 'Google',
          'model': 'Pixel 6',
          'os_name': 'Android',
          'os_version': '12',
        };

        final deviceContext = DeviceContext.fromMap(map);

        expect(deviceContext.manufacturer, equals('Google'));
        expect(deviceContext.model, equals('Pixel 6'));
        expect(deviceContext.osName, equals('Android'));
        expect(deviceContext.osVersion, equals('12'));
      });
    });

    // ApplicationInfo Tests
    group('ApplicationInfo Tests', () {
      test('Test ApplicationInfo creation', () {
        final appInfo = ApplicationInfo(
          appName: 'MyApp',
          packageName: 'com.example.myapp',
          versionName: '2.0.0',
          versionCode: 20,
        );

        expect(appInfo.appName, equals('MyApp'));
        expect(appInfo.packageName, equals('com.example.myapp'));
        expect(appInfo.versionName, equals('2.0.0'));
        expect(appInfo.versionCode, equals(20));
      });

      test('Test ApplicationInfo toMap', () {
        final appInfo = ApplicationInfo(
          appName: 'TestApp',
          versionName: '1.0.0',
          packageName: 'com.test.app',
        );

        final map = appInfo.toMap();

        expect(map['app_name'], equals('TestApp'));
        expect(map['version_name'], equals('1.0.0'));
        expect(map['package_name'], equals('com.test.app'));
      });

      test('Test ApplicationInfo fromMap', () {
        final map = {
          'app_name': 'DemoApp',
          'version_name': '3.0.0',
          'package_name': 'com.demo.app',
          'version_code': 30,
        };

        final appInfo = ApplicationInfo.fromMap(map);

        expect(appInfo.appName, equals('DemoApp'));
        expect(appInfo.versionName, equals('3.0.0'));
        expect(appInfo.packageName, equals('com.demo.app'));
        expect(appInfo.versionCode, equals(30));
      });
    });

    // EvaluationContext Tests
    group('EvaluationContext Tests', () {
      test('Test EvaluationContext creation', () {
        final context = EvaluationContext(
          type: ContextType.user,
          key: 'user-123',
          name: 'Main User Context',
          properties: {'role': 'admin', 'department': 'engineering'},
          privateAttributes: ['email'],
        );

        expect(context.type, equals(ContextType.user));
        expect(context.key, equals('user-123'));
        expect(context.name, equals('Main User Context'));
        expect(context.properties['role'], equals('admin'));
        expect(context.properties['department'], equals('engineering'));
        expect(context.privateAttributes, contains('email'));
      });

      test('Test EvaluationContext toMap', () {
        final context = EvaluationContext(
          type: ContextType.session,
          key: 'session-456',
          properties: {'duration': '30min'},
        );

        final map = context.toMap();

        expect(map['type'], equals('session'));
        expect(map['key'], equals('session-456'));
        expect(map['properties']['duration'], equals('30min'));
      });

      test('Test EvaluationContext fromMap', () {
        final map = {
          'type': 'custom',
          'key': 'custom-context',
          'name': 'Custom Context',
          'properties': {'level': 'premium'},
          'private_attributes': ['sensitive_data'],
        };

        final context = EvaluationContext.fromMap(map);

        expect(context.type, equals(ContextType.custom));
        expect(context.key, equals('custom-context'));
        expect(context.name, equals('Custom Context'));
        expect(context.properties['level'], equals('premium'));
        expect(context.privateAttributes, contains('sensitive_data'));
      });
    });

    // PrivateAttributesRequest Tests
    group('PrivateAttributesRequest Tests', () {
      test('Test PrivateAttributesRequest creation', () {
        final privateAttrs = PrivateAttributesRequest(
          userFields: ['email', 'phone'],
          properties: {'type': 'sensitive'},
        );

        expect(privateAttrs.userFields, containsAll(['email', 'phone']));
        expect(privateAttrs.properties['type'], equals('sensitive'));
      });

      test('Test PrivateAttributesRequest toMap', () {
        final privateAttrs = PrivateAttributesRequest(
          userFields: ['ssn', 'credit_card'],
          properties: {'category': 'pii'},
        );

        final map = privateAttrs.toMap();

        expect(map['user_fields'], containsAll(['ssn', 'credit_card']));
        expect(map['properties']['category'], equals('pii'));
      });

      test('Test PrivateAttributesRequest fromMap', () {
        final map = {
          'user_fields': ['password', 'token'],
          'properties': {'level': 'high'},
        };

        final privateAttrs = PrivateAttributesRequest.fromMap(map);

        expect(privateAttrs.userFields, containsAll(['password', 'token']));
        expect(privateAttrs.properties['level'], equals('high'));
      });
    });

    // Integration Tests
    group('Integration Tests', () {
      test('Test complete user with all components', () {
        final deviceContext = DeviceContext(
          manufacturer: 'Apple',
          model: 'iPhone 13',
          osName: 'iOS',
          osVersion: '15.0',
        );

        final appInfo = ApplicationInfo(
          appName: 'TestApp',
          versionName: '1.0.0',
          packageName: 'com.test.app',
        );

        final context = EvaluationContext(
          type: ContextType.user,
          key: 'user-context',
          properties: {'premium': true},
        );

        final privateFields = PrivateAttributesRequest(
          userFields: ['email'],
          properties: {'type': 'pii'},
        );

        final user = CFUser(
          userCustomerId: 'test-user-123',
          anonymous: false,
          properties: {'name': 'John Doe', 'age': 30},
          contexts: [context],
          device: deviceContext,
          application: appInfo,
          privateFields: privateFields,
        );

        // Verify all components are properly integrated
        expect(user.userCustomerId, equals('test-user-123'));
        expect(user.device?.manufacturer, equals('Apple'));
        expect(user.application?.appName, equals('TestApp'));
        expect(user.contexts.first.key, equals('user-context'));
        expect(user.privateFields?.userFields, contains('email'));

        // Test serialization
        final userMap = user.toMap();
        expect(userMap['user_customer_id'], equals('test-user-123'));
        expect(userMap['properties']['device']['manufacturer'], equals('Apple'));
        expect(userMap['private_fields'], isNotNull);
      });

      test('Test immutability across all operations', () {
        final originalUser = CFUser(userCustomerId: 'test-user');
        
        final userWithProperty = originalUser.addProperty('prop1', 'value1');
        final userWithContext = userWithProperty.addContext(
          EvaluationContext(type: ContextType.custom, key: 'ctx1'),
        );
        final userWithDevice = userWithContext.withDeviceContext(
          DeviceContext(manufacturer: 'Test', model: 'Device'),
        );
        final userWithApp = userWithDevice.withApplicationInfo(
          ApplicationInfo(appName: 'TestApp'),
        );

        // All instances should be different
        expect(identical(originalUser, userWithProperty), isFalse);
        expect(identical(userWithProperty, userWithContext), isFalse);
        expect(identical(userWithContext, userWithDevice), isFalse);
        expect(identical(userWithDevice, userWithApp), isFalse);

        // Original should remain unchanged
        expect(originalUser.properties, isEmpty);
        expect(originalUser.contexts, isEmpty);
        expect(originalUser.device, isNull);
        expect(originalUser.application, isNull);

        // Final user should have all modifications
        expect(userWithApp.properties['prop1'], equals('value1'));
        expect(userWithApp.contexts, hasLength(1));
        expect(userWithApp.device?.manufacturer, equals('Test'));
        expect(userWithApp.application?.appName, equals('TestApp'));
      });
    });
  });
} 