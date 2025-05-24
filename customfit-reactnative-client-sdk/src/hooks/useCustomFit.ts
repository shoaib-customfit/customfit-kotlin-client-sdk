import { useState, useEffect, useCallback, useRef } from 'react';
import { CFClient } from '../client/CFClient';
import { 
  FeatureFlagChangeListener, 
  AllFlagsChangeListener, 
  ConnectionStatusListener,
  ConnectionStatus 
} from '../core/types/CFTypes';

/**
 * Hook for getting a feature flag value
 */
export function useFeatureFlag<T = boolean>(key: string, defaultValue: T): T {
  const [value, setValue] = useState<T>(defaultValue);
  const listenerRef = useRef<FeatureFlagChangeListener | null>(null);

  useEffect(() => {
    const client = CFClient.getInstance();
    if (!client) {
      return;
    }

    // Get initial value
    const initialValue = client.getFeatureFlag(key, defaultValue);
    setValue(initialValue);

    // Set up listener for changes
    const listener: FeatureFlagChangeListener = {
      onFeatureFlagChanged: (flagKey: string, oldValue: any, newValue: any) => {
        if (flagKey === key) {
          setValue(newValue);
        }
      }
    };

    listenerRef.current = listener;
    client.addFeatureFlagListener(key, listener);

    // Cleanup
    return () => {
      if (client && listenerRef.current) {
        client.removeFeatureFlagListener(key, listenerRef.current);
      }
    };
  }, [key, defaultValue]);

  return value;
}

/**
 * Hook for getting a feature value (alias for useFeatureFlag)
 */
export function useFeatureValue<T>(key: string, defaultValue: T): T {
  return useFeatureFlag(key, defaultValue);
}

/**
 * Hook for getting all feature flags
 */
export function useAllFeatureFlags(): Record<string, any> {
  const [flags, setFlags] = useState<Record<string, any>>({});
  const listenerRef = useRef<AllFlagsChangeListener | null>(null);

  useEffect(() => {
    const client = CFClient.getInstance();
    if (!client) {
      return;
    }

    // Get initial flags
    const initialFlags = client.getAllFlags();
    setFlags(initialFlags);

    // Set up listener for changes
    const listener: AllFlagsChangeListener = {
      onAllFlagsChanged: (newFlags: Record<string, any>) => {
        setFlags(newFlags);
      }
    };

    listenerRef.current = listener;
    client.addAllFlagsListener(listener);

    // Cleanup
    return () => {
      if (client && listenerRef.current) {
        client.removeAllFlagsListener(listenerRef.current);
      }
    };
  }, []);

  return flags;
}

/**
 * Hook for SDK status and utilities
 */
export function useCustomFit() {
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>(ConnectionStatus.UNKNOWN);
  const [isInitialized, setIsInitialized] = useState<boolean>(false);
  const listenerRef = useRef<ConnectionStatusListener | null>(null);

  useEffect(() => {
    const client = CFClient.getInstance();
    if (!client) {
      setIsInitialized(false);
      return;
    }

    setIsInitialized(true);

    // Set up connection status listener
    const listener: ConnectionStatusListener = {
      onConnectionStatusChanged: (status: ConnectionStatus) => {
        setConnectionStatus(status);
      }
    };

    listenerRef.current = listener;
    client.addConnectionStatusListener(listener);

    // Cleanup
    return () => {
      if (client && listenerRef.current) {
        client.removeConnectionStatusListener(listenerRef.current);
      }
    };
  }, []);

  const trackEvent = useCallback(async (name: string, properties?: Record<string, any>) => {
    const client = CFClient.getInstance();
    if (!client) {
      console.warn('CFClient not initialized');
      return;
    }

    return await client.trackEvent(name, properties);
  }, []);



  const forceRefresh = useCallback(async () => {
    const client = CFClient.getInstance();
    if (!client) {
      console.warn('CFClient not initialized');
      return;
    }

    return await client.forceRefresh();
  }, []);

  const flushEvents = useCallback(async () => {
    const client = CFClient.getInstance();
    if (!client) {
      console.warn('CFClient not initialized');
      return;
    }

    return await client.flushEvents();
  }, []);

  const flushSummaries = useCallback(async () => {
    const client = CFClient.getInstance();
    if (!client) {
      console.warn('CFClient not initialized');
      return;
    }

    return await client.flushSummaries();
  }, []);

  const setUserAttribute = useCallback((key: string, value: any) => {
    const client = CFClient.getInstance();
    if (!client) {
      console.warn('CFClient not initialized');
      return;
    }

    client.addUserProperty(key, value);
  }, []);

  const setUserAttributes = useCallback((attributes: Record<string, any>) => {
    const client = CFClient.getInstance();
    if (!client) {
      console.warn('CFClient not initialized');
      return;
    }

    client.addUserProperties(attributes);
  }, []);

  const setOfflineMode = useCallback((offline: boolean) => {
    const client = CFClient.getInstance();
    if (!client) {
      console.warn('CFClient not initialized');
      return;
    }

    client.setOfflineMode(offline);
  }, []);

  const getMetrics = useCallback(() => {
    const client = CFClient.getInstance();
    if (!client) {
      console.warn('CFClient not initialized');
      return null;
    }

    return client.getMetrics();
  }, []);

  return {
    // Status
    isInitialized,
    connectionStatus,
    isConnected: connectionStatus === ConnectionStatus.CONNECTED,
    isOffline: connectionStatus === ConnectionStatus.DISCONNECTED,

    // Event tracking
    trackEvent,

    // Configuration
    forceRefresh,

    // Data management
    flushEvents,
    flushSummaries,

    // User management
    setUserAttribute,
    setUserAttributes,

    // Settings
    setOfflineMode,

    // Metrics
    getMetrics,
  };
}

 