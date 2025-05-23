import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

// Mock SDK interfaces (since we can't import the actual SDK due to compilation issues)
interface CFClient {
  getString: (key: string, defaultValue: string) => string;
  getBoolean: (key: string, defaultValue: boolean) => boolean;
  addConfigListener: <T>(key: string, callback: (value: T) => void) => void;
  removeConfigListener: (key: string) => void;
  fetchConfigs: () => Promise<boolean>;
  eventTracker: {
    trackEvent: (eventName: string, properties: Record<string, any>) => Promise<void>;
  };
  userManager: {
    addUserProperty: (key: string, value: any) => void;
  };
  connectionManager: {
    setOfflineMode: (offline: boolean) => void;
  };
  shutdown: () => void;
}

interface CFConfig {
  static: {
    builder: (clientKey: string) => CFConfigBuilder;
  };
}

interface CFConfigBuilder {
  setDebugLoggingEnabled: (enabled: boolean) => CFConfigBuilder;
  setOfflineMode: (offline: boolean) => CFConfigBuilder;
  setSdkSettingsCheckIntervalMs: (interval: number) => CFConfigBuilder;
  setBackgroundPollingIntervalMs: (interval: number) => CFConfigBuilder;
  setReducedPollingIntervalMs: (interval: number) => CFConfigBuilder;
  setSummariesFlushTimeSeconds: (seconds: number) => CFConfigBuilder;
  setSummariesFlushIntervalMs: (interval: number) => CFConfigBuilder;
  setEventsFlushTimeSeconds: (seconds: number) => CFConfigBuilder;
  setEventsFlushIntervalMs: (interval: number) => CFConfigBuilder;
  setNetworkConnectionTimeoutMs: (timeout: number) => CFConfigBuilder;
  setNetworkReadTimeoutMs: (timeout: number) => CFConfigBuilder;
  setLogLevel: (level: string) => CFConfigBuilder;
  build: () => any;
}

interface CFUser {
  userCustomerId: string;
  properties: Record<string, any>;
  anonymous: boolean;
}

// Mock SDK implementation
const createMockSDK = (): { CFClient: any; CFConfig: any; CFUser: any } => {
  const listeners: Record<string, ((value: any) => void)[]> = {};
  
  const mockClient: CFClient = {
    getString: (key: string, defaultValue: string) => {
      const values: Record<string, string> = {
        'hero_text': 'CF React Native Flag Demo-18',
      };
      return values[key] || defaultValue;
    },
    getBoolean: (key: string, defaultValue: boolean) => {
      const values: Record<string, boolean> = {
        'enhanced_toast': false,
      };
      return values[key] || defaultValue;
    },
    addConfigListener: <T>(key: string, callback: (value: T) => void) => {
      if (!listeners[key]) {
        listeners[key] = [];
      }
      listeners[key].push(callback);
      console.log(`✅ Added listener for ${key}`);
    },
    removeConfigListener: (key: string) => {
      delete listeners[key];
      console.log(`🗑️ Removed listener for ${key}`);
    },
    fetchConfigs: async () => {
      console.log('🔄 Fetching configs...');
      // Simulate config changes
      setTimeout(() => {
        if (listeners['hero_text']) {
          const newValue = `CF RN Demo-${Date.now() % 100}`;
          listeners['hero_text'].forEach(callback => callback(newValue));
        }
        if (listeners['enhanced_toast']) {
          const newValue = Math.random() > 0.5;
          listeners['enhanced_toast'].forEach(callback => callback(newValue));
        }
      }, 1000);
      return true;
    },
    eventTracker: {
      trackEvent: async (eventName: string, properties: Record<string, any>) => {
        console.log(`📊 Event tracked: ${eventName}`, properties);
      },
    },
    userManager: {
      addUserProperty: (key: string, value: any) => {
        console.log(`👤 User property added: ${key} = ${value}`);
      },
    },
    connectionManager: {
      setOfflineMode: (offline: boolean) => {
        console.log(`🌐 Offline mode: ${offline}`);
      },
    },
    shutdown: () => {
      console.log('🔄 SDK shutdown');
    },
  };

  const mockConfigBuilder: CFConfigBuilder = {
    setDebugLoggingEnabled: (enabled: boolean) => mockConfigBuilder,
    setOfflineMode: (offline: boolean) => mockConfigBuilder,
    setSdkSettingsCheckIntervalMs: (interval: number) => mockConfigBuilder,
    setBackgroundPollingIntervalMs: (interval: number) => mockConfigBuilder,
    setReducedPollingIntervalMs: (interval: number) => mockConfigBuilder,
    setSummariesFlushTimeSeconds: (seconds: number) => mockConfigBuilder,
    setSummariesFlushIntervalMs: (interval: number) => mockConfigBuilder,
    setEventsFlushTimeSeconds: (seconds: number) => mockConfigBuilder,
    setEventsFlushIntervalMs: (interval: number) => mockConfigBuilder,
    setNetworkConnectionTimeoutMs: (timeout: number) => mockConfigBuilder,
    setNetworkReadTimeoutMs: (timeout: number) => mockConfigBuilder,
    setLogLevel: (level: string) => mockConfigBuilder,
    build: () => ({}),
  };

  return {
    CFClient: {
      create: (config: any, user: CFUser) => {
        console.log('🚀 CFClient created with user:', user.userCustomerId);
        return mockClient;
      },
    },
    CFConfig: {
      builder: (clientKey: string) => {
        console.log('⚙️ CFConfig builder created with key:', clientKey.substring(0, 8) + '...');
        return mockConfigBuilder;
      },
    },
    CFUser: (userCustomerId: string, properties: Record<string, any>, anonymous: boolean) => ({
      userCustomerId,
      properties,
      anonymous,
    }),
  };
};

const { CFClient, CFConfig, CFUser } = createMockSDK();

interface CustomFitContextType {
  isInitialized: boolean;
  featureFlags: Record<string, any>;
  heroText: string;
  enhancedToast: boolean;
  isOffline: boolean;
  lastConfigChangeMessage: string | null;
  hasNewConfigMessage: boolean;
  toggleOfflineMode: () => Promise<void>;
  trackEvent: (eventName: string, properties?: Record<string, any>) => Promise<void>;
  addUserProperty: (key: string, value: any) => Promise<void>;
  refreshFeatureFlags: (eventName?: string) => Promise<boolean>;
}

const CustomFitContext = createContext<CustomFitContextType | undefined>(undefined);

export const useCustomFit = () => {
  const context = useContext(CustomFitContext);
  if (!context) {
    throw new Error('useCustomFit must be used within a CustomFitProvider');
  }
  return context;
};

interface CustomFitProviderProps {
  children: ReactNode;
}

export const CustomFitProvider: React.FC<CustomFitProviderProps> = ({ children }) => {
  const [client, setClient] = useState<CFClient | null>(null);
  const [isInitialized, setIsInitialized] = useState(false);
  const [featureFlags, setFeatureFlags] = useState<Record<string, any>>({});
  const [heroText, setHeroText] = useState('CF React Native Flag Demo-18');
  const [enhancedToast, setEnhancedToast] = useState(false);
  const [isOffline, setIsOffline] = useState(false);
  const [lastConfigChangeMessage, setLastConfigChangeMessage] = useState<string | null>(null);
  const [lastMessageTime, setLastMessageTime] = useState<Date | null>(null);

  const hasNewConfigMessage = lastMessageTime !== null && 
    (Date.now() - lastMessageTime.getTime()) < 5 * 60 * 1000; // 5 minutes

  const initialize = async () => {
    try {
      console.log('Initializing CustomFit provider...');

      const userProperties = {
        'name': 'Demo User',
        'platform': 'React Native',
      };

      const user = CFUser(
        `reactnative_user_${Date.now()}`,
        userProperties,
        true
      );
      console.log('CFUser created with ID:', user.userCustomerId);

      const config = CFConfig.builder(
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek'
      )
        .setDebugLoggingEnabled(true)
        .setOfflineMode(false)
        .setSdkSettingsCheckIntervalMs(2000)
        .setBackgroundPollingIntervalMs(2000)
        .setReducedPollingIntervalMs(2000)
        .setSummariesFlushTimeSeconds(5)
        .setSummariesFlushIntervalMs(5000)
        .setEventsFlushTimeSeconds(30)
        .setEventsFlushIntervalMs(30000)
        .setNetworkConnectionTimeoutMs(10000)
        .setNetworkReadTimeoutMs(10000)
        .setLogLevel('debug')
        .build();
      console.log('CFConfig created successfully');

      const cfClient = CFClient.create(config, user);
      console.log('CFClient created successfully');

      setClient(cfClient);
      setIsInitialized(true);

      // Set up config listeners
      setupConfigListeners(cfClient);

      // Update initial values
      updateInitialValues(cfClient);

    } catch (error) {
      console.error('❌ Failed to create CFClient or register listener:', error);
      // Make sure UI still shows something even if client fails
      setIsInitialized(true);
    }
  };

  const setupConfigListeners = (cfClient: CFClient) => {
    // Add listener for hero_text
    cfClient.addConfigListener<string>('hero_text', (newValue) => {
      console.log('🚩 hero_text config listener triggered with value:', newValue);
      if (heroText !== newValue) {
        setHeroText(newValue);
        setLastConfigChangeMessage(`FLAG UPDATE: hero_text = ${newValue}`);
        setLastMessageTime(new Date());
      }
    });

    // Add listener for enhanced_toast
    cfClient.addConfigListener<boolean>('enhanced_toast', (isEnabled) => {
      console.log('🚩 enhanced_toast config listener triggered with value:', isEnabled);
      if (enhancedToast !== isEnabled) {
        setEnhancedToast(isEnabled);
      }
    });

    console.log('✅ Config listeners set up successfully');
  };

  const updateInitialValues = (cfClient: CFClient) => {
    // Get initial values from config
    const initialHeroText = cfClient.getString('hero_text', 'CF DEMO');
    const initialEnhancedToast = cfClient.getBoolean('enhanced_toast', false);

    console.log('Initial values:', { heroText: initialHeroText, enhancedToast: initialEnhancedToast });

    setHeroText(initialHeroText);
    setEnhancedToast(initialEnhancedToast);

    setFeatureFlags({
      'hero_text': { variation: initialHeroText },
      'enhanced_toast': { variation: initialEnhancedToast },
    });
  };

  const toggleOfflineMode = async () => {
    if (!isInitialized || !client) return;

    if (isOffline) {
      client.connectionManager.setOfflineMode(false);
    } else {
      client.connectionManager.setOfflineMode(true);
    }
    setIsOffline(!isOffline);
  };

  const trackEvent = async (eventName: string, properties: Record<string, any> = {}) => {
    if (!isInitialized || !client) {
      console.log('⚠️ Event tracking skipped: CFClient is null');
      return;
    }
    await client.eventTracker.trackEvent(eventName, properties);
  };

  const addUserProperty = async (key: string, value: any) => {
    if (!isInitialized || !client) return;
    client.userManager.addUserProperty(key, value);
  };

  const refreshFeatureFlags = async (eventName?: string): Promise<boolean> => {
    if (!isInitialized || !client) return false;

    console.log('Manually refreshing feature flags...');

    // Track the refresh event if an event name is provided
    if (eventName) {
      await trackEvent(eventName, {
        'config_key': 'all',
        'refresh_source': 'user_action',
        'screen': 'home',
        'platform': 'react_native'
      });
    }

    // Fetch latest flags from server
    const success = await client.fetchConfigs();
    if (success) {
      console.log('✅ Flags refreshed successfully');
    } else {
      console.log('⚠️ Failed to refresh flags');
    }

    // Update the last message
    setLastConfigChangeMessage('Configuration manually refreshed');
    setLastMessageTime(new Date());

    return success;
  };

  useEffect(() => {
    initialize();

    return () => {
      if (isInitialized && client) {
        // Remove listeners when provider is disposed
        client.removeConfigListener('hero_text');
        client.removeConfigListener('enhanced_toast');
        client.shutdown();
      }
    };
  }, []);

  const value: CustomFitContextType = {
    isInitialized,
    featureFlags,
    heroText,
    enhancedToast,
    isOffline,
    lastConfigChangeMessage,
    hasNewConfigMessage,
    toggleOfflineMode,
    trackEvent,
    addUserProperty,
    refreshFeatureFlags,
  };

  return (
    <CustomFitContext.Provider value={value}>
      {children}
    </CustomFitContext.Provider>
  );
}; 