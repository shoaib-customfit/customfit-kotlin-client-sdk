import { CFConfigImpl } from '../src/config/core/CFConfig';
import { CFUserImpl } from '../src/core/model/CFUser';

describe('CustomFit React Native SDK - Basic Functionality Test Suite', () => {
  describe('CFConfig Creation Tests', () => {
    test('should create CFConfig with valid client key', () => {
      const config = CFConfigImpl.builder('valid-client-key-123').build();

      expect(config.clientKey).toBe('valid-client-key-123');
      expect(config.offlineMode).toBe(false);
      expect(config.loggingEnabled).toBe(true);
      expect(config.debugLoggingEnabled).toBe(false);
    });

    test('should build CFConfig with custom values', () => {
      const config = CFConfigImpl.builder('test-key')
        .eventsQueueSize(50)
        .eventsFlushTimeSeconds(60)
        .maxRetryAttempts(5)
        .offlineMode(true)
        .loggingEnabled(false)
        .debugLoggingEnabled(true)
        .build();

      expect(config.clientKey).toBe('test-key');
      expect(config.eventsQueueSize).toBe(50);
      expect(config.eventsFlushTimeSeconds).toBe(60);
      expect(config.maxRetryAttempts).toBe(5);
      expect(config.offlineMode).toBe(true);
      expect(config.loggingEnabled).toBe(false);
      expect(config.debugLoggingEnabled).toBe(true);
    });

    test('should validate builder parameters', () => {
      // Test negative values
      expect(() => CFConfigImpl.builder('test-key').eventsQueueSize(-1).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').eventsFlushTimeSeconds(-1).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').maxRetryAttempts(-1).build()).toThrow();
    });

    test('should handle extreme configuration values', () => {
      const config = CFConfigImpl.builder('test-key')
        .eventsQueueSize(2147483647) // Max int
        .networkConnectionTimeoutMs(2147483647)
        .maxStoredEvents(2147483647)
        .build();

      expect(config.eventsQueueSize).toBe(2147483647);
      expect(config.networkConnectionTimeoutMs).toBe(2147483647);
      expect(config.maxStoredEvents).toBe(2147483647);
    });

    test('should handle minimum valid configuration values', () => {
      const config = CFConfigImpl.builder('test-key')
        .eventsQueueSize(1)
        .eventsFlushTimeSeconds(1)
        .maxRetryAttempts(0)
        .networkConnectionTimeoutMs(1)
        .networkReadTimeoutMs(1)
        .maxStoredEvents(1)
        .build();

      expect(config.eventsQueueSize).toBe(1);
      expect(config.eventsFlushTimeSeconds).toBe(1);
      expect(config.maxRetryAttempts).toBe(0);
      expect(config.networkConnectionTimeoutMs).toBe(1);
      expect(config.networkReadTimeoutMs).toBe(1);
      expect(config.maxStoredEvents).toBe(1);
    });
  });

  describe('CFUser Tests', () => {
    test('should create CFUser with valid user ID', () => {
      const user = CFUserImpl.builder('test-user-123').build();
      expect(user.userCustomerId).toBe('test-user-123');
    });

    test('should create CFUser with properties', () => {
      const user = CFUserImpl.builder('test-user-123')
        .properties({
          platform: 'react-native',
          version: '1.0.0',
          isTestUser: true,
        })
        .build();
      expect(user.userCustomerId).toBe('test-user-123');
      expect(user.properties).toBeDefined();
      expect(user.properties?.platform).toBe('react-native');
      expect(user.properties?.version).toBe('1.0.0');
      expect(user.properties?.isTestUser).toBe(true);
    });

    test('should create CFUser with device ID', () => {
      const user = CFUserImpl.builder('test-user-123')
        .deviceId('device-123')
        .build();

      expect(user.userCustomerId).toBe('test-user-123');
      expect(user.deviceId).toBe('device-123');
    });

    test('should create anonymous user', () => {
      const user = CFUserImpl.builder()
        .anonymous(true)
        .anonymousId('anon-123')
        .build();

      expect(user.anonymous).toBe(true);
      expect(user.anonymousId).toBe('anon-123');
      expect(user.userCustomerId).toBeUndefined();
    });

    test('should update user properties immutably', () => {
      const originalUser = CFUserImpl.builder('test-user-123')
        .property('original', 'value')
        .build();

      const updatedUser = originalUser.withProperty('new', 'property');

      expect(originalUser.properties?.original).toBe('value');
      expect(originalUser.properties?.new).toBeUndefined();
      expect(updatedUser.properties?.original).toBe('value');
      expect(updatedUser.properties?.new).toBe('property');
    });

    test('should convert user to map correctly', () => {
      const user = CFUserImpl.builder('test-user-123')
        .properties({
          platform: 'react-native',
          version: '1.0.0',
        })
        .anonymous(false)
        .build();

      const userMap = user.toUserMap();

      expect(userMap.user_customer_id).toBe('test-user-123');
      expect(userMap.anonymous).toBe(false);
      expect(userMap.properties.platform).toBe('react-native');
      expect(userMap.properties.version).toBe('1.0.0');
      expect(userMap.properties.device).toBeDefined();
    });

    test('should handle user with all optional fields', () => {
      const user = CFUserImpl.builder('test-user-123')
        .anonymousId('anon-456')
        .deviceId('device-789')
        .anonymous(false)
        .properties({ key: 'value' })
        .build();

      expect(user.userCustomerId).toBe('test-user-123');
      expect(user.anonymousId).toBe('anon-456');
      expect(user.deviceId).toBe('device-789');
      expect(user.anonymous).toBe(false);
      expect(user.properties?.key).toBe('value');
    });
  });

  describe('Configuration Builder Tests', () => {
    test('should chain builder methods', () => {
      const config = CFConfigImpl.builder('test-key')
        .eventsQueueSize(25)
        .eventsFlushTimeSeconds(45)
        .maxRetryAttempts(3)
        .retryInitialDelayMs(500)
        .retryMaxDelayMs(15000)
        .retryBackoffMultiplier(2.5)
        .summariesQueueSize(15)
        .summariesFlushTimeSeconds(90)
        .networkConnectionTimeoutMs(8000)
        .networkReadTimeoutMs(12000)
        .loggingEnabled(true)
        .debugLoggingEnabled(false)
        .offlineMode(false)
        .autoEnvAttributesEnabled(true)
        .build();

      expect(config.clientKey).toBe('test-key');
      expect(config.eventsQueueSize).toBe(25);
      expect(config.eventsFlushTimeSeconds).toBe(45);
      expect(config.maxRetryAttempts).toBe(3);
      expect(config.retryInitialDelayMs).toBe(500);
      expect(config.retryMaxDelayMs).toBe(15000);
      expect(config.retryBackoffMultiplier).toBe(2.5);
      expect(config.summariesQueueSize).toBe(15);
      expect(config.summariesFlushTimeSeconds).toBe(90);
      expect(config.networkConnectionTimeoutMs).toBe(8000);
      expect(config.networkReadTimeoutMs).toBe(12000);
      expect(config.loggingEnabled).toBe(true);
      expect(config.debugLoggingEnabled).toBe(false);
      expect(config.offlineMode).toBe(false);
      expect(config.autoEnvAttributesEnabled).toBe(true);
    });

    test('should validate retry configuration', () => {
      expect(() => CFConfigImpl.builder('test-key').retryBackoffMultiplier(0.5).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').retryBackoffMultiplier(1.0).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').retryInitialDelayMs(-1).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').retryMaxDelayMs(-1).build()).toThrow();
    });

    test('should validate network timeouts', () => {
      expect(() => CFConfigImpl.builder('test-key').networkConnectionTimeoutMs(0).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').networkReadTimeoutMs(0).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').networkConnectionTimeoutMs(-1).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').networkReadTimeoutMs(-1).build()).toThrow();
    });

    test('should validate queue sizes', () => {
      expect(() => CFConfigImpl.builder('test-key').eventsQueueSize(0).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').summariesQueueSize(0).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').eventsQueueSize(-1).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').summariesQueueSize(-1).build()).toThrow();
    });

    test('should validate flush intervals', () => {
      expect(() => CFConfigImpl.builder('test-key').eventsFlushTimeSeconds(0).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').summariesFlushTimeSeconds(0).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').eventsFlushIntervalMs(0).build()).toThrow();
      expect(() => CFConfigImpl.builder('test-key').summariesFlushIntervalMs(0).build()).toThrow();
    });
  });

  describe('User Builder Tests', () => {
    test('should chain user builder methods', () => {
      const user = CFUserImpl.builder('test-user')
        .anonymousId('anon-123')
        .deviceId('device-456')
        .anonymous(false)
        .property('key1', 'value1')
        .property('key2', 42)
        .property('key3', true)
        .build();

      expect(user.userCustomerId).toBe('test-user');
      expect(user.anonymousId).toBe('anon-123');
      expect(user.deviceId).toBe('device-456');
      expect(user.anonymous).toBe(false);
      expect(user.properties?.key1).toBe('value1');
      expect(user.properties?.key2).toBe(42);
      expect(user.properties?.key3).toBe(true);
    });

    test('should create default user', () => {
      const user = CFUserImpl.defaultUser();

      expect(user.userCustomerId).toBeUndefined();
      expect(user.anonymous).toBe(false);
      expect(user.properties).toEqual({});
      expect(user.contexts).toEqual([]);
    });
  });

  describe('Edge Cases and Error Handling', () => {
    test('should handle user with no customer ID', () => {
      const user = CFUserImpl.builder().build();
      expect(user.userCustomerId).toBeUndefined();
    });

    test('should handle user map conversion with minimal data', () => {
      const user = CFUserImpl.builder().build();
      const userMap = user.toUserMap();

      expect(userMap.anonymous).toBe(false);
      expect(userMap.properties).toBeDefined();
      expect(userMap.properties.device).toBeDefined();
      expect(userMap.user_customer_id).toBeUndefined();
    });

    test('should handle complex property types', () => {
      const complexProps = {
        string: 'text',
        number: 123,
        boolean: true,
        null_value: null,
        undefined_value: undefined,
        array: [1, 2, 3],
        object: { nested: 'value' },
        date: new Date(),
      };

      const user = CFUserImpl.builder('test-user')
        .properties(complexProps)
        .build();

      expect(user.properties).toEqual(complexProps);
    });

    test('should handle user property updates', () => {
      const user = CFUserImpl.builder('test-user')
        .property('initial', 'value')
        .build();

      const updatedUser = user
        .withProperty('new', 'property')
        .withProperties({ batch: 'update', another: 'prop' });

      expect(user.properties?.initial).toBe('value');
      expect(user.properties?.new).toBeUndefined();
      expect(updatedUser.properties?.initial).toBe('value');
      expect(updatedUser.properties?.new).toBe('property');
      expect(updatedUser.properties?.batch).toBe('update');
      expect(updatedUser.properties?.another).toBe('prop');
    });
  });
}); 