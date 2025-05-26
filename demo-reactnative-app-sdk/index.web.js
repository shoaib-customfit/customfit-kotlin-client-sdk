import { AppRegistry } from 'react-native';
import App from './App';

// Register the app for web
AppRegistry.registerComponent('customfit-reactnative-demo', () => App);

// Ensure the DOM is ready and run the app
const runApp = () => {
  const rootTag = document.getElementById('root');
  if (rootTag) {
    AppRegistry.runApplication('customfit-reactnative-demo', {
      initialProps: {},
      rootTag: rootTag,
    });
  } else {
    console.error('Root element not found!');
  }
};

// Run when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', runApp);
} else {
  runApp();
} 