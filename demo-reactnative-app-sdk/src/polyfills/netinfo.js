// Polyfill for @react-native-community/netinfo for web
const NetInfo = {
  addEventListener(listener) {
    const handler = () => {
      listener({
        type: navigator.onLine ? 'wifi' : 'none',
        isConnected: navigator.onLine,
        isInternetReachable: navigator.onLine,
        details: {
          isConnectionExpensive: false,
          cellularGeneration: null,
          carrier: null,
        }
      });
    };

    window.addEventListener('online', handler);
    window.addEventListener('offline', handler);

    // Return unsubscribe function
    return () => {
      window.removeEventListener('online', handler);
      window.removeEventListener('offline', handler);
    };
  },

  async fetch() {
    return {
      type: navigator.onLine ? 'wifi' : 'none',
      isConnected: navigator.onLine,
      isInternetReachable: navigator.onLine,
      details: {
        isConnectionExpensive: false,
        cellularGeneration: null,
        carrier: null,
      }
    };
  },

  configure(configuration) {
    // No-op for web
    console.log('NetInfo.configure called with:', configuration);
  },

  // Add isConnected property for compatibility
  isConnected: {
    addEventListener(listener) {
      const handler = () => listener(navigator.onLine);
      window.addEventListener('online', handler);
      window.addEventListener('offline', handler);
      
      return () => {
        window.removeEventListener('online', handler);
        window.removeEventListener('offline', handler);
      };
    },
    
    fetch() {
      return Promise.resolve(navigator.onLine);
    }
  }
};

export default NetInfo; 