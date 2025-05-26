// Polyfill for react-native modules when running on web
import { Platform as PlatformWeb, AppState as AppStateWeb } from 'react-native-web';

export const Platform = PlatformWeb || {
  OS: 'web',
  Version: 1,
  select: (obj) => obj.web || obj.default,
  isPad: false,
  isTVOS: false,
  isTV: false,
};

export const AppState = AppStateWeb || {
  currentState: 'active',
  addEventListener: (type, handler) => {
    if (type === 'change') {
      const listener = () => {
        handler(document.hidden ? 'background' : 'active');
      };
      document.addEventListener('visibilitychange', listener);
      return {
        remove: () => document.removeEventListener('visibilitychange', listener)
      };
    }
    return { remove: () => {} };
  },
  removeEventListener: () => {},
};

// Export everything from react-native-web
export * from 'react-native-web'; 