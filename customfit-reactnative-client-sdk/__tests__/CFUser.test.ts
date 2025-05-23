import { CFUserImpl, CFUserBuilderImpl } from '../src/core/model/CFUser';
import { CFUser, CFUserBuilder } from '../src/core/types/CFTypes';

describe('CFUser Tests', () => {
  describe('CFUserImpl', () => {
    test('should create CFUser with basic properties', () => {
      const user = new CFUserImpl(
        'test-user-123',
        'anon-123',
        'device-456',
        false,
        { name: 'John Doe', age: 30 }
      );

      expect(user.userCustomerId).toBe('test-user-123');
      expect(user.anonymousId).toBe('anon-123');
      expect(user.deviceId).toBe('device-456');
      expect(user.anonymous).toBe(false);
      expect(user.properties).toEqual({ name: 'John Doe', age: 30 });
    });

    test('should create anonymous user with default values', () => {
      const user = new CFUserImpl();

      expect(user.userCustomerId).toBeUndefined();
      expect(user.anonymousId).toBeUndefined();
      expect(user.deviceId).toBeUndefined();
      expect(user.anonymous).toBe(false);
      expect(user.properties).toEqual({});
    });

    test('should create anonymous user when anonymous flag is true', () => {
      const user = new CFUserImpl(undefined, 'anon-123', undefined, true);

      expect(user.userCustomerId).toBeUndefined();
      expect(user.anonymousId).toBe('anon-123');
      expect(user.anonymous).toBe(true);
    });

    test('should return new instance when updating user customer ID (immutability)', () => {
      const originalUser = new CFUserImpl('user-1', 'anon-1', 'device-1', false, { prop: 'value' });
      const updatedUser = originalUser.withUserCustomerId('user-2');

      // Original should be unchanged
      expect(originalUser.userCustomerId).toBe('user-1');
      
      // New instance should have updated value
      expect(updatedUser.userCustomerId).toBe('user-2');
      expect(updatedUser.anonymousId).toBe('anon-1');
      expect(updatedUser.deviceId).toBe('device-1');
      expect(updatedUser.properties).toEqual({ prop: 'value' });
      
      // Should be different instances
      expect(originalUser).not.toBe(updatedUser);
    });

    test('should return new instance when updating anonymous ID', () => {
      const originalUser = new CFUserImpl('user-1', 'anon-1');
      const updatedUser = originalUser.withAnonymousId('anon-2');

      expect(originalUser.anonymousId).toBe('anon-1');
      expect(updatedUser.anonymousId).toBe('anon-2');
      expect(updatedUser.userCustomerId).toBe('user-1');
      expect(originalUser).not.toBe(updatedUser);
    });

    test('should return new instance when updating device ID', () => {
      const originalUser = new CFUserImpl('user-1', 'anon-1', 'device-1');
      const updatedUser = originalUser.withDeviceId('device-2');

      expect(originalUser.deviceId).toBe('device-1');
      expect(updatedUser.deviceId).toBe('device-2');
      expect(updatedUser.userCustomerId).toBe('user-1');
      expect(originalUser).not.toBe(updatedUser);
    });

    test('should return new instance when updating anonymous status', () => {
      const originalUser = new CFUserImpl('user-1', 'anon-1', 'device-1', false);
      const updatedUser = originalUser.withAnonymous(true);

      expect(originalUser.anonymous).toBe(false);
      expect(updatedUser.anonymous).toBe(true);
      expect(updatedUser.userCustomerId).toBe('user-1');
      expect(originalUser).not.toBe(updatedUser);
    });

    test('should return new instance when updating properties', () => {
      const originalUser = new CFUserImpl('user-1', undefined, undefined, false, { prop1: 'value1' });
      const updatedUser = originalUser.withProperties({ prop2: 'value2', prop3: 'value3' });

      expect(originalUser.properties).toEqual({ prop1: 'value1' });
      expect(updatedUser.properties).toEqual({ prop1: 'value1', prop2: 'value2', prop3: 'value3' });
      expect(originalUser).not.toBe(updatedUser);
    });

    test('should return new instance when updating single property', () => {
      const originalUser = new CFUserImpl('user-1', undefined, undefined, false, { prop1: 'value1' });
      const updatedUser = originalUser.withProperty('prop2', 'value2');

      expect(originalUser.properties).toEqual({ prop1: 'value1' });
      expect(updatedUser.properties).toEqual({ prop1: 'value1', prop2: 'value2' });
      expect(originalUser).not.toBe(updatedUser);
    });

    test('should overwrite existing property when using withProperty', () => {
      const originalUser = new CFUserImpl('user-1', undefined, undefined, false, { prop1: 'value1' });
      const updatedUser = originalUser.withProperty('prop1', 'new-value');

      expect(originalUser.properties).toEqual({ prop1: 'value1' });
      expect(updatedUser.properties).toEqual({ prop1: 'new-value' });
    });

    test('should generate correct user map for API calls', () => {
      const user = new CFUserImpl(
        'test-user-123',
        'anon-456',
        'device-789',
        false,
        { name: 'John', age: 30, premium: true }
      );

      const userMap = user.toUserMap();

      expect(userMap).toEqual({
        user_customer_id: 'test-user-123',
        anonymous_id: 'anon-456',
        anonymous: false,
        properties: {
          name: 'John',
          age: 30,
          premium: true,
          device: {
            device_id: 'device-789',
            os_name: 'React Native',
            sdk_type: 'react-native',
            sdk_version: '1.0.0',
          },
        },
      });
    });

    test('should generate user map without optional fields when not provided', () => {
      const user = new CFUserImpl(undefined, undefined, 'device-123', true, { prop: 'value' });

      const userMap = user.toUserMap();

      expect(userMap).toEqual({
        anonymous: true,
        properties: {
          prop: 'value',
          device: {
            device_id: 'device-123',
            os_name: 'React Native',
            sdk_type: 'react-native',
            sdk_version: '1.0.0',
          },
        },
      });
      expect(userMap.user_customer_id).toBeUndefined();
      expect(userMap.anonymous_id).toBeUndefined();
    });

    test('should create default user', () => {
      const user = CFUserImpl.defaultUser();

      expect(user.userCustomerId).toBeUndefined();
      expect(user.anonymousId).toBeUndefined();
      expect(user.deviceId).toBeUndefined();
      expect(user.anonymous).toBe(false);
      expect(user.properties).toEqual({});
    });

    test('should create builder instance', () => {
      const builder = CFUserImpl.builder('test-user');

      expect(builder).toBeInstanceOf(CFUserBuilderImpl);
    });
  });

  describe('CFUserBuilderImpl', () => {
    test('should build user with all properties set via builder', () => {
      const user = new CFUserBuilderImpl('test-user')
        .anonymousId('anon-123')
        .deviceId('device-456')
        .anonymous(false)
        .property('name', 'John')
        .property('age', 30)
        .properties({ department: 'engineering', level: 'senior' })
        .build();

      expect(user.userCustomerId).toBe('test-user');
      expect(user.anonymousId).toBe('anon-123');
      expect(user.deviceId).toBe('device-456');
      expect(user.anonymous).toBe(false);
      expect(user.properties).toEqual({
        name: 'John',
        age: 30,
        department: 'engineering',
        level: 'senior',
      });
    });

    test('should build user with only required properties', () => {
      const user = new CFUserBuilderImpl('test-user').build();

      expect(user.userCustomerId).toBe('test-user');
      expect(user.anonymousId).toBeUndefined();
      expect(user.deviceId).toBeUndefined();
      expect(user.anonymous).toBe(false);
      expect(user.properties).toEqual({});
    });

    test('should support fluent API chaining', () => {
      const builder = new CFUserBuilderImpl()
        .userCustomerId('user-123')
        .anonymousId('anon-456')
        .deviceId('device-789')
        .anonymous(true);

      expect(builder).toBeInstanceOf(CFUserBuilderImpl);

      const user = builder.build();
      expect(user.userCustomerId).toBe('user-123');
      expect(user.anonymousId).toBe('anon-456');
      expect(user.deviceId).toBe('device-789');
      expect(user.anonymous).toBe(true);
    });

    test('should handle property overwrites correctly', () => {
      const user = new CFUserBuilderImpl('test-user')
        .property('name', 'John')
        .property('name', 'Jane') // Overwrite
        .properties({ name: 'Bob', age: 30 }) // Overwrite again
        .build();

      expect(user.properties).toEqual({ name: 'Bob', age: 30 });
    });

    test('should merge properties correctly', () => {
      const user = new CFUserBuilderImpl('test-user')
        .properties({ prop1: 'value1', prop2: 'value2' })
        .properties({ prop2: 'updated', prop3: 'value3' })
        .property('prop4', 'value4')
        .build();

      expect(user.properties).toEqual({
        prop1: 'value1',
        prop2: 'updated',
        prop3: 'value3',
        prop4: 'value4',
      });
    });

    test('should handle null and undefined values', () => {
      const user = new CFUserBuilderImpl('test-user')
        .property('nullProp', null)
        .property('undefinedProp', undefined)
        .property('zeroProp', 0)
        .property('falseProp', false)
        .property('emptyStringProp', '')
        .build();

      expect(user.properties).toEqual({
        nullProp: null,
        undefinedProp: undefined,
        zeroProp: 0,
        falseProp: false,
        emptyStringProp: '',
      });
    });

    test('should handle complex object properties', () => {
      const complexObject = {
        nested: { value: 'test' },
        array: [1, 2, 3],
        date: new Date('2023-01-01'),
      };

      const user = new CFUserBuilderImpl('test-user')
        .property('complex', complexObject)
        .build();

      expect(user.properties?.complex).toEqual(complexObject);
    });
  });

  describe('Immutability', () => {
    test('should maintain immutability across multiple operations', () => {
      const originalUser = new CFUserImpl('user-1', 'anon-1', 'device-1', false, { prop1: 'value1' });

      const user2 = originalUser.withUserCustomerId('user-2');
      const user3 = user2.withProperty('prop2', 'value2');
      const user4 = user3.withAnonymous(true);
      const user5 = user4.withDeviceId('device-2');

      // All should be different instances
      expect(originalUser).not.toBe(user2);
      expect(user2).not.toBe(user3);
      expect(user3).not.toBe(user4);
      expect(user4).not.toBe(user5);

      // Original should remain unchanged
      expect(originalUser.userCustomerId).toBe('user-1');
      expect(originalUser.anonymousId).toBe('anon-1');
      expect(originalUser.deviceId).toBe('device-1');
      expect(originalUser.anonymous).toBe(false);
      expect(originalUser.properties).toEqual({ prop1: 'value1' });

      // Final user should have all changes
      expect(user5.userCustomerId).toBe('user-2');
      expect(user5.anonymousId).toBe('anon-1');
      expect(user5.deviceId).toBe('device-2');
      expect(user5.anonymous).toBe(true);
      expect(user5.properties).toEqual({ prop1: 'value1', prop2: 'value2' });
    });

    test('should not mutate original properties object', () => {
      const originalProps = { prop1: 'value1' };
      const user = new CFUserImpl('user-1', undefined, undefined, false, originalProps);
      
      user.withProperty('prop2', 'value2');

      // Original properties object should not be modified
      expect(originalProps).toEqual({ prop1: 'value1' });
      expect(user.properties).toEqual({ prop1: 'value1' });
    });
  });

  describe('Type Safety', () => {
    test('should handle different property value types', () => {
      const user = new CFUserImpl('user-1', undefined, undefined, false, {
        stringProp: 'string value',
        numberProp: 42,
        booleanProp: true,
        objectProp: { nested: 'value' },
        arrayProp: [1, 2, 3],
        dateProp: new Date('2023-01-01'),
        nullProp: null,
        undefinedProp: undefined,
      });

      expect(typeof user.properties?.stringProp).toBe('string');
      expect(typeof user.properties?.numberProp).toBe('number');
      expect(typeof user.properties?.booleanProp).toBe('boolean');
      expect(typeof user.properties?.objectProp).toBe('object');
      expect(Array.isArray(user.properties?.arrayProp)).toBe(true);
      expect(user.properties?.dateProp).toBeInstanceOf(Date);
      expect(user.properties?.nullProp).toBeNull();
      expect(user.properties?.undefinedProp).toBeUndefined();
    });
  });
}); 