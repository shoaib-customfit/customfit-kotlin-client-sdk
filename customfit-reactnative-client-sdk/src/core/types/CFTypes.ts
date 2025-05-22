/**
 * Core types and interfaces for the CustomFit React Native SDK
 */

/**
 * Result type for operations that can succeed or fail
 */
export interface CFResult<T> {
  readonly isSuccess: boolean;
  readonly isError: boolean;
  readonly data?: T;
  readonly error?: CFError;
  
  // Functional methods
  map<U>(transform: (data: T) => U): CFResult<U>;
  flatMap<U>(transform: (data: T) => CFResult<U>): CFResult<U>;
  onSuccess(action: (data: T) => void): CFResult<T>;
  onError(action: (error: CFError) => void): CFResult<T>;
  getOrDefault(defaultValue: T): T;
  getOrThrow(): T;
}

/**
 * Error details for failed operations
 */
export interface CFError {
  readonly message: string;
  readonly code?: number;
  readonly category: ErrorCategory;
  readonly originalError?: Error;
}

/**
 * Error categories for classification
 */
export enum ErrorCategory {
  NETWORK = 'network',
  SERIALIZATION = 'serialization',
  VALIDATION = 'validation',
  PERMISSION = 'permission',
  TIMEOUT = 'timeout',
  INTERNAL = 'internal',
  UNKNOWN = 'unknown',
  STATE = 'state',
}

/**
 * Log levels for the SDK
 */
export enum LogLevel {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
  TRACE = 5,
}

/**
 * User information for personalization
 */
export interface CFUser {
  userCustomerId?: string;
  anonymousId?: string;
  deviceId?: string;
  anonymous?: boolean;
  properties?: Record<string, any>;
  
  // Immutable update methods
  withUserCustomerId(userCustomerId: string): CFUser;
  withAnonymousId(anonymousId: string): CFUser;
  withDeviceId(deviceId: string): CFUser;
  withAnonymous(anonymous: boolean): CFUser;
  withProperties(properties: Record<string, any>): CFUser;
  withProperty(key: string, value: any): CFUser;
  toUserMap(): Record<string, any>;
}

/**
 * Event data structure
 */
export interface EventData {
  id: string;
  name: string;
  properties?: Record<string, any>;
  timestamp: string;
  sessionId: string;
  userId?: string;
  anonymousId?: string;
  deviceId?: string;
}

/**
 * Summary data structure
 */
export interface SummaryData {
  name: string;
  count: number;
  properties?: Record<string, any>;
}

/**
 * SDK settings from server
 */
export interface SdkSettings {
  cf_account_enabled: boolean;
  cf_skip_sdk: boolean;
}

/**
 * Configuration for the SDK
 */
export interface CFConfig {
  readonly clientKey: string;
  readonly dimensionId?: string;
  
  // Event tracker configuration
  readonly eventsQueueSize: number;
  readonly eventsFlushTimeSeconds: number;
  readonly eventsFlushIntervalMs: number;
  readonly maxStoredEvents: number;
  
  // Retry configuration
  readonly maxRetryAttempts: number;
  readonly retryInitialDelayMs: number;
  readonly retryMaxDelayMs: number;
  readonly retryBackoffMultiplier: number;
  
  // Summary manager configuration
  readonly summariesQueueSize: number;
  readonly summariesFlushTimeSeconds: number;
  readonly summariesFlushIntervalMs: number;
  
  // SDK settings check configuration
  readonly sdkSettingsCheckIntervalMs: number;
  
  // Network configuration
  readonly networkConnectionTimeoutMs: number;
  readonly networkReadTimeoutMs: number;
  
  // Logging configuration
  readonly loggingEnabled: boolean;
  readonly debugLoggingEnabled: boolean;
  readonly logLevel: string;
  
  // Offline mode
  readonly offlineMode: boolean;
  
  // Background operation settings
  readonly disableBackgroundPolling: boolean;
  readonly backgroundPollingIntervalMs: number;
  readonly useReducedPollingWhenBatteryLow: boolean;
  readonly reducedPollingIntervalMs: number;
  
  // Auto environment attributes
  readonly autoEnvAttributesEnabled: boolean;
}

/**
 * App state for lifecycle management
 */
export enum AppState {
  ACTIVE = 'active',
  BACKGROUND = 'background',
  INACTIVE = 'inactive',
  UNKNOWN = 'unknown',
}

/**
 * Connection status
 */
export enum ConnectionStatus {
  CONNECTED = 'connected',
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  UNKNOWN = 'unknown',
}

/**
 * Battery state information
 */
export interface BatteryState {
  level: number; // 0.0 to 1.0
  isLow: boolean;
  isCharging: boolean;
}

/**
 * Circuit breaker state
 */
export enum CircuitBreakerState {
  CLOSED = 'closed',
  OPEN = 'open',
  HALF_OPEN = 'half_open',
}

/**
 * Listener interfaces
 */
export interface ConfigChangeListener {
  onConfigChanged(key: string, oldValue: any, newValue: any): void;
}

export interface FeatureFlagChangeListener {
  onFeatureFlagChanged(key: string, oldValue: any, newValue: any): void;
}

export interface AllFlagsChangeListener {
  onAllFlagsChanged(flags: Record<string, any>): void;
}

export interface ConnectionStatusListener {
  onConnectionStatusChanged(status: ConnectionStatus): void;
}

export interface AppStateListener {
  onAppStateChanged(newState: AppState, previousState: AppState): void;
}

export interface BatteryStateListener {
  onBatteryStateChanged(batteryState: BatteryState): void;
}

/**
 * HTTP request options
 */
export interface HttpRequestOptions {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'HEAD';
  headers?: Record<string, string>;
  body?: string;
  timeout?: number;
}

/**
 * HTTP response interface
 */
export interface HttpResponse {
  status: number;
  statusText: string;
  headers: Record<string, string>;
  data?: any;
}

/**
 * Cache entry with TTL
 */
export interface CacheEntry<T> {
  data: T;
  timestamp: number;
  ttl: number;
}

/**
 * Metrics for performance monitoring
 */
export interface PerformanceMetrics {
  totalEvents: number;
  totalSummaries: number;
  totalConfigFetches: number;
  averageResponseTime: number;
  failureRate: number;
}

/**
 * Configuration builder interface
 */
export interface CFConfigBuilder {
  eventsQueueSize(size: number): CFConfigBuilder;
  eventsFlushTimeSeconds(seconds: number): CFConfigBuilder;
  eventsFlushIntervalMs(ms: number): CFConfigBuilder;
  maxStoredEvents(max: number): CFConfigBuilder;
  maxRetryAttempts(attempts: number): CFConfigBuilder;
  retryInitialDelayMs(delayMs: number): CFConfigBuilder;
  retryMaxDelayMs(delayMs: number): CFConfigBuilder;
  retryBackoffMultiplier(multiplier: number): CFConfigBuilder;
  summariesQueueSize(size: number): CFConfigBuilder;
  summariesFlushTimeSeconds(seconds: number): CFConfigBuilder;
  summariesFlushIntervalMs(ms: number): CFConfigBuilder;
  sdkSettingsCheckIntervalMs(ms: number): CFConfigBuilder;
  networkConnectionTimeoutMs(ms: number): CFConfigBuilder;
  networkReadTimeoutMs(ms: number): CFConfigBuilder;
  loggingEnabled(enabled: boolean): CFConfigBuilder;
  debugLoggingEnabled(enabled: boolean): CFConfigBuilder;
  logLevel(level: string): CFConfigBuilder;
  offlineMode(offline: boolean): CFConfigBuilder;
  disableBackgroundPolling(disable: boolean): CFConfigBuilder;
  backgroundPollingIntervalMs(ms: number): CFConfigBuilder;
  useReducedPollingWhenBatteryLow(use: boolean): CFConfigBuilder;
  reducedPollingIntervalMs(ms: number): CFConfigBuilder;
  autoEnvAttributesEnabled(enabled: boolean): CFConfigBuilder;
  build(): CFConfig;
}

/**
 * User builder interface
 */
export interface CFUserBuilder {
  userCustomerId(id: string): CFUserBuilder;
  anonymousId(id: string): CFUserBuilder;
  deviceId(id: string): CFUserBuilder;
  anonymous(isAnonymous: boolean): CFUserBuilder;
  properties(props: Record<string, any>): CFUserBuilder;
  property(key: string, value: any): CFUserBuilder;
  build(): CFUser;
} 