/**
 * Session Management for React Native SDK
 * 
 * Strategy 1: Time-Based Rotation Implementation
 * - Rotates every 30-60 minutes of active use
 * - Rotates on app restart/cold start
 * - Rotates when app returns from background after >15 minutes
 * - Rotates on user authentication changes
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import { CFResult } from '../error/CFResult';
import { ErrorCategory } from '../types/CFTypes';
import { Logger } from '../../logging/Logger';

// MARK: - Session Configuration

/**
 * Configuration for session management
 */
export interface SessionConfig {
  /** Maximum session duration in milliseconds (default: 60 minutes) */
  readonly maxSessionDurationMs: number;
  
  /** Minimum session duration in milliseconds (default: 5 minutes) */
  readonly minSessionDurationMs: number;
  
  /** Background threshold - rotate if app was in background longer than this (default: 15 minutes) */
  readonly backgroundThresholdMs: number;
  
  /** Force rotation on app restart */
  readonly rotateOnAppRestart: boolean;
  
  /** Force rotation on user authentication changes */
  readonly rotateOnAuthChange: boolean;
  
  /** Session ID prefix for identification */
  readonly sessionIdPrefix: string;
  
  /** Enable automatic rotation based on time */
  readonly enableTimeBasedRotation: boolean;
}

/**
 * Default session configuration
 */
export const DEFAULT_SESSION_CONFIG: SessionConfig = {
  maxSessionDurationMs: 60 * 60 * 1000, // 60 minutes
  minSessionDurationMs: 5 * 60 * 1000,  // 5 minutes
  backgroundThresholdMs: 15 * 60 * 1000, // 15 minutes
  rotateOnAppRestart: true,
  rotateOnAuthChange: true,
  sessionIdPrefix: 'cf_session',
  enableTimeBasedRotation: true,
};

// MARK: - Session Data

/**
 * Represents a session with metadata
 */
export interface SessionData {
  readonly sessionId: string;
  readonly createdAt: number;
  readonly lastActiveAt: number;
  readonly appStartTime: number;
  readonly rotationReason?: string;
}

/**
 * Create SessionData with current timestamp
 */
export const createSessionData = (
  sessionId: string,
  rotationReason?: string,
  appStartTime?: number
): SessionData => ({
  sessionId,
  createdAt: Date.now(),
  lastActiveAt: Date.now(),
  appStartTime: appStartTime || Date.now(),
  rotationReason,
});

/**
 * Update SessionData with new activity timestamp
 */
export const updateSessionActivity = (session: SessionData): SessionData => ({
  ...session,
  lastActiveAt: Date.now(),
});

// MARK: - Rotation Reason

/**
 * Reasons for session rotation
 */
export enum RotationReason {
  APP_START = 'Application started',
  MAX_DURATION_EXCEEDED = 'Maximum session duration exceeded',
  BACKGROUND_TIMEOUT = 'App was in background too long',
  AUTH_CHANGE = 'User authentication changed',
  MANUAL_ROTATION = 'Manually triggered rotation',
  NETWORK_CHANGE = 'Network connectivity changed',
  STORAGE_ERROR = 'Session storage error occurred',
}

// MARK: - Session Rotation Listener

/**
 * Session rotation listener interface
 */
export interface SessionRotationListener {
  onSessionRotated(oldSessionId: string | null, newSessionId: string, reason: RotationReason): void;
  onSessionRestored(sessionId: string): void;
  onSessionError(error: string): void;
}

// MARK: - Session Manager

/**
 * Manages session IDs with time-based rotation strategy
 *
 * Strategy 1: Time-Based Rotation
 * - Rotates every 30-60 minutes of active use
 * - Rotates on app restart/cold start
 * - Rotates when app returns from background after >15 minutes
 * - Rotates on user authentication changes
 */
export class SessionManager {
  
  // MARK: - Constants
  
  private static readonly SESSION_STORAGE_KEY = 'cf_current_session';
  private static readonly LAST_APP_START_KEY = 'cf_last_app_start';
  private static readonly BACKGROUND_TIMESTAMP_KEY = 'cf_background_timestamp';
  
  // MARK: - Singleton
  
  private static _instance: SessionManager | null = null;
  private static _isInitializing = false;
  private static _initPromise: Promise<SessionManager> | null = null;

  /**
   * Initialize the SessionManager singleton
   */
  static async initialize(config: SessionConfig = DEFAULT_SESSION_CONFIG): Promise<CFResult<SessionManager>> {
    if (SessionManager._instance) {
      Logger.info('🔄 SessionManager already initialized, returning existing instance');
      return CFResult.success(SessionManager._instance);
    }

    if (SessionManager._isInitializing && SessionManager._initPromise) {
      Logger.info('🔄 SessionManager initialization in progress, waiting...');
      try {
        const manager = await SessionManager._initPromise;
        return CFResult.success(manager);
      } catch (error) {
        return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
      }
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
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Get the current SessionManager instance
   */
  static getInstance(): SessionManager | null {
    return SessionManager._instance;
  }

  /**
   * Shutdown the SessionManager
   */
  static shutdown(): void {
    if (SessionManager._instance) {
      SessionManager._instance.listeners.clear();
      Logger.info('🔄 SessionManager shutdown');
    }
    SessionManager._instance = null;
    SessionManager._isInitializing = false;
    SessionManager._initPromise = null;
  }

  // MARK: - Properties

  private readonly config: SessionConfig;
  private currentSession: SessionData | null = null;
  private readonly listeners: Set<SessionRotationListener> = new Set();
  private lastBackgroundTime = 0;

  // MARK: - Initialization

  private constructor(config: SessionConfig) {
    this.config = config;
  }

  /**
   * Initialize session on startup
   */
  private async initializeSession(): Promise<void> {
    const currentAppStart = Date.now();
    const lastAppStart = await this.getLastAppStartTime();

    // Check if this is a new app start
    const isNewAppStart = lastAppStart === 0 || 
        (currentAppStart - lastAppStart) > this.config.minSessionDurationMs;

    if (isNewAppStart && this.config.rotateOnAppRestart) {
      // App restart - force new session
      await this.rotateSession(RotationReason.APP_START);
      await this.storeLastAppStartTime(currentAppStart);
    } else {
      // Try to restore existing session
      await this.restoreOrCreateSession();
    }
  }

  // MARK: - Public Methods

  /**
   * Get the current session ID
   */
  getCurrentSessionId(): string {
    if (this.currentSession) {
      return this.currentSession.sessionId;
    } else {
      // No current session, create one synchronously if possible
      const sessionId = this.generateSessionId();
      this.currentSession = createSessionData(sessionId, RotationReason.APP_START);
      this.storeCurrentSession().catch(error => {
        Logger.error('Failed to store emergency session: ' + error);
      });
      return sessionId;
    }
  }

  /**
   * Get current session data
   */
  getCurrentSession(): SessionData | null {
    return this.currentSession;
  }

  /**
   * Update session activity (call this on user interactions)
   */
  async updateActivity(): Promise<void> {
    const session = this.currentSession;
    if (!session) return;

    const now = Date.now();

    // Check if session needs rotation due to max duration
    if (this.config.enableTimeBasedRotation && 
        this.shouldRotateForMaxDuration(session, now)) {
      await this.rotateSession(RotationReason.MAX_DURATION_EXCEEDED);
    } else {
      // Update last active time
      this.currentSession = updateSessionActivity(session);
      await this.storeCurrentSession();
    }
  }

  /**
   * Handle app going to background
   */
  async onAppBackground(): Promise<void> {
    this.lastBackgroundTime = Date.now();
    await this.storeBackgroundTime(this.lastBackgroundTime);
    Logger.debug('🔄 App went to background at: ' + this.lastBackgroundTime);
  }

  /**
   * Handle app coming to foreground
   */
  async onAppForeground(): Promise<void> {
    const now = Date.now();
    const backgroundDuration = this.lastBackgroundTime > 0 ? now - this.lastBackgroundTime : 0;

    Logger.debug('🔄 App came to foreground after ' + backgroundDuration + ' ms in background');

    // Check if we need to rotate due to background timeout
    if (backgroundDuration > this.config.backgroundThresholdMs) {
      await this.rotateSession(RotationReason.BACKGROUND_TIMEOUT);
    } else {
      // Just update activity
      await this.updateActivityInternal();
    }

    this.lastBackgroundTime = 0;
  }

  /**
   * Handle user authentication changes
   */
  async onAuthenticationChange(userId?: string): Promise<void> {
    if (this.config.rotateOnAuthChange) {
      Logger.info('🔄 Authentication changed for user: ' + (userId || 'null'));
      await this.rotateSession(RotationReason.AUTH_CHANGE);
    }
  }

  /**
   * Handle network connectivity changes
   */
  async onNetworkChange(): Promise<void> {
    Logger.debug('🔄 Network connectivity changed');
    // Optional: rotate on network change for high-security scenarios
    // await this.rotateSession(RotationReason.NETWORK_CHANGE);
  }

  /**
   * Manually force session rotation
   */
  async forceRotation(): Promise<string> {
    await this.rotateSession(RotationReason.MANUAL_ROTATION);
    return this.currentSession!.sessionId;
  }

  /**
   * Add a session rotation listener
   */
  addListener(listener: SessionRotationListener): void {
    this.listeners.add(listener);
  }

  /**
   * Remove a session rotation listener
   */
  removeListener(listener: SessionRotationListener): void {
    this.listeners.delete(listener);
  }

  /**
   * Get session statistics
   */
  getSessionStats(): Record<string, any> {
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

  // MARK: - Private Helper Methods

  private async restoreOrCreateSession(): Promise<void> {
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

  private async rotateSession(reason: RotationReason): Promise<void> {
    const oldSessionId = this.currentSession?.sessionId || null;
    const newSessionId = this.generateSessionId();

    this.currentSession = createSessionData(newSessionId, reason);

    await this.storeCurrentSession();
    this.notifySessionRotated(oldSessionId, newSessionId, reason);

    Logger.info('🔄 Session rotated: ' + (oldSessionId || 'null') + ' -> ' + newSessionId + ' (' + reason + ')');
  }

  private generateSessionId(): string {
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(2, 10);
    return `${this.config.sessionIdPrefix}_${timestamp}_${randomStr}`;
  }

  private shouldRotateForMaxDuration(session: SessionData, currentTime: number): boolean {
    const sessionAge = currentTime - session.createdAt;
    return sessionAge >= this.config.maxSessionDurationMs;
  }

  private isSessionValid(session: SessionData, currentTime: number): boolean {
    const sessionAge = currentTime - session.createdAt;
    const inactiveTime = currentTime - session.lastActiveAt;

    // Session is valid if:
    // 1. Not older than max duration
    // 2. Has been active recently (within background threshold)
    return sessionAge < this.config.maxSessionDurationMs &&
           inactiveTime < this.config.backgroundThresholdMs;
  }

  private async updateActivityInternal(): Promise<void> {
    const session = this.currentSession;
    if (!session) return;

    const now = Date.now();

    // Check if session needs rotation due to max duration
    if (this.config.enableTimeBasedRotation && 
        this.shouldRotateForMaxDuration(session, now)) {
      await this.rotateSession(RotationReason.MAX_DURATION_EXCEEDED);
    } else {
      // Update last active time
      this.currentSession = updateSessionActivity(session);
      await this.storeCurrentSession();
    }
  }

  // MARK: - Storage Operations

  private async storeCurrentSession(): Promise<void> {
    const session = this.currentSession;
    if (!session) return;

    try {
      await AsyncStorage.setItem(SessionManager.SESSION_STORAGE_KEY, JSON.stringify(session));
    } catch (error) {
      Logger.error('Failed to store session: ' + error);
      this.notifySessionError(`Failed to store session: ${error}`);
    }
  }

  private async loadStoredSession(): Promise<SessionData | null> {
    try {
      const sessionJson = await AsyncStorage.getItem(SessionManager.SESSION_STORAGE_KEY);
      
      if (sessionJson) {
        return JSON.parse(sessionJson) as SessionData;
      }
      return null;
    } catch (error) {
      Logger.error('Failed to load stored session: ' + error);
      return null;
    }
  }

  private async storeLastAppStartTime(timestamp: number): Promise<void> {
    try {
      await AsyncStorage.setItem(SessionManager.LAST_APP_START_KEY, timestamp.toString());
    } catch (error) {
      Logger.error('Failed to store last app start time: ' + error);
    }
  }

  private async getLastAppStartTime(): Promise<number> {
    try {
      const timeStr = await AsyncStorage.getItem(SessionManager.LAST_APP_START_KEY);
      return timeStr ? parseInt(timeStr, 10) : 0;
    } catch (error) {
      Logger.error('Failed to get last app start time: ' + error);
      return 0;
    }
  }

  private async storeBackgroundTime(timestamp: number): Promise<void> {
    try {
      await AsyncStorage.setItem(SessionManager.BACKGROUND_TIMESTAMP_KEY, timestamp.toString());
    } catch (error) {
      Logger.error('Failed to store background time: ' + error);
    }
  }

  // MARK: - Notification Helpers

  private notifySessionRotated(oldSessionId: string | null, newSessionId: string, reason: RotationReason): void {
    for (const listener of this.listeners) {
      try {
        listener.onSessionRotated(oldSessionId, newSessionId, reason);
      } catch (error) {
        Logger.error('Error in session rotation listener: ' + error);
      }
    }
  }

  private notifySessionRestored(sessionId: string): void {
    for (const listener of this.listeners) {
      try {
        listener.onSessionRestored(sessionId);
      } catch (error) {
        Logger.error('Error in session restored listener: ' + error);
      }
    }
  }

  private notifySessionError(error: string): void {
    for (const listener of this.listeners) {
      try {
        listener.onSessionError(error);
      } catch (error) {
        Logger.error('Error in session error listener: ' + error);
      }
    }
  }
} 