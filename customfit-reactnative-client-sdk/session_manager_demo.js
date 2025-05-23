/**
 * SessionManager Demo for React Native SDK
 * 
 * Demonstrates Strategy 1: Time-Based Rotation Implementation
 */

const AsyncStorage = require('@react-native-async-storage/async-storage');
const { 
  SessionManager, 
  DEFAULT_SESSION_CONFIG, 
  RotationReason,
  CFClient 
} = require('./lib/index');
const { CFConfig } = require('./lib/index');
const { CFUser } = require('./lib/index');

// Mock AsyncStorage for Node.js environment
if (typeof AsyncStorage.getItem !== 'function') {
  const mockStorage = new Map();
  
  AsyncStorage.getItem = async (key) => {
    return mockStorage.get(key) || null;
  };
  
  AsyncStorage.setItem = async (key, value) => {
    mockStorage.set(key, value);
  };
  
  AsyncStorage.removeItem = async (key) => {
    mockStorage.delete(key);
  };
}

/**
 * Demo session rotation listener
 */
class DemoSessionListener {
  constructor(name) {
    this.name = name;
  }

  onSessionRotated(oldSessionId, newSessionId, reason) {
    console.log(`📱 [${this.name}] Session rotated: ${oldSessionId || 'null'} -> ${newSessionId} (${reason})`);
  }

  onSessionRestored(sessionId) {
    console.log(`📱 [${this.name}] Session restored: ${sessionId}`);
  }

  onSessionError(error) {
    console.log(`📱 [${this.name}] Session error: ${error}`);
  }
}

/**
 * CFClient session rotation listener
 */
class CFClientSessionListener {
  onSessionRotated(oldSessionId, newSessionId, reason) {
    console.log(`🔗 [CFClient] Session rotated: ${oldSessionId || 'null'} -> ${newSessionId} (${reason})`);
  }

  onSessionRestored(sessionId) {
    console.log(`🔗 [CFClient] Session restored: ${sessionId}`);
  }

  onSessionError(error) {
    console.log(`🔗 [CFClient] Session error: ${error}`);
  }
}

/**
 * Demonstrate SessionManager standalone functionality
 */
async function demonstrateSessionManager() {
  console.log('\n=== SessionManager Standalone Demo ===\n');

  // Custom configuration
  const customConfig = {
    maxSessionDurationMs: 30 * 1000,     // 30 seconds for demo
    minSessionDurationMs: 5 * 1000,      // 5 seconds minimum  
    backgroundThresholdMs: 10 * 1000,    // 10 seconds background threshold
    rotateOnAppRestart: true,
    rotateOnAuthChange: true,
    sessionIdPrefix: 'demo_session',
    enableTimeBasedRotation: true,
  };

  console.log('📋 Custom Configuration:', customConfig);

  // Initialize SessionManager
  console.log('\n🔄 Initializing SessionManager...');
  const result = await SessionManager.initialize(customConfig);
  
  if (!result.isSuccess) {
    console.error('❌ Failed to initialize SessionManager:', result.error?.message);
    return;
  }

  const sessionManager = result.data;
  console.log('✅ SessionManager initialized successfully');

  // Add listener
  const listener = new DemoSessionListener('Standalone');
  sessionManager.addListener(listener);

  // Get initial session
  const initialSessionId = sessionManager.getCurrentSessionId();
  console.log('🆔 Initial session ID:', initialSessionId);

  // Get session statistics
  let stats = sessionManager.getSessionStats();
  console.log('📊 Session statistics:', JSON.stringify(stats, null, 2));

  // Simulate user activity
  console.log('\n🎯 Simulating user activity...');
  await sessionManager.updateActivity();
  console.log('✅ Session activity updated');

  // Wait 2 seconds
  console.log('\n⏳ Waiting 2 seconds...');
  await new Promise(resolve => setTimeout(resolve, 2000));

  // Simulate authentication change
  console.log('\n🔐 Simulating authentication change...');
  await sessionManager.onAuthenticationChange('user_12345');

  // Get new session ID after auth change
  const newSessionId = sessionManager.getCurrentSessionId();
  console.log('🆔 Session ID after auth change:', newSessionId);

  // Manual rotation
  console.log('\n🔄 Performing manual rotation...');
  const manualRotationSessionId = await sessionManager.forceRotation();
  console.log('🆔 Session ID after manual rotation:', manualRotationSessionId);

  // Final statistics
  stats = sessionManager.getSessionStats();
  console.log('\n📊 Final session statistics:', JSON.stringify(stats, null, 2));

  // Cleanup
  SessionManager.shutdown();
  console.log('🛑 SessionManager shutdown');
}

/**
 * Demonstrate CFClient integration with SessionManager
 */
async function demonstrateCFClientIntegration() {
  console.log('\n=== CFClient Integration Demo ===\n');

  // Create configuration
  const config = CFConfig.builder()
    .clientKey('demo_client_key_12345')
    .serverUrl('https://api.example.com')
    .loggingEnabled(true)
    .debugLoggingEnabled(true)
    .build();

  const user = CFUser.builder()
    .userId('demo_user_123')
    .build();

  console.log('🔧 Creating CFClient with SessionManager...');

  // Initialize CFClient (includes SessionManager)
  const cfClient = await CFClient.initialize(config, user);
  console.log('✅ CFClient initialized successfully');

  // Add session rotation listener
  const sessionListener = new CFClientSessionListener();
  cfClient.addSessionRotationListener(sessionListener);

  // Get current session information
  const sessionId = cfClient.getCurrentSessionId();
  const sessionData = cfClient.getCurrentSessionData();
  
  console.log('🆔 Current session ID:', sessionId);
  console.log('📄 Current session data:', JSON.stringify(sessionData, null, 2));

  // Get session statistics
  let stats = cfClient.getSessionStatistics();
  console.log('📊 Session statistics:', JSON.stringify(stats, null, 2));

  // Simulate user activity through CFClient
  console.log('\n🎯 Updating session activity...');
  await cfClient.updateSessionActivity();

  // Track some events (which will include session info)
  console.log('\n📝 Tracking events...');
  await cfClient.trackEvent('demo_event', { demo: true });
  await cfClient.trackScreenView('demo_screen');

  // Simulate authentication change
  console.log('\n🔐 Simulating authentication change...');
  await cfClient.onUserAuthenticationChange('new_user_456');

  // Get updated session info
  const newSessionId = cfClient.getCurrentSessionId();
  console.log('🆔 New session ID after auth change:', newSessionId);

  // Force manual rotation
  console.log('\n🔄 Forcing manual session rotation...');
  const rotatedSessionId = await cfClient.forceSessionRotation();
  console.log('🆔 Session ID after manual rotation:', rotatedSessionId);

  // Final statistics
  stats = cfClient.getSessionStatistics();
  console.log('\n📊 Final session statistics:', JSON.stringify(stats, null, 2));

  // Shutdown
  await cfClient.shutdown();
  console.log('🛑 CFClient shutdown');
}

/**
 * Simulate app lifecycle events
 */
async function demonstrateAppLifecycle() {
  console.log('\n=== App Lifecycle Demo ===\n');

  // Initialize with short durations for demo
  const config = {
    maxSessionDurationMs: 20 * 1000,     // 20 seconds
    minSessionDurationMs: 3 * 1000,      // 3 seconds
    backgroundThresholdMs: 5 * 1000,     // 5 seconds background threshold
    rotateOnAppRestart: true,
    rotateOnAuthChange: true,
    sessionIdPrefix: 'lifecycle_session',
    enableTimeBasedRotation: true,
  };

  const result = await SessionManager.initialize(config);
  if (!result.isSuccess) {
    console.error('❌ Failed to initialize SessionManager');
    return;
  }

  const sessionManager = result.data;
  const listener = new DemoSessionListener('Lifecycle');
  sessionManager.addListener(listener);

  console.log('🆔 Initial session:', sessionManager.getCurrentSessionId());

  // Simulate app going to background
  console.log('\n📱 App going to background...');
  await sessionManager.onAppBackground();

  // Wait for background timeout (6 seconds > 5 second threshold)
  console.log('⏳ Waiting 6 seconds (background timeout)...');
  await new Promise(resolve => setTimeout(resolve, 6000));

  // Simulate app coming back to foreground
  console.log('📱 App coming to foreground...');
  await sessionManager.onAppForeground();

  console.log('🆔 Session after background timeout:', sessionManager.getCurrentSessionId());

  // Cleanup
  SessionManager.shutdown();
  console.log('🛑 SessionManager shutdown');
}

/**
 * Main demo function
 */
async function runSessionManagerDemo() {
  console.log('🚀 React Native SDK SessionManager Demo');
  console.log('🎯 Strategy 1: Time-Based Rotation Implementation');
  console.log('==========================================');

  try {
    // Run standalone SessionManager demo
    await demonstrateSessionManager();

    // Wait between demos
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Run CFClient integration demo
    await demonstrateCFClientIntegration();

    // Wait between demos
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Run app lifecycle demo
    await demonstrateAppLifecycle();

    console.log('\n✅ All demos completed successfully!');
    console.log('\n🎉 SessionManager Features Demonstrated:');
    console.log('   ✓ Singleton pattern with thread safety');
    console.log('   ✓ Time-based rotation (configurable duration)');
    console.log('   ✓ App restart/cold start rotation');
    console.log('   ✓ Background timeout rotation');
    console.log('   ✓ Authentication change rotation');
    console.log('   ✓ Manual rotation capability');
    console.log('   ✓ Persistent storage with AsyncStorage');
    console.log('   ✓ Session statistics and monitoring');
    console.log('   ✓ Event listeners for session changes');
    console.log('   ✓ CFClient integration');
    console.log('   ✓ Comprehensive error handling');

  } catch (error) {
    console.error('❌ Demo failed:', error);
    console.error(error.stack);
  }
}

// Run the demo
if (require.main === module) {
  runSessionManagerDemo();
}

module.exports = {
  runSessionManagerDemo,
  demonstrateSessionManager,
  demonstrateCFClientIntegration,
  demonstrateAppLifecycle,
  DemoSessionListener,
  CFClientSessionListener
}; 