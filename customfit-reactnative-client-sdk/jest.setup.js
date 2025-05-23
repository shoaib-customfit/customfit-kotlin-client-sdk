// Mock React Native modules for testing

// Mock react-native modules
const mockPlatform = {
  OS: 'android',
  Version: 30,
  select: jest.fn((obj) => obj.android || obj.default),
};

const mockDimensions = {
  get: jest.fn(() => ({
    width: 375,
    height: 667,
    scale: 2,
    fontScale: 1,
  })),
  addEventListener: jest.fn(),
  removeEventListener: jest.fn(),
};

const mockAppState = {
  currentState: 'active',
  addEventListener: jest.fn(),
  removeEventListener: jest.fn(),
};

// Export for direct module mapping
module.exports = {
  Platform: mockPlatform,
  Dimensions: mockDimensions,
  AppState: mockAppState,
};

// Set up global mocks
jest.mock('react-native', () => ({
  Platform: mockPlatform,
  Dimensions: mockDimensions,
  AppState: mockAppState,
}));

// Mock @react-native-async-storage/async-storage
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

// Mock @react-native-community/netinfo
jest.mock('@react-native-community/netinfo', () => ({
  fetch: jest.fn(() => Promise.resolve({
    type: 'wifi',
    isConnected: true,
    isInternetReachable: true,
  })),
  addEventListener: jest.fn(() => jest.fn()),
}));

// Mock other React Native modules
jest.mock('react-native-device-info', () => ({
  getBatteryLevel: jest.fn(() => Promise.resolve(0.8)),
  isPinOrFingerprintSet: jest.fn(() => Promise.resolve(false)),
  getDeviceId: jest.fn(() => 'mock-device-id'),
  getSystemName: jest.fn(() => 'Android'),
  getSystemVersion: jest.fn(() => '11'),
  getModel: jest.fn(() => 'Mock Device'),
  getBrand: jest.fn(() => 'Mock Brand'),
  getManufacturer: jest.fn(() => Promise.resolve('Mock Manufacturer')),
  getApplicationName: jest.fn(() => 'Mock App'),
  getBuildNumber: jest.fn(() => '1'),
  getVersion: jest.fn(() => '1.0.0'),
  getBundleId: jest.fn(() => 'com.mock.app'),
}));

// Mock SDK internal modules
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

// Global test setup
global.fetch = jest.fn(() =>
  Promise.resolve({
    ok: true,
    status: 200,
    statusText: 'OK',
    headers: new Map(),
    json: () => Promise.resolve({}),
    text: () => Promise.resolve(''),
  })
);

// Mock console methods to reduce noise in tests
global.console = {
  ...console,
  log: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}; 