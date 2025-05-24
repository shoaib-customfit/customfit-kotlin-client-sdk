import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

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
  const [isInitialized, setIsInitialized] = useState(false);
  const [featureFlags, setFeatureFlags] = useState<Record<string, any>>({});
  const [heroText, setHeroText] = useState('CF DEMO');
  const [enhancedToast, setEnhancedToast] = useState(false);
  const [isOffline, setIsOffline] = useState(false);
  const [lastConfigChangeMessage, setLastConfigChangeMessage] = useState<string | null>(null);
  const [lastMessageTime, setLastMessageTime] = useState<Date | null>(null);

  const hasNewConfigMessage = lastMessageTime !== null && 
    (Date.now() - lastMessageTime.getTime()) < 5 * 60 * 1000; // 5 minutes

  const initialize = async () => {
    try {
      console.log('Initializing CustomFit provider...');
      
      // Simulate initialization delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      setIsInitialized(true);
      
      // Set initial feature flags
      setFeatureFlags({
        'hero_text': { variation: 'CF DEMO' },
        'enhanced_toast': { variation: false },
      });
      
      console.log('✅ CustomFit provider initialized successfully');
    } catch (error) {
      console.error('❌ Failed to initialize CustomFit provider:', error);
      setIsInitialized(true); // Still show UI
    }
  };

  const toggleOfflineMode = async () => {
    setIsOffline(!isOffline);
    console.log(`🌐 Offline mode: ${!isOffline}`);
    
    setLastConfigChangeMessage(`Offline mode: ${!isOffline ? 'ON' : 'OFF'}`);
    setLastMessageTime(new Date());
  };

  const trackEvent = async (eventName: string, properties: Record<string, any> = {}) => {
    if (!isInitialized) {
      console.log('⚠️ Event tracking skipped: Provider not initialized');
      return;
    }
    
    console.log(`📊 Event tracked: ${eventName}`, properties);
  };

  const addUserProperty = async (key: string, value: any) => {
    if (!isInitialized) return;
    
    console.log(`👤 User property added: ${key} = ${value}`);
  };

  const refreshFeatureFlags = async (eventName?: string): Promise<boolean> => {
    if (!isInitialized) return false;

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

    // Simulate config refresh with random values
    const newHeroText = `CF RN Demo-${Math.floor(Math.random() * 100)}`;
    const newEnhancedToast = Math.random() > 0.5;
    
    setHeroText(newHeroText);
    setEnhancedToast(newEnhancedToast);
    
    setFeatureFlags({
      'hero_text': { variation: newHeroText },
      'enhanced_toast': { variation: newEnhancedToast },
    });

    setLastConfigChangeMessage('Configuration manually refreshed');
    setLastMessageTime(new Date());

    console.log('✅ Flags refreshed successfully');
    return true;
  };

  useEffect(() => {
    initialize();
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