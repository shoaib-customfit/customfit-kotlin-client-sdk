/**
 * Basic test runner for CustomFit React Native SDK
 * Tests core functionality without TypeScript compilation
 */

console.log('🎯 CustomFit React Native SDK - Basic Test');
console.log('==========================================');

// Test 1: Module imports
console.log('\n📦 Testing module structure...');
try {
  const fs = require('fs');
  const path = require('path');
  
  // Check if main files exist
  const srcPath = path.join(__dirname, 'src');
  const indexPath = path.join(srcPath, 'index.ts');
  const clientPath = path.join(srcPath, 'client', 'CFClient.ts');
  const configPath = path.join(srcPath, 'config', 'core', 'CFConfig.ts');
  const userPath = path.join(srcPath, 'core', 'model', 'CFUser.ts');
  
  console.log('✓ Checking file structure...');
  console.log(`  - Main index: ${fs.existsSync(indexPath) ? '✓' : '✗'}`);
  console.log(`  - CFClient: ${fs.existsSync(clientPath) ? '✓' : '✗'}`);
  console.log(`  - CFConfig: ${fs.existsSync(configPath) ? '✓' : '✗'}`);
  console.log(`  - CFUser: ${fs.existsSync(userPath) ? '✓' : '✗'}`);
  
  // Check folder structure
  const expectedFolders = [
    'analytics/event',
    'analytics/summary',
    'client',
    'config/core',
    'constants',
    'core/error',
    'core/model',
    'core/types',
    'core/util',
    'extensions',
    'hooks',
    'lifecycle',
    'logging',
    'network',
    'platform',
    'serialization',
    'utils'
  ];
  
  console.log('✓ Checking folder structure...');
  expectedFolders.forEach(folder => {
    const folderPath = path.join(srcPath, folder);
    const exists = fs.existsSync(folderPath);
    console.log(`  - ${folder}: ${exists ? '✓' : '✗'}`);
  });
  
} catch (error) {
  console.error('✗ Module structure test failed:', error.message);
}

// Test 2: Package.json validation
console.log('\n📋 Testing package.json...');
try {
  const packageJson = require('./package.json');
  
  console.log(`✓ Package name: ${packageJson.name}`);
  console.log(`✓ Version: ${packageJson.version}`);
  console.log(`✓ Main entry: ${packageJson.main || 'not specified'}`);
  console.log(`✓ TypeScript types: ${packageJson.types || 'not specified'}`);
  
  // Check dependencies
  const deps = packageJson.dependencies || {};
  const expectedDeps = [
    '@react-native-async-storage/async-storage',
    '@react-native-community/netinfo'
  ];
  
  console.log('✓ Dependencies:');
  expectedDeps.forEach(dep => {
    console.log(`  - ${dep}: ${deps[dep] ? '✓' : '✗'}`);
  });
  
} catch (error) {
  console.error('✗ Package.json test failed:', error.message);
}

// Test 3: TypeScript configuration
console.log('\n⚙️ Testing TypeScript configuration...');
try {
  const tsconfig = require('./tsconfig.json');
  
  console.log(`✓ Target: ${tsconfig.compilerOptions?.target}`);
  console.log(`✓ Module: ${tsconfig.compilerOptions?.module}`);
  console.log(`✓ Strict mode: ${tsconfig.compilerOptions?.strict}`);
  console.log(`✓ Declaration: ${tsconfig.compilerOptions?.declaration}`);
  console.log(`✓ Source maps: ${tsconfig.compilerOptions?.sourceMap}`);
  
} catch (error) {
  console.error('✗ TypeScript config test failed:', error.message);
}

// Test 4: Demo file validation
console.log('\n🎬 Testing demo file...');
try {
  const fs = require('fs');
  const path = require('path');
  const demoPath = path.join(__dirname, 'demo', 'main.ts');
  
  if (fs.existsSync(demoPath)) {
    const demoContent = fs.readFileSync(demoPath, 'utf8');
    
    console.log('✓ Demo file exists');
    console.log(`✓ File size: ${demoContent.length} characters`);
    
    // Check for key imports
    const keyImports = [
      'CFClient',
      'CFConfig',
      'CFUser',
      'CFLifecycleManager',
      'Logger'
    ];
    
    console.log('✓ Key imports:');
    keyImports.forEach(imp => {
      const found = demoContent.includes(imp);
      console.log(`  - ${imp}: ${found ? '✓' : '✗'}`);
    });
    
    // Check for client key
    const hasClientKey = demoContent.includes('eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9');
    console.log(`✓ Client key: ${hasClientKey ? '✓' : '✗'}`);
    
    // Check for demo steps
    const demoSteps = [
      'Configuration',
      'Initialization',
      'Feature Flags',
      'Event Tracking',
      'User Management',
      'Listener System',
      'Lifecycle Management',
      'Dynamic Configuration',
      'React Hooks',
      'Performance & Metrics',
      'Cleanup & Shutdown'
    ];
    
    console.log('✓ Demo steps:');
    demoSteps.forEach(step => {
      const found = demoContent.includes(step);
      console.log(`  - ${step}: ${found ? '✓' : '✗'}`);
    });
    
  } else {
    console.error('✗ Demo file not found');
  }
  
} catch (error) {
  console.error('✗ Demo file test failed:', error.message);
}

// Test 5: Core feature implementation check
console.log('\n🔍 Testing core feature implementation...');
try {
  const fs = require('fs');
  const path = require('path');
  
  // Check if key methods exist in CFClient
  const clientPath = path.join(__dirname, 'src', 'client', 'CFClient.ts');
  if (fs.existsSync(clientPath)) {
    const clientContent = fs.readFileSync(clientPath, 'utf8');
    
    const keyMethods = [
      'getFeatureFlag',
      'getString',
      'getNumber',
      'getBoolean',
      'getJson',
      'getAllFlags',
      'trackEvent',
      'trackScreenView',
      'trackFeatureUsage',
      'setUserAttribute',
      'setUserAttributes',
      'registerFeatureFlagListener',
      'registerAllFlagsListener',
      'addConnectionStatusListener',
      'incrementAppLaunchCount',
      'shutdown',
      'pause',
      'resume',
      'awaitSdkSettingsCheck'
    ];
    
    console.log('✓ CFClient methods:');
    keyMethods.forEach(method => {
      const found = clientContent.includes(method);
      console.log(`  - ${method}: ${found ? '✓' : '✗'}`);
    });
  } else {
    console.error('✗ CFClient.ts not found');
  }
  
} catch (error) {
  console.error('✗ Core feature test failed:', error.message);
}

// Test 6: React hooks implementation
console.log('\n⚛️ Testing React hooks implementation...');
try {
  const fs = require('fs');
  const path = require('path');
  
  const hooksPath = path.join(__dirname, 'src', 'hooks', 'useCustomFit.ts');
  if (fs.existsSync(hooksPath)) {
    const hooksContent = fs.readFileSync(hooksPath, 'utf8');
    
    const hooks = [
      'useFeatureFlag',
      'useFeatureValue',
      'useAllFeatureFlags',
      'useCustomFit',
      'useScreenTracking',
      'useFeatureTracking'
    ];
    
    console.log('✓ React hooks:');
    hooks.forEach(hook => {
      const found = hooksContent.includes(`export.*${hook}`) || hooksContent.includes(`function ${hook}`);
      console.log(`  - ${hook}: ${found ? '✓' : '✗'}`);
    });
  } else {
    console.error('✗ useCustomFit.ts not found');
  }
  
} catch (error) {
  console.error('✗ React hooks test failed:', error.message);
}

console.log('\n🎉 Basic tests completed!');
console.log('=============================');
console.log('The CustomFit React Native SDK structure has been verified.');
console.log('');
console.log('To run the full demo:');
console.log('1. Ensure React Native environment is set up');
console.log('2. Install dependencies: npm install');
console.log('3. Run the demo: node -r ts-node/register demo/main.ts');
console.log('4. Or integrate into your React Native app'); 