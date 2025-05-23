import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_flutter_client_sdk/src/core/model/cf_user.dart';
import 'package:customfit_flutter_client_sdk/src/core/model/evaluation_context.dart';
import 'package:customfit_flutter_client_sdk/src/core/model/device_context.dart';
import 'package:customfit_flutter_client_sdk/src/core/model/application_info.dart';
import 'package:customfit_flutter_client_sdk/src/core/model/private_attributes_request.dart';

void main() {
  group('CFUser Tests', () {
    test('should create CFUser with basic properties', () {
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

    test('should create anonymous user', () {
      final user = CFUser(anonymous: true);

      expect(user.userCustomerId, isNull);
      expect(user.anonymous, isTrue);
      expect(user.properties, isEmpty);
    });

    test('should add property and return new instance', () {
      final originalUser = CFUser(userCustomerId: 'test-user');
      final updatedUser = originalUser.addProperty('newProp', 'newValue');

      // Original should be unchanged (immutability)
      expect(originalUser.properties.containsKey('newProp'), isFalse);
      
      // Updated user should have new property
      expect(updatedUser.properties['newProp'], equals('newValue'));
      expect(updatedUser.userCustomerId, equals('test-user'));
    });

    test('should add context and return new instance', () {
      final originalUser = CFUser(userCustomerId: 'test-user');
      final context = EvaluationContext(
        type: ContextType.custom,
        key: 'test-context',
        properties: {'attr1': 'value1'},
      );
      final updatedUser = originalUser.addContext(context);

      // Original should be unchanged
      expect(originalUser.contexts, isEmpty);
      
      // Updated user should have new context
      expect(updatedUser.contexts, hasLength(1));
      expect(updatedUser.contexts.first.key, equals('test-context'));
      expect(updatedUser.contexts.first.type, equals(ContextType.custom));
    });

    test('should set device context and return new instance', () {
      final originalUser = CFUser(userCustomerId: 'test-user');
      final deviceContext = DeviceContext(
        manufacturer: 'Google',
        model: 'Pixel 6',
        osName: 'Android',
        osVersion: '12',
      );
      final updatedUser = originalUser.withDeviceContext(deviceContext);

      // Original should be unchanged
      expect(originalUser.device, isNull);
      
      // Updated user should have device context
      expect(updatedUser.device, isNotNull);
      expect(updatedUser.device!.manufacturer, equals('Google'));
      expect(updatedUser.device!.model, equals('Pixel 6'));
    });

    test('should set application info and return new instance', () {
      final originalUser = CFUser(userCustomerId: 'test-user');
      final appInfo = ApplicationInfo(
        appName: 'TestApp',
        versionName: '1.0.0',
        packageName: 'com.test.app',
      );
      final updatedUser = originalUser.withApplicationInfo(appInfo);

      // Original should be unchanged
      expect(originalUser.application, isNull);
      
      // Updated user should have application info
      expect(updatedUser.application, isNotNull);
      expect(updatedUser.application!.appName, equals('TestApp'));
      expect(updatedUser.application!.versionName, equals('1.0.0'));
    });

    test('should convert to map correctly', () {
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

    test('should include contexts in map when present', () {
      final context = EvaluationContext(
        type: ContextType.user,
        key: 'user-context',
        properties: {'level': 'premium'},
      );
      final user = CFUser(
        userCustomerId: 'test-user',
        contexts: [context],
      );

      final userMap = user.toMap();
      final properties = userMap['properties'] as Map<String, dynamic>;

      expect(properties['contexts'], isNotNull);
      expect(properties['contexts'], isList);
      expect((properties['contexts'] as List).length, equals(1));
    });

    test('should include device context in map when present', () {
      final deviceContext = DeviceContext(
        manufacturer: 'Apple',
        model: 'iPhone 13',
        osName: 'iOS',
        osVersion: '15.0',
      );
      final user = CFUser(
        userCustomerId: 'test-user',
        device: deviceContext,
      );

      final userMap = user.toMap();
      final properties = userMap['properties'] as Map<String, dynamic>;

      expect(properties['device'], isNotNull);
      expect(properties['device'], isA<Map<String, dynamic>>());
    });

    test('should include application info in map when present', () {
      final appInfo = ApplicationInfo(
        appName: 'TestApp',
        versionName: '2.0.0',
        packageName: 'com.test.app',
      );
      final user = CFUser(
        userCustomerId: 'test-user',
        application: appInfo,
      );

      final userMap = user.toMap();
      final properties = userMap['properties'] as Map<String, dynamic>;

      expect(properties['application'], isNotNull);
      expect(properties['application'], isA<Map<String, dynamic>>());
    });

    test('should handle private and session fields', () {
      final privateFields = PrivateAttributesRequest(
        userFields: ['email', 'phone'],
        properties: {'type': 'private'},
      );
      final sessionFields = PrivateAttributesRequest(
        userFields: ['sessionId'],
        properties: {'type': 'session'},
      );
      final user = CFUser(
        userCustomerId: 'test-user',
        privateFields: privateFields,
        sessionFields: sessionFields,
      );

      final userMap = user.toMap();

      expect(userMap['private_fields'], isNotNull);
      expect(userMap['session_fields'], isNotNull);
    });

    test('should create from map correctly', () {
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
      expect(user.contexts, isEmpty);
    });

    test('should handle null values when creating from map', () {
      final map = <String, dynamic>{
        'user_customer_id': null,
        'anonymous': null,
        'properties': null,
        'contexts': null,
        'device': null,
        'application': null,
      };

      final user = CFUser.fromMap(map);

      expect(user.userCustomerId, isNull);
      expect(user.anonymous, isFalse); // Should default to false
      expect(user.properties, isEmpty); // Should default to empty map
      expect(user.contexts, isEmpty); // Should default to empty list
      expect(user.device, isNull);
      expect(user.application, isNull);
    });

    test('should maintain immutability when adding multiple properties', () {
      final originalUser = CFUser(userCustomerId: 'test-user');
      
      final user1 = originalUser.addProperty('prop1', 'value1');
      final user2 = user1.addProperty('prop2', 'value2');

      // All instances should be different
      expect(identical(originalUser, user1), isFalse);
      expect(identical(user1, user2), isFalse);

      // Each should have their expected properties
      expect(originalUser.properties, isEmpty);
      expect(user1.properties['prop1'], equals('value1'));
      expect(user1.properties.containsKey('prop2'), isFalse);
      expect(user2.properties['prop1'], equals('value1'));
      expect(user2.properties['prop2'], equals('value2'));
    });

    test('should handle different property types', () {
      final user = CFUser(
        userCustomerId: 'test-user',
        properties: {
          'stringProp': 'string value',
          'intProp': 42,
          'doubleProp': 3.14,
          'boolProp': true,
          'listProp': [1, 2, 3],
          'mapProp': {'nested': 'value'},
          'nullProp': null,
        },
      );

      expect(user.properties['stringProp'], isA<String>());
      expect(user.properties['intProp'], isA<int>());
      expect(user.properties['doubleProp'], isA<double>());
      expect(user.properties['boolProp'], isA<bool>());
      expect(user.properties['listProp'], isA<List>());
      expect(user.properties['mapProp'], isA<Map>());
      expect(user.properties['nullProp'], isNull);
    });
  });
} 