/**
 * Simple SessionManager Demo for React Native SDK
 * Node.js compatible demo without React Native dependencies
 */

// Mock AsyncStorage for Node.js environment
const AsyncStorage = (() => {
  const storage = new Map();
  
  return {
    getItem: async (key) => storage.get(key) || null,
    setItem: async (key, value) => storage.set(key, value),
    removeItem: async (key) => storage.delete(key)
  };
})();

// Mock the Logger for Node.js
const Logger = {
  info: (msg) => console.log('[INFO]', msg),
  debug: (msg) => console.log('[DEBUG]', msg),
  error: (msg) => console.error('[ERROR]', msg),
  warning: (msg) => console.warn('[WARN]', msg)
};

// Mock CFResult for Node.js
class CFResult {
  constructor(success, data, error) {
    this.isSuccess = success;
    this.isError = !success;
    this.data = data;
    this.error = error;
  }
  
  static success(data) {
    return new CFResult(true, data);
  }
  
  static errorFromException(error, category) {
    return new CFResult(false, null, { message: error.message, category });
  }
}

// Import the SessionManager classes (copy essential parts)
const RotationReason = {
  APP_START: 'Application started',
  MAX_DURATION_EXCEEDED: 'Maximum session duration exceeded',
  BACKGROUND_TIMEOUT: 'App was in background too long',
  AUTH_CHANGE: 'User authentication changed',
  MANUAL_ROTATION: 'Manually triggered rotation'
};

const DEFAULT_SESSION_CONFIG = {
  maxSessionDurationMs: 60 * 60 * 1000, // 60 minutes
  minSessionDurationMs: 5 * 60 * 1000,  // 5 minutes
  backgroundThresholdMs: 15 * 60 * 1000, // 15 minutes
  rotateOnAppRestart: true,
  rotateOnAuthChange: true,
  sessionIdPrefix: 'cf_session',
  enableTimeBasedRotation: true,
};

const createSessionData = (sessionId, rotationReason, appStartTime) => ({
  sessionId,
  createdAt: Date.now(),
  lastActiveAt: Date.now(),
  appStartTime: appStartTime || Date.now(),
  rotationReason,
});

const updateSessionActivity = (session) => ({
  ...session,
  lastActiveAt: Date.now(),
});

// Simplified SessionManager for demo
class SessionManager {
  static SESSION_STORAGE_KEY = 'cf_current_session';
  static LAST_APP_START_KEY = 'cf_last_app_start';
  static BACKGROUND_TIMESTAMP_KEY = 'cf_background_timestamp';
  
  static _instance = null;
  static _isInitializing = false;
  static _initPromise = null;

  static async initialize(config = DEFAULT_SESSION_CONFIG) {
    if (SessionManager._instance) {
      Logger.info('🔄 SessionManager already initialized, returning existing instance');
      return CFResult.success(SessionManager._instance);
    }

    if (SessionManager._isInitializing && SessionManager._initPromise) {
      Logger.info('🔄 SessionManager initialization in progress, waiting...');
      const manager = await SessionManager._initPromise;
      return CFResult.success(manager);
    }

    SessionManager._isInitializing = true;
    
    try {
      SessionManager._initPromise = (async () => {
        const manager = new SessionManager(config);
        await manager.initializeSession();
        
        SessionManager._instance = manager;
        SessionManager._isInitializing = false;
        
        Logger.info('🔄 SessionManager initialized with config: ' + JSON.stringify(config));
        return manager;
      })();

      const manager = await SessionManager._initPromise;
      return CFResult.success(manager);
    } catch (error) {
      SessionManager._isInitializing = false;
      SessionManager._initPromise = null;
      
      Logger.error('Failed to initialize SessionManager: ' + error);
      return CFResult.errorFromException(error, 'INTERNAL');
    }
  }

  static getInstance() {
    return SessionManager._instance;
  }

  static shutdown() {
    if (SessionManager._instance) {
      SessionManager._instance.listeners.clear();
      Logger.info('🔄 SessionManager shutdown');
    }
    SessionManager._instance = null;
    SessionManager._isInitializing = false;
    SessionManager._initPromise = null;
  }

  constructor(config) {
    this.config = config;
    this.currentSession = null;
    this.listeners = new Set();
    this.lastBackgroundTime = 0;
  }

  async initializeSession() {
    const currentAppStart = Date.now();
    const lastAppStart = await this.getLastAppStartTime();

    const isNewAppStart = lastAppStart === 0 || 
        (currentAppStart - lastAppStart) > this.config.minSessionDurationMs;

    if (isNewAppStart && this.config.rotateOnAppRestart) {
      await this.rotateSession(RotationReason.APP_START);
      await this.storeLastAppStartTime(currentAppStart);
    } else {
      await this.restoreOrCreateSession();
    }
  }

  getCurrentSessionId() {
    if (this.currentSession) {
      return this.currentSession.sessionId;
    } else {
      const sessionId = this.generateSessionId();
      this.currentSession = createSessionData(sessionId, RotationReason.APP_START);
      this.storeCurrentSession().catch(error => {
        Logger.error('Failed to store emergency session: ' + error);
      });
      return sessionId;
    }
  }

  getCurrentSession() {
    return this.currentSession;
  }

  async updateActivity() {
    const session = this.currentSession;
    if (!session) return;

    const now = Date.now();

    if (this.config.enableTimeBasedRotation && 
        this.shouldRotateForMaxDuration(session, now)) {
      await this.rotateSession(RotationReason.MAX_DURATION_EXCEEDED);
    } else {
      this.currentSession = updateSessionActivity(session);
      await this.storeCurrentSession();
    }
  }

  async onAppBackground() {
    this.lastBackgroundTime = Date.now();
    await this.storeBackgroundTime(this.lastBackgroundTime);
    Logger.debug('🔄 App went to background at: ' + this.lastBackgroundTime);
  }

  async onAppForeground() {
    const now = Date.now();
    const backgroundDuration = this.lastBackgroundTime > 0 ? now - this.lastBackgroundTime : 0;

    Logger.debug('🔄 App came to foreground after ' + backgroundDuration + ' ms in background');

    if (backgroundDuration > this.config.backgroundThresholdMs) {
      await this.rotateSession(RotationReason.BACKGROUND_TIMEOUT);
    } else {
      await this.updateActivityInternal();
    }

    this.lastBackgroundTime = 0;
  }

  async onAuthenticationChange(userId) {
    if (this.config.rotateOnAuthChange) {
      Logger.info('🔄 Authentication changed for user: ' + (userId || 'null'));
      await this.rotateSession(RotationReason.AUTH_CHANGE);
    }
  }

  async forceRotation() {
    await this.rotateSession(RotationReason.MANUAL_ROTATION);
    return this.currentSession.sessionId;
  }

  addListener(listener) {
    this.listeners.add(listener);
  }

  removeListener(listener) {
    this.listeners.delete(listener);
  }

  getSessionStats() {
    const session = this.currentSession;
    const now = Date.now();

    return {
      hasActiveSession: session !== null,
      sessionId: session?.sessionId || 'none',
      sessionAge: session ? now - session.createdAt : 0,
      lastActiveAge: session ? now - session.lastActiveAt : 0,
      backgroundTime: this.lastBackgroundTime,
      config: this.config,
      listenersCount: this.listeners.size,
    };
  }

  async restoreOrCreateSession() {
    const storedSession = await this.loadStoredSession();
    const now = Date.now();

    if (storedSession && this.isSessionValid(storedSession, now)) {
      this.currentSession = updateSessionActivity(storedSession);
      await this.storeCurrentSession();
      this.notifySessionRestored(storedSession.sessionId);
      Logger.info('🔄 Restored existing session: ' + storedSession.sessionId);
    } else {
      await this.rotateSession(RotationReason.APP_START);
    }
  }

  async rotateSession(reason) {
    const oldSessionId = this.currentSession?.sessionId || null;
    const newSessionId = this.generateSessionId();

    this.currentSession = createSessionData(newSessionId, reason);

    await this.storeCurrentSession();
    this.notifySessionRotated(oldSessionId, newSessionId, reason);

    Logger.info('🔄 Session rotated: ' + (oldSessionId || 'null') + ' -> ' + newSessionId + ' (' + reason + ')');
  }

  generateSessionId() {
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(2, 10);
    return `${this.config.sessionIdPrefix}_${timestamp}_${randomStr}`;
  }

  shouldRotateForMaxDuration(session, currentTime) {
    const sessionAge = currentTime - session.createdAt;
    return sessionAge >= this.config.maxSessionDurationMs;
  }

  isSessionValid(session, currentTime) {
    const sessionAge = currentTime - session.createdAt;
    const inactiveTime = currentTime - session.lastActiveAt;

    return sessionAge < this.config.maxSessionDurationMs &&
           inactiveTime < this.config.backgroundThresholdMs;
  }

  async updateActivityInternal() {
    const session = this.currentSession;
    if (!session) return;

    const now = Date.now();

    if (this.config.enableTimeBasedRotation && 
        this.shouldRotateForMaxDuration(session, now)) {
      await this.rotateSession(RotationReason.MAX_DURATION_EXCEEDED);
    } else {
      this.currentSession = updateSessionActivity(session);
      await this.storeCurrentSession();
    }
  }

  async storeCurrentSession() {
    const session = this.currentSession;
    if (!session) return;

    try {
      await AsyncStorage.setItem(SessionManager.SESSION_STORAGE_KEY, JSON.stringify(session));
    } catch (error) {
      Logger.error('Failed to store session: ' + error);
      this.notifySessionError(`Failed to store session: ${error}`);
    }
  }

  async loadStoredSession() {
    try {
      const sessionJson = await AsyncStorage.getItem(SessionManager.SESSION_STORAGE_KEY);
      
      if (sessionJson) {
        return JSON.parse(sessionJson);
      }
      return null;
    } catch (error) {
      Logger.error('Failed to load stored session: ' + error);
      return null;
    }
  }

  async storeLastAppStartTime(timestamp) {
    try {
      await AsyncStorage.setItem(SessionManager.LAST_APP_START_KEY, timestamp.toString());
    } catch (error) {
      Logger.error('Failed to store last app start time: ' + error);
    }
  }

  async getLastAppStartTime() {
    try {
      const timeStr = await AsyncStorage.getItem(SessionManager.LAST_APP_START_KEY);
      return timeStr ? parseInt(timeStr, 10) : 0;
    } catch (error) {
      Logger.error('Failed to get last app start time: ' + error);
      return 0;
    }
  }

  async storeBackgroundTime(timestamp) {
    try {
      await AsyncStorage.setItem(SessionManager.BACKGROUND_TIMESTAMP_KEY, timestamp.toString());
    } catch (error) {
      Logger.error('Failed to store background time: ' + error);
    }
  }

  notifySessionRotated(oldSessionId, newSessionId, reason) {
    for (const listener of this.listeners) {
      try {
        listener.onSessionRotated(oldSessionId, newSessionId, reason);
      } catch (error) {
        Logger.error('Error in session rotation listener: ' + error);
      }
    }
  }

  notifySessionRestored(sessionId) {
    for (const listener of this.listeners) {
      try {
        listener.onSessionRestored(sessionId);
      } catch (error) {
        Logger.error('Error in session restored listener: ' + error);
      }
    }
  }

  notifySessionError(error) {
    for (const listener of this.listeners) {
      try {
        listener.onSessionError(error);
      } catch (error) {
        Logger.error('Error in session error listener: ' + error);
      }
    }
  }
}

// Demo session listener
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

// Main demo function
async function runSimpleSessionDemo() {
  console.log('🚀 React Native SDK SessionManager Simple Demo');
  console.log('🎯 Strategy 1: Time-Based Rotation Implementation');
  console.log('================================================');

  try {
    // Custom configuration with short durations for demo
    const customConfig = {
      maxSessionDurationMs: 10 * 1000,     // 10 seconds for demo
      minSessionDurationMs: 2 * 1000,      // 2 seconds minimum  
      backgroundThresholdMs: 5 * 1000,     // 5 seconds background threshold
      rotateOnAppRestart: true,
      rotateOnAuthChange: true,
      sessionIdPrefix: 'demo_session',
      enableTimeBasedRotation: true,
    };

    console.log('\n📋 Custom Configuration:', JSON.stringify(customConfig, null, 2));

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
    const listener = new DemoSessionListener('Demo');
    sessionManager.addListener(listener);

    // Get initial session
    const initialSessionId = sessionManager.getCurrentSessionId();
    console.log('\n🆔 Initial session ID:', initialSessionId);

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

    // Simulate background timeout scenario
    console.log('\n📱 Simulating app lifecycle...');
    await sessionManager.onAppBackground();
    console.log('⏳ Waiting 6 seconds (background timeout)...');
    await new Promise(resolve => setTimeout(resolve, 6000));
    await sessionManager.onAppForeground();

    const finalSessionId = sessionManager.getCurrentSessionId();
    console.log('🆔 Session ID after background timeout:', finalSessionId);

    // Final statistics
    stats = sessionManager.getSessionStats();
    console.log('\n📊 Final session statistics:', JSON.stringify(stats, null, 2));

    // Cleanup
    SessionManager.shutdown();
    console.log('\n🛑 SessionManager shutdown');

    console.log('\n✅ Demo completed successfully!');
    console.log('\n🎉 SessionManager Features Demonstrated:');
    console.log('   ✓ Singleton pattern initialization');
    console.log('   ✓ Session ID generation and tracking');
    console.log('   ✓ Authentication change rotation');
    console.log('   ✓ Manual rotation capability');
    console.log('   ✓ Background timeout rotation');
    console.log('   ✓ Persistent storage with AsyncStorage');
    console.log('   ✓ Session statistics and monitoring');
    console.log('   ✓ Event listeners for session changes');
    console.log('   ✓ Comprehensive error handling');

  } catch (error) {
    console.error('❌ Demo failed:', error);
    console.error(error.stack);
  }
}

// Run the demo
if (require.main === module) {
  runSimpleSessionDemo();
}

module.exports = {
  runSimpleSessionDemo,
  SessionManager,
  DemoSessionListener
}; 