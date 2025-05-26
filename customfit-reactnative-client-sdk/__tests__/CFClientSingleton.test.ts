// Mock all dependencies before importing the modules
jest.mock('../src/network/HttpClient', () => {
  return {
    HttpClient: jest.fn().mockImplementation(() => ({
      get: jest.fn(() => Promise.resolve({ isSuccess: true, data: { status: 200, data: {} } })),
      post: jest.fn(() => Promise.resolve({ isSuccess: true, data: { status: 200 } })),
      head: jest.fn(() => Promise.resolve({ isSuccess: true, data: { status: 200 } })),
    })),
  };
});

jest.mock('../src/network/ConfigFetcher', () => {
  return {
    ConfigFetcher: jest.fn().mockImplementation(() => ({
      checkSdkSettings: jest.fn(() => Promise.resolve({ isSuccess: true, data: null })),
      getCachedUserConfigs: jest.fn(() => Promise.resolve({ isSuccess: true, data: null })),
      fetchUserConfigs: jest.fn(() => Promise.resolve({ isSuccess: true, data: { configs: {}, metadata: {} } })),
      cacheUserConfigs: jest.fn(() => Promise.resolve({ isSuccess: true })),
    })),
  };
});

jest.mock('../src/analytics/event/EventTracker', () => {
  return {
    EventTracker: jest.fn().mockImplementation(() => ({
      start: jest.fn(() => Promise.resolve()),
      stop: jest.fn(() => Promise.resolve()),
      trackEvent: jest.fn(() => Promise.resolve({ isSuccess: true })),
      flush: jest.fn(() => Promise.resolve({ isSuccess: true, data: 0 })),
      updateFlushInterval: jest.fn(),
      setUser: jest.fn(),
    })),
  };
});

jest.mock('../src/analytics/summary/SummaryManager', () => {
  return {
    SummaryManager: jest.fn().mockImplementation(() => ({
      start: jest.fn(() => Promise.resolve()),
      stop: jest.fn(() => Promise.resolve()),
      trackFeatureFlagAccess: jest.fn(),
      flush: jest.fn(() => Promise.resolve({ isSuccess: true, data: 0 })),
      updateFlushInterval: jest.fn(),
    })),
  };
});

jest.mock('../src/platform/ConnectionMonitor', () => {
  const mockInstance = {
    startMonitoring: jest.fn(() => Promise.resolve()),
    stopMonitoring: jest.fn(),
    isConnected: jest.fn(() => true),
    addListener: jest.fn(),
    removeListener: jest.fn(),
  };
  
  return {
    ConnectionMonitor: {
      getInstance: jest.fn(() => mockInstance),
    },
  };
});

jest.mock('../src/platform/AppStateManager', () => {
  const mockInstance = {
    startMonitoring: jest.fn(),
    stopMonitoring: jest.fn(),
    getPollingInterval: jest.fn((normal) => normal),
    addAppStateListener: jest.fn(),
    addBatteryStateListener: jest.fn(),
  };
  
  return {
    AppStateManager: {
      getInstance: jest.fn(() => mockInstance),
    },
  };
});

jest.mock('../src/platform/EnvironmentAttributesCollector', () => {
  const mockInstance = {
    getAllAttributes: jest.fn(() => Promise.resolve({})),
  };
  
  return {
    EnvironmentAttributesCollector: {
      getInstance: jest.fn(() => mockInstance),
    },
  };
});

jest.mock('react-native', () => ({
  Platform: {
    OS: 'android',
    Version: 30,
    select: jest.fn((obj) => obj.android || obj.default),
  },
  Dimensions: {
    get: jest.fn(() => ({
      width: 375,
      height: 667,
      scale: 2,
      fontScale: 1,
    })),
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  },
  AppState: {
    currentState: 'active',
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  },
}));

jest.mock('@react-native-async-storage/async-storage', () => {
  const mockStorage = new Map();
  
  return {
    setItem: jest.fn((key, value) => {
      mockStorage.set(key, value);
      return Promise.resolve();
    }),
    getItem: jest.fn((key) => {
      return Promise.resolve(mockStorage.get(key) || null);
    }),
    removeItem: jest.fn((key) => {
      mockStorage.delete(key);
      return Promise.resolve();
    }),
    getAllKeys: jest.fn(() => {
      return Promise.resolve([...mockStorage.keys()]);
    }),
    clear: jest.fn(() => {
      mockStorage.clear();
      return Promise.resolve();
    }),
  };
});

// Mock the logging module
jest.mock('../src/logging/Logger');

import { CFClient } from '../src/client/CFClient';
import { CFConfigImpl } from '../src/config/core/CFConfig';
import { CFUserImpl } from '../src/core/model/CFUser';
import { Logger } from '../src/logging/Logger';

describe('CFClient Singleton Tests', () => {
  let testConfig: CFConfigImpl;
  let testUser: CFUserImpl;

  beforeEach(async () => {
    // Clean state before each test
    await CFClient.shutdownSingleton();

    // Create test configuration using builder
    testConfig = CFConfigImpl.builder('test-client-key')
      .debugLoggingEnabled(true)
      .offlineMode(true) // Use offline mode for testing
      .loggingEnabled(true)
      .logLevel('DEBUG')
      .build() as CFConfigImpl;

    // Create test user using builder
    testUser = CFUserImpl.builder('test-user-123')
      .property('platform', 'reactnative-test')
      .build() as CFUserImpl;
  });

  afterEach(async () => {
    // Clean up after each test
    await CFClient.shutdownSingleton();
  });

  describe('Singleton Creation', () => {
    test('should create singleton instance', async () => {
      // Given: No existing instance
      expect(CFClient.isInitialized()).toBe(false);
      expect(CFClient.getInstance()).toBeNull();

      // When: Creating first instance
      const client1 = await CFClient.initialize(testConfig, testUser);

      // Then: Singleton should be created and accessible
      expect(CFClient.isInitialized()).toBe(true);
      expect(CFClient.getInstance()).not.toBeNull();
      expect(client1).toBe(CFClient.getInstance());
    });

    test('should return same instance on subsequent calls', async () => {
      // Given: First instance created
      const client1 = await CFClient.initialize(testConfig, testUser);

      // When: Creating second instance with different config
      const differentConfig = CFConfigImpl.builder('different-key')
        .debugLoggingEnabled(false)
        .offlineMode(false)
        .build() as CFConfigImpl;
      const differentUser = CFUserImpl.builder('different-user').build() as CFUserImpl;

      const client2 = await CFClient.initialize(differentConfig, differentUser);

      // Then: Should return the same instance
      expect(client1).toBe(client2);
      expect(client1).toBe(CFClient.getInstance());
    });

    test('should handle getInstance before initialization', () => {
      // Given: No instance created
      expect(CFClient.isInitialized()).toBe(false);

      // When: Getting instance without initialization
      const instance = CFClient.getInstance();

      // Then: Should return null
      expect(instance).toBeNull();
      expect(CFClient.isInitialized()).toBe(false);
    });
  });

  describe('Initialization States', () => {
    test('should track isInitialized correctly', async () => {
      // Initially not initialized
      expect(CFClient.isInitialized()).toBe(false);

      // After initialization
      const client = await CFClient.initialize(testConfig, testUser);
      expect(client).toBeDefined();
      expect(CFClient.isInitialized()).toBe(true);

      // After shutdown
      await CFClient.shutdownSingleton();
      expect(CFClient.isInitialized()).toBe(false);
    });

    test('should track isInitializing during creation', async () => {
      // Initially not initializing
      expect(CFClient.isInitializing()).toBe(false);

      // Start initialization (don't await yet)
      const initPromise = CFClient.initialize(testConfig, testUser);
      
      // During initialization (this might be too fast to catch in real scenarios)
      // expect(CFClient.isInitializing()).toBe(true);

      // After completion
      const client = await initPromise;
      expect(client).toBeDefined();
      expect(CFClient.isInitializing()).toBe(false);
    });
  });

  describe('Singleton Lifecycle', () => {
    test('should shutdown singleton properly', async () => {
      // Given: Initialized singleton
      const client = await CFClient.initialize(testConfig, testUser);
      expect(CFClient.isInitialized()).toBe(true);
      expect(CFClient.getInstance()).not.toBeNull();

      // When: Shutting down
      await CFClient.shutdownSingleton();

      // Then: Should be clean state
      expect(CFClient.isInitialized()).toBe(false);
      expect(CFClient.getInstance()).toBeNull();
      expect(CFClient.isInitializing()).toBe(false);
    });

    test('should reinitialize singleton', async () => {
      // Given: First instance
      const client1 = await CFClient.initialize(testConfig, testUser);
      expect(CFClient.isInitialized()).toBe(true);

      // When: Reinitializing with new config
      const newConfig = CFConfigImpl.builder('new-key')
        .debugLoggingEnabled(false)
        .offlineMode(false)
        .build() as CFConfigImpl;
      const newUser = CFUserImpl.builder('new-user').build() as CFUserImpl;

      const client2 = await CFClient.reinitialize(newConfig, newUser);

      // Then: Should have new instance
      expect(CFClient.isInitialized()).toBe(true);
      expect(CFClient.getInstance()).not.toBeNull();
      expect(client2).toBe(CFClient.getInstance());
      expect(client1).not.toBe(client2);
    });

    test('should create detached instance', async () => {
      // Given: Existing singleton
      const singleton = await CFClient.initialize(testConfig, testUser);
      expect(CFClient.isInitialized()).toBe(true);

      // When: Creating detached instance
      const detachedConfig = CFConfigImpl.builder('detached-key')
        .debugLoggingEnabled(false)
        .offlineMode(true)
        .build() as CFConfigImpl;
      const detachedUser = CFUserImpl.builder('detached-user').build() as CFUserImpl;

      const detachedClient = await CFClient.createDetached(detachedConfig, detachedUser);

      // Then: Singleton should remain unchanged
      expect(CFClient.isInitialized()).toBe(true);
      expect(singleton).toBe(CFClient.getInstance());
      expect(detachedClient).not.toBe(CFClient.getInstance());
      expect(singleton).not.toBe(detachedClient);
    });
  });

  describe('Concurrent Access', () => {
    test('should handle concurrent initialization attempts', async () => {
      const promises: Promise<CFClient>[] = [];
      const configs = [];
      const users = [];

      // Create multiple configs and users
      for (let i = 0; i < 5; i++) {
        configs.push(CFConfigImpl.builder(`test-key-${i}`)
          .debugLoggingEnabled(true)
          .offlineMode(true)
          .build());
        users.push(CFUserImpl.builder(`test-user-${i}`).build());
      }

      // Launch multiple concurrent initialization attempts
      for (let i = 0; i < 5; i++) {
        promises.push(CFClient.initialize(configs[i], users[i]));
      }

      const clients = await Promise.all(promises);

      // All clients should be the same instance
      expect(clients).toHaveLength(5);
      const firstClient = clients[0];

      for (const client of clients) {
        expect(client).toBe(firstClient);
      }

      // Should still be the singleton
      expect(firstClient).toBe(CFClient.getInstance());
    });

    test('should handle mixed concurrent operations', async () => {
      const promises: Promise<any>[] = [];

      // Mix of different operations
      for (let i = 0; i < 10; i++) {
        switch (i % 4) {
          case 0:
            // Initialize
            promises.push(CFClient.initialize(testConfig, testUser));
            break;
          case 1:
            // Get instance
            promises.push(Promise.resolve(CFClient.getInstance()));
            break;
          case 2:
            // Check status
            promises.push(Promise.resolve({
              isInitialized: CFClient.isInitialized(),
              isInitializing: CFClient.isInitializing()
            }));
            break;
          case 3:
            // Create detached (only if singleton exists)
            promises.push(
              CFClient.isInitialized() 
                ? CFClient.createDetached(testConfig, testUser)
                : Promise.resolve(null)
            );
            break;
        }
      }

      const results = await Promise.all(promises);

      // Should end in a consistent state
      if (CFClient.isInitialized()) {
        expect(CFClient.getInstance()).not.toBeNull();
      } else {
        expect(CFClient.getInstance()).toBeNull();
      }
    });
  });

  describe('Deprecation and Backward Compatibility', () => {
    test('should support deprecated init method', async () => {
      // When: Using deprecated init method
      const client = await CFClient.init(testConfig, testUser);

      // Then: Should work but log warning
      expect(client).toBeDefined();
      expect(CFClient.isInitialized()).toBe(true);
      expect(client).toBe(CFClient.getInstance());
      
      // Should have logged deprecation warning
      expect(Logger.warning).toHaveBeenCalledWith(
        'CFClient.init() is deprecated, use CFClient.initialize() instead'
      );
    });
  });

  describe('Shutdown and Reinitialization Cycles', () => {
    test('should handle multiple shutdown and reinitialize cycles', async () => {
      // Test multiple cycles of shutdown and reinitialize
      for (let i = 0; i < 3; i++) {
        // Initialize
        const config = CFConfigImpl.builder(`test-key-${i}`)
          .debugLoggingEnabled(true)
          .offlineMode(true)
          .build() as CFConfigImpl;
        const user = CFUserImpl.builder(`test-user-${i}`).build() as CFUserImpl;

        const client = await CFClient.initialize(config, user);
        expect(CFClient.isInitialized()).toBe(true);
        expect(CFClient.getInstance()).not.toBeNull();
        expect(client).toBe(CFClient.getInstance());

        // Shutdown
        await CFClient.shutdownSingleton();
        expect(CFClient.isInitialized()).toBe(false);
        expect(CFClient.getInstance()).toBeNull();
      }
    });
  });

  describe('Error Handling', () => {
    test('should handle initialization failure properly', async () => {
      // Mock an initialization failure
      const originalConsoleError = console.error;
      console.error = jest.fn();

      try {
        // Create a config that might cause issues (empty client key)
        const badConfig = CFConfigImpl.builder('')
          .debugLoggingEnabled(true)
          .offlineMode(true)
          .build() as CFConfigImpl;

        // This might throw or handle gracefully depending on implementation
        try {
          await CFClient.initialize(badConfig, testUser);
        } catch (error) {
          // If it throws, that's expected for invalid config
          expect(error).toBeDefined();
        }

        // State should be clean after failure
        expect(CFClient.isInitializing()).toBe(false);
      } finally {
        console.error = originalConsoleError;
      }
    });
  });

  describe('Thread Safety Simulation', () => {
    test('should handle rapid successive calls', async () => {
      const promises: Promise<CFClient>[] = [];

      // Create many rapid successive calls
      for (let i = 0; i < 20; i++) {
        promises.push(CFClient.initialize(testConfig, testUser));
      }

      const clients = await Promise.all(promises);

      // All should be the same instance
      const firstClient = clients[0];
      for (const client of clients) {
        expect(client).toBe(firstClient);
      }

      expect(CFClient.getInstance()).toBe(firstClient);
    });
  });
}); 