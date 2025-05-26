// Patch for CustomFit React Native SDK to work with local proxy
// This patches the SDK constants to use relative URLs when running locally

if (typeof window !== 'undefined' && window.location.hostname === 'localhost') {
  console.log('🔧 Patching CustomFit SDK for local development...');
  
  // Wait for the SDK to be loaded
  setTimeout(() => {
    try {
      // Access the SDK's constants through the global require cache
      const moduleCache = require.cache || {};
      
      Object.keys(moduleCache).forEach(key => {
        if (key.includes('customfit') && key.includes('CFConstants')) {
          const constantsModule = moduleCache[key];
          if (constantsModule && constantsModule.exports && constantsModule.exports.CFConstants) {
            const CFConstants = constantsModule.exports.CFConstants;
            
            // Patch the API URLs to use relative paths
            console.log('🔧 Patching API URLs...');
            CFConstants.Api.BASE_API_URL = '';
            CFConstants.Api.SDK_SETTINGS_BASE_URL = '';
            
            console.log('✅ SDK patched for local development');
          }
        }
      });
    } catch (e) {
      console.error('Failed to patch SDK:', e);
    }
  }, 100);
}

export default {}; 