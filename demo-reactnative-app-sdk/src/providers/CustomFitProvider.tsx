import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { 
  CFClient, 
  CFConfig, 
  CFUser, 
  ConnectionStatus,
  Logger,
  CFConstants
} from '@customfit/react-native-sdk';

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
  resetCircuitBreakers: () => void;
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
  const [isInitialized, setIsInitialized] = useState(false);
  const [lastConfigChangeMessage, setLastConfigChangeMessage] = useState<string | null>(null);
  const [lastMessageTime, setLastMessageTime] = useState<Date | null>(null);
  const [client, setClient] = useState<CFClient | null>(null);
  const initializationAttempted = React.useRef(false);
  
  // State for feature flags
  const [heroText, setHeroText] = useState<string>('CF DEMO');
  const [enhancedToast, setEnhancedToast] = useState<boolean>(false);
  const [isOffline, setIsOffline] = useState<boolean>(false);
  const [featureFlags, setFeatureFlags] = useState<Record<string, any>>({});
  
  // Store listener references for cleanup
  const listenersRef = React.useRef<{
    heroTextListener?: (value: string) => void;
    enhancedToastListener?: (value: boolean) => void;
  }>({});

  const hasNewConfigMessage = lastMessageTime !== null && 
    (Date.now() - lastMessageTime.getTime()) < 5 * 60 * 1000; // 5 minutes

  const initialize = async () => {
    // Prevent multiple initialization attempts
    if (initializationAttempted.current) {
      console.log('🔄 SDK initialization already attempted, skipping...');
      return;
    }
    
    initializationAttempted.current = true;
    
    try {
      console.log('Initializing CustomFit SDK...');
      
      // Configure SDK using builder pattern - same token as Flutter app
      const config = CFConfig.builder('eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek')
        .loggingEnabled(true)
        .debugLoggingEnabled(true)
        .offlineMode(false)
        .disableBackgroundPolling(false)
        .backgroundPollingIntervalMs(CFConstants.BackgroundPolling.BACKGROUND_POLLING_INTERVAL_MS) // Use default 1 hour
        .autoEnvAttributesEnabled(true)
        .sdkSettingsCheckIntervalMs(CFConstants.BackgroundPolling.SDK_SETTINGS_CHECK_INTERVAL_MS) // Use default 5 minutes
        .summariesFlushTimeSeconds(5)
        .summariesFlushIntervalMs(5000)
        .eventsFlushTimeSeconds(30)
        .eventsFlushIntervalMs(30000)
        .networkConnectionTimeoutMs(10000)
        .networkReadTimeoutMs(10000)
        .logLevel('DEBUG')
        .build();
      
      // Create user using builder pattern - similar to Flutter app
      const user = CFUser.builder(`react_native_user_${Date.now()}`)
        .anonymousId(`anon-${Date.now()}`)
        .property('name', 'Demo User')
        .property('platform', 'React Native')
        .anonymous(true)
        .build();

      // Initialize SDK
      const cfClient = await CFClient.initialize(config, user);
      setClient(cfClient);
      
      // Initialize SDK - it should now work properly like Flutter SDK
      
      // Give the SDK a moment to settle, then check if circuit breakers need resetting
      setTimeout(() => {
        console.log('🔧 Checking circuit breaker health...');
        try {
          // Try to reset circuit breakers to ensure clean state
          cfClient.resetCircuitBreakers();
          console.log('✅ Circuit breakers reset for clean initialization');
        } catch (error) {
          console.log('⚠️ Could not reset circuit breakers:', error);
        }
      }, 2000);
      
      // Track initialization event
      await cfClient.trackEvent('sdk_initialized', {
        platform: 'react-native',
        environment: 'demo'
      });

      // Set up config listeners like Flutter
      setupConfigListeners(cfClient);
      
      // Get initial values
      updateInitialValues(cfClient);

      setIsInitialized(true);
      
      console.log('✅ CustomFit SDK initialized successfully');
    } catch (error) {
      console.error('❌ Failed to initialize CustomFit SDK:', error);
      setIsInitialized(true); // Still show UI even if initialization fails
    }
  };

  const updateInitialValues = (cfClient: CFClient) => {
    // Get initial values from config
    const initialHeroText = cfClient.getString('hero_text', 'CF DEMO');
    const initialEnhancedToast = cfClient.getBoolean('enhanced_toast', false);

    console.log('🔍 Initial values from SDK:');
    console.log('  - hero_text:', initialHeroText);
    console.log('  - enhanced_toast:', initialEnhancedToast);
    console.log('  - All flags:', cfClient.getAllFlags());

    setHeroText(initialHeroText);
    setEnhancedToast(initialEnhancedToast);

    console.log(`Initial values: heroText=${initialHeroText}, enhancedToast=${initialEnhancedToast}`);

      setFeatureFlags({
        'hero_text': { variation: initialHeroText },
        'enhanced_toast': { variation: initialEnhancedToast },
      });
  };

  const setupConfigListeners = (cfClient: CFClient) => {
    // Add listener for hero_text - similar to Flutter
    const heroTextListener = (newValue: string) => {
      console.log(`🚩 hero_text config listener triggered with value: ${newValue}`);
      console.log(`  - Current heroText state: ${heroText}`);
      if (heroText !== newValue) {
        setHeroText(newValue);
        setFeatureFlags(prev => ({
          ...prev,
          'hero_text': { variation: newValue }
        }));
        setLastConfigChangeMessage(`FLAG UPDATE: hero_text = ${newValue}`);
        setLastMessageTime(new Date());
      }
    };
    listenersRef.current.heroTextListener = heroTextListener;
    cfClient.addConfigListener<string>('hero_text', heroTextListener);

    // Add listener for enhanced_toast - similar to Flutter
    const enhancedToastListener = (isEnabled: boolean) => {
      console.log(`🚩 enhanced_toast config listener triggered with value: ${isEnabled}`);
      console.log(`  - Current enhancedToast state: ${enhancedToast}`);
      if (enhancedToast !== isEnabled) {
        setEnhancedToast(isEnabled);
        setFeatureFlags(prev => ({
          ...prev,
          'enhanced_toast': { variation: isEnabled }
        }));
      }
    };
    listenersRef.current.enhancedToastListener = enhancedToastListener;
    cfClient.addConfigListener<boolean>('enhanced_toast', enhancedToastListener);

    // Add connection status listener
    cfClient.addConnectionStatusListener({
      onConnectionStatusChanged: (status: ConnectionStatus) => {
        if (status === ConnectionStatus.CONNECTED) {
          console.log('📶 SDK Connected to server');
          setIsOffline(false);
        } else if (status === ConnectionStatus.DISCONNECTED) {
          console.log('📵 SDK Disconnected from server');
          setIsOffline(true);
        }
      }
    });

    console.log('✅ Config listeners set up successfully');
  };

  const toggleOfflineMode = async () => {
    if (!client) return;

    const newOfflineMode = !isOffline;
    client.setOfflineMode(newOfflineMode);
    console.log(`🌐 Offline mode: ${newOfflineMode}`);
    
    setLastConfigChangeMessage(`Offline mode: ${newOfflineMode ? 'ON' : 'OFF'}`);
    setLastMessageTime(new Date());
  };

  const trackEvent = async (eventName: string, properties: Record<string, any> = {}) => {
    if (!client) {
      console.log('⚠️ Event tracking skipped: Client not initialized');
      return;
    }
    
    await client.trackEvent(eventName, properties);
  };

  const addUserProperty = async (key: string, value: any) => {
    if (!client) return;
    
    client.addUserProperty(key, value);
  };

  const refreshFeatureFlags = async (eventName?: string): Promise<boolean> => {
    if (!client) return false;

    console.log('🔄 Manually refreshing feature flags...');

    // Track the refresh event if an event name is provided
    if (eventName) {
      await trackEvent(eventName, {
        'config_key': 'all',
        'refresh_source': 'user_action',
        'screen': 'home',
        'platform': 'react_native'
      });
    }

    // Force refresh from server
    const result = await client.forceRefresh();
    
    if (result.isSuccess) {
      // Values will be updated through listeners
      console.log('✅ Feature flags refreshed successfully from server');
      setLastConfigChangeMessage('Configuration manually refreshed');
    setLastMessageTime(new Date());
    return true;
    } else {
      console.log('⚠️ Failed to refresh flags');
      return false;
    }
  };

  useEffect(() => {
    // Only initialize once
    if (!initializationAttempted.current) {
      initialize();
    }
    
    // Cleanup on unmount
    return () => {
      if (client) {
        if (listenersRef.current.heroTextListener) {
          client.removeConfigListener('hero_text', listenersRef.current.heroTextListener);
        }
        if (listenersRef.current.enhancedToastListener) {
          client.removeConfigListener('enhanced_toast', listenersRef.current.enhancedToastListener);
        }
        client.shutdown();
      }
    };
  }, []); // Empty dependency array ensures this runs only once

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
    resetCircuitBreakers: () => {
      if (client) {
        console.log('🔧 Resetting circuit breakers...');
        client.resetCircuitBreakers();
      }
    },
  };

  return (
    <CustomFitContext.Provider value={value}>
      {children}
    </CustomFitContext.Provider>
  );
}; 