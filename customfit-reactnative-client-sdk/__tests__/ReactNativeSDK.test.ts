import { CFUserImpl, CFUserBuilderImpl } from '../src/core/model/CFUser';
import { CFConfigImpl, CFConfigBuilderImpl } from '../src/config/core/CFConfig';
import { CFUser, CFUserBuilder, CFConfig, CFConfigBuilder } from '../src/core/types/CFTypes';

describe('CustomFit React Native SDK - Comprehensive Test Suite', () => {
  
  // CFUser Tests
  describe('CFUser Tests', () => {
    test('Test CFUser creation with basic properties', () => {
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

    test('Test anonymous user creation', () => {
      const user = new CFUserImpl(undefined, 'anon-123', undefined, true);

      expect(user.userCustomerId).toBeUndefined();
      expect(user.anonymousId).toBe('anon-123');
      expect(user.anonymous).toBe(true);
    });

    test('Test CFUser property operations (immutability)', () => {
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

    test('Test CFUser with property updates', () => {
      const originalUser = new CFUserImpl('user-1', undefined, undefined, false, { prop1: 'value1' });
      const updatedUser = originalUser.withProperty('prop2', 'value2');

      expect(originalUser.properties).toEqual({ prop1: 'value1' });
      expect(updatedUser.properties).toEqual({ prop1: 'value1', prop2: 'value2' });
      expect(originalUser).not.toBe(updatedUser);
    });

    test('Test CFUser toUserMap conversion', () => {
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

    test('Test CFUser default user', () => {
      const user = CFUserImpl.defaultUser();

      expect(user.userCustomerId).toBeUndefined();
      expect(user.anonymousId).toBeUndefined();
      expect(user.deviceId).toBeUndefined();
      expect(user.anonymous).toBe(false);
      expect(user.properties).toEqual({});
    });

    test('Test CFUser builder creation', () => {
      const builder = CFUserImpl.builder('test-user');

      expect(builder).toBeInstanceOf(CFUserBuilderImpl);
    });
  });

  // CFUserBuilder Tests
  describe('CFUserBuilder Tests', () => {
    test('Test CFUserBuilder with all properties', () => {
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

    test('Test CFUserBuilder fluent API chaining', () => {
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

    test('Test CFUserBuilder property merging', () => {
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

    test('Test CFUserBuilder with various value types', () => {
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
  });

  // CFConfig Tests
  describe('CFConfig Tests', () => {
    test('Test CFConfig creation with defaults', () => {
      const config = new CFConfigImpl('test-client-key');

      expect(config.clientKey).toBe('test-client-key');
      expect(config.eventsQueueSize).toBe(100); // Actual default from CFConstants
      expect(config.loggingEnabled).toBe(true);
      expect(config.debugLoggingEnabled).toBe(false);
      expect(config.offlineMode).toBe(false);
      expect(config.autoEnvAttributesEnabled).toBe(true);
    });

    test('Test CFConfig creation with custom values', () => {
      const config = new CFConfigImpl(
        'test-client-key',
        50, // eventsQueueSize
        60, // eventsFlushTimeSeconds
        30000, // eventsFlushIntervalMs
        2000, // maxStoredEvents
        5, // maxRetryAttempts
        2000, // retryInitialDelayMs
        60000, // retryMaxDelayMs
        2.0, // retryBackoffMultiplier
        20, // summariesQueueSize
        90, // summariesFlushTimeSeconds
        45000, // summariesFlushIntervalMs
        120000, // sdkSettingsCheckIntervalMs
        15000, // networkConnectionTimeoutMs
        45000, // networkReadTimeoutMs
        false, // loggingEnabled
        true, // debugLoggingEnabled
        'debug', // logLevel
        true, // offlineMode
        true, // disableBackgroundPolling
        600000, // backgroundPollingIntervalMs
        false, // useReducedPollingWhenBatteryLow
        1800000, // reducedPollingIntervalMs
        false // autoEnvAttributesEnabled
      );

      expect(config.clientKey).toBe('test-client-key');
      expect(config.eventsQueueSize).toBe(50);
      expect(config.eventsFlushTimeSeconds).toBe(60);
      expect(config.maxRetryAttempts).toBe(5);
      expect(config.loggingEnabled).toBe(false);
      expect(config.debugLoggingEnabled).toBe(true);
      expect(config.offlineMode).toBe(true);
      expect(config.autoEnvAttributesEnabled).toBe(false);
    });

    test('Test CFConfig builder creation', () => {
      const builder = CFConfigImpl.builder('test-client-key');

      expect(builder).toBeInstanceOf(CFConfigBuilderImpl);
    });

    test('Test CFConfig JWT token parsing', () => {
      // Mock JWT token with dimension_id in payload
      const validToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkaW1lbnNpb25faWQiOiJ0ZXN0LWRpbWVuc2lvbi0xMjMiLCJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      
      const config = new CFConfigImpl(validToken);
      
      expect(config.dimensionId).toBe('test-dimension-123');
    });

    test('Test CFConfig with invalid token', () => {
      const invalidToken = 'invalid-token';
      
      const config = new CFConfigImpl(invalidToken);
      
      expect(config.dimensionId).toBeUndefined();
    });
  });

  // CFConfigBuilder Tests
  describe('CFConfigBuilder Tests', () => {
    test('Test CFConfigBuilder with all properties', () => {
      const config = new CFConfigBuilderImpl('test-client-key')
        .eventsQueueSize(50)
        .eventsFlushTimeSeconds(60)
        .maxRetryAttempts(5)
        .loggingEnabled(false)
        .debugLoggingEnabled(true)
        .offlineMode(true)
        .autoEnvAttributesEnabled(false)
        .build();

      expect(config.clientKey).toBe('test-client-key');
      expect(config.eventsQueueSize).toBe(50);
      expect(config.eventsFlushTimeSeconds).toBe(60);
      expect(config.maxRetryAttempts).toBe(5);
      expect(config.loggingEnabled).toBe(false);
      expect(config.debugLoggingEnabled).toBe(true);
      expect(config.offlineMode).toBe(true);
      expect(config.autoEnvAttributesEnabled).toBe(false);
    });

    test('Test CFConfigBuilder validation errors', () => {
      const builder = new CFConfigBuilderImpl('test-client-key');

      expect(() => builder.eventsQueueSize(0)).toThrow('Events queue size must be greater than 0');
      expect(() => builder.eventsFlushTimeSeconds(-1)).toThrow('Events flush time must be greater than 0');
      expect(() => builder.maxRetryAttempts(-1)).toThrow('Max retry attempts must be non-negative');
      expect(() => builder.retryBackoffMultiplier(1.0)).toThrow('Backoff multiplier must be greater than 1.0');
      expect(() => builder.networkConnectionTimeoutMs(0)).toThrow('Network connection timeout must be greater than 0');
    });

    test('Test CFConfigBuilder fluent API', () => {
      const builder = new CFConfigBuilderImpl('test-client-key')
        .eventsQueueSize(25)
        .loggingEnabled(false)
        .debugLoggingEnabled(true)
        .offlineMode(true)
        .maxRetryAttempts(10);

      expect(builder).toBeInstanceOf(CFConfigBuilderImpl);

      const config = builder.build();
      expect(config.eventsQueueSize).toBe(25);
      expect(config.loggingEnabled).toBe(false);
      expect(config.debugLoggingEnabled).toBe(true);
      expect(config.offlineMode).toBe(true);
      expect(config.maxRetryAttempts).toBe(10);
    });

    test('Test CFConfigBuilder network configuration', () => {
      const config = new CFConfigBuilderImpl('test-client-key')
        .networkConnectionTimeoutMs(5000)
        .networkReadTimeoutMs(15000)
        .build();

      expect(config.networkConnectionTimeoutMs).toBe(5000);
      expect(config.networkReadTimeoutMs).toBe(15000);
    });

    test('Test CFConfigBuilder retry configuration', () => {
      const config = new CFConfigBuilderImpl('test-client-key')
        .maxRetryAttempts(5)
        .retryInitialDelayMs(500)
        .retryMaxDelayMs(10000)
        .retryBackoffMultiplier(2.5)
        .build();

      expect(config.maxRetryAttempts).toBe(5);
      expect(config.retryInitialDelayMs).toBe(500);
      expect(config.retryMaxDelayMs).toBe(10000);
      expect(config.retryBackoffMultiplier).toBe(2.5);
    });

    test('Test CFConfigBuilder summary configuration', () => {
      const config = new CFConfigBuilderImpl('test-client-key')
        .summariesQueueSize(15)
        .summariesFlushTimeSeconds(45)
        .summariesFlushIntervalMs(22500)
        .build();

      expect(config.summariesQueueSize).toBe(15);
      expect(config.summariesFlushTimeSeconds).toBe(45);
      expect(config.summariesFlushIntervalMs).toBe(22500);
    });

    test('Test CFConfigBuilder background polling configuration', () => {
      const config = new CFConfigBuilderImpl('test-client-key')
        .disableBackgroundPolling(true)
        .backgroundPollingIntervalMs(180000)
        .useReducedPollingWhenBatteryLow(false)
        .reducedPollingIntervalMs(600000)
        .build();

      expect(config.disableBackgroundPolling).toBe(true);
      expect(config.backgroundPollingIntervalMs).toBe(180000);
      expect(config.useReducedPollingWhenBatteryLow).toBe(false);
      expect(config.reducedPollingIntervalMs).toBe(600000);
    });
  });

  // Immutability Tests
  describe('Immutability Tests', () => {
    test('Test CFUser immutability across multiple operations', () => {
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

    test('Test original properties object not mutated', () => {
      const originalProps = { prop1: 'value1' };
      const user = new CFUserImpl('user-1', undefined, undefined, false, originalProps);
      
      user.withProperty('prop2', 'value2');

      // Original properties object should not be modified
      expect(originalProps).toEqual({ prop1: 'value1' });
      expect(user.properties).toEqual({ prop1: 'value1' });
    });
  });

  // Integration Tests
  describe('Integration Tests', () => {
    test('Test complete user workflow', () => {
      // Create user with builder
      const user = CFUserImpl.builder('test-user-123')
        .anonymousId('anon-456')
        .deviceId('device-789')
        .anonymous(false)
        .property('name', 'John Doe')
        .property('age', 30)
        .properties({ premium: true, department: 'engineering' })
        .build();

      // Verify user creation
      expect(user.userCustomerId).toBe('test-user-123');
      expect(user.anonymousId).toBe('anon-456');
      expect(user.deviceId).toBe('device-789');
      expect(user.anonymous).toBe(false);
      expect(user.properties).toEqual({
        name: 'John Doe',
        age: 30,
        premium: true,
        department: 'engineering',
      });

      // Test immutable updates
      const updatedUser = user
        .withProperty('level', 'senior')
        .withAnonymous(true);

      expect(user.properties).not.toHaveProperty('level');
      expect(user.anonymous).toBe(false);
      expect(updatedUser.properties).toHaveProperty('level', 'senior');
      expect(updatedUser.anonymous).toBe(true);

      // Test serialization
      const userMap = updatedUser.toUserMap();
      expect(userMap.user_customer_id).toBe('test-user-123');
      expect(userMap.anonymous).toBe(true);
      expect(userMap.properties.name).toBe('John Doe');
      expect(userMap.properties.level).toBe('senior');
      expect(userMap.properties.device.device_id).toBe('device-789');
    });

    test('Test complete config workflow', () => {
      // Create config with builder
      const config = CFConfigImpl.builder('test-client-key')
        .eventsQueueSize(100)
        .eventsFlushTimeSeconds(120)
        .maxRetryAttempts(7)
        .retryInitialDelayMs(2000)
        .retryBackoffMultiplier(2.0)
        .summariesQueueSize(20)
        .networkConnectionTimeoutMs(15000)
        .loggingEnabled(false)
        .debugLoggingEnabled(true)
        .offlineMode(true)
        .autoEnvAttributesEnabled(false)
        .build();

      // Verify all configurations
      expect(config.clientKey).toBe('test-client-key');
      expect(config.eventsQueueSize).toBe(100);
      expect(config.eventsFlushTimeSeconds).toBe(120);
      expect(config.maxRetryAttempts).toBe(7);
      expect(config.retryInitialDelayMs).toBe(2000);
      expect(config.retryBackoffMultiplier).toBe(2.0);
      expect(config.summariesQueueSize).toBe(20);
      expect(config.networkConnectionTimeoutMs).toBe(15000);
      expect(config.loggingEnabled).toBe(false);
      expect(config.debugLoggingEnabled).toBe(true);
      expect(config.offlineMode).toBe(true);
      expect(config.autoEnvAttributesEnabled).toBe(false);
    });
  });

  // Type Safety Tests
  describe('Type Safety Tests', () => {
    test('Test different property value types', () => {
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

    test('Test config parameter types', () => {
      const config = new CFConfigImpl('test-key', 50, 60, 30000);

      expect(typeof config.clientKey).toBe('string');
      expect(typeof config.eventsQueueSize).toBe('number');
      expect(typeof config.eventsFlushTimeSeconds).toBe('number');
      expect(typeof config.eventsFlushIntervalMs).toBe('number');
      expect(typeof config.loggingEnabled).toBe('boolean');
      expect(typeof config.offlineMode).toBe('boolean');
    });
  });
});

describe('Basic Test Suite', () => {
  test('should perform basic arithmetic', () => {
    expect(1 + 1).toBe(2);
    expect(2 * 3).toBe(6);
  });

  test('should handle strings', () => {
    expect('hello'.toUpperCase()).toBe('HELLO');
    expect('world'.length).toBe(5);
  });

  test('should handle arrays', () => {
    const arr = [1, 2, 3];
    expect(arr.length).toBe(3);
    expect(arr.includes(2)).toBe(true);
  });

  test('should handle objects', () => {
    const obj = { name: 'test', value: 42 };
    expect(obj.name).toBe('test');
    expect(obj.value).toBe(42);
  });
}); 