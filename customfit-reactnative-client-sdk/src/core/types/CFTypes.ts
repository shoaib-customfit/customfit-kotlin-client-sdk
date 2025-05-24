/**
 * Core types and interfaces for the CustomFit React Native SDK
 */

// Forward declarations to avoid circular dependencies
export interface EvaluationContext {
  type: string;
  key: string;
  name?: string;
  properties: Record<string, any>;
  privateAttributes?: string[];
}

export interface DeviceContext {
  manufacturer?: string;
  model?: string;
  osName?: string;
  osVersion?: string;
  sdkVersion?: string;
  appId?: string;
  appVersion?: string;
  locale?: string;
  timezone?: string;
  screenWidth?: number;
  screenHeight?: number;
  screenDensity?: number;
  networkType?: string;
  networkCarrier?: string;
  customAttributes?: Record<string, any>;
}

export interface ApplicationInfo {
  appName?: string;
  packageName?: string;
  versionName?: string;
  versionCode?: number;
  buildNumber?: string;
  launchCount?: number;
  installDate?: Date;
  updateDate?: Date;
  customAttributes?: Record<string, any>;
}

export enum ContextType {
  USER = 'user',
  DEVICE = 'device',
  APP = 'app',
  SESSION = 'session',
  ORGANIZATION = 'organization',
  CUSTOM = 'custom',
}

/**
 * Helper functions for EvaluationContext
 */
export function evaluationContextFromMap(map: Record<string, any>): EvaluationContext {
  return {
    type: (map.type as string) || ContextType.CUSTOM,
    key: map.key as string,
    name: map.name as string | undefined,
    properties: (map.properties as Record<string, any>) || {},
    privateAttributes: (map.private_attributes as string[]) || [],
  };
}

export function evaluationContextToMap(context: EvaluationContext): Record<string, any> {
  const result: Record<string, any> = {
    type: context.type,
    key: context.key,
    properties: context.properties,
  };

  if (context.name) {
    result.name = context.name;
  }

  if (context.privateAttributes && context.privateAttributes.length > 0) {
    result.private_attributes = context.privateAttributes;
  }

  return result;
}

/**
 * Helper functions for DeviceContext
 */
export function createBasicDeviceContext(): DeviceContext {
  return {
    sdkVersion: '1.0.0',
    customAttributes: {},
  };
}

export function deviceContextFromMap(map: Record<string, any>): DeviceContext {
  return {
    manufacturer: map.manufacturer as string | undefined,
    model: map.model as string | undefined,
    osName: map.os_name as string | undefined,
    osVersion: map.os_version as string | undefined,
    sdkVersion: (map.sdk_version as string) || '1.0.0',
    appId: map.app_id as string | undefined,
    appVersion: map.app_version as string | undefined,
    locale: map.locale as string | undefined,
    timezone: map.timezone as string | undefined,
    screenWidth: map.screen_width as number | undefined,
    screenHeight: map.screen_height as number | undefined,
    screenDensity: map.screen_density as number | undefined,
    networkType: map.network_type as string | undefined,
    networkCarrier: map.network_carrier as string | undefined,
    customAttributes: (map.custom_attributes as Record<string, any>) || {},
  };
}

export function deviceContextToMap(context: DeviceContext): Record<string, any> {
  const result: Record<string, any> = {};

  if (context.manufacturer) result.manufacturer = context.manufacturer;
  if (context.model) result.model = context.model;
  if (context.osName) result.os_name = context.osName;
  if (context.osVersion) result.os_version = context.osVersion;
  if (context.sdkVersion) result.sdk_version = context.sdkVersion;
  if (context.appId) result.app_id = context.appId;
  if (context.appVersion) result.app_version = context.appVersion;
  if (context.locale) result.locale = context.locale;
  if (context.timezone) result.timezone = context.timezone;
  if (context.screenWidth) result.screen_width = context.screenWidth;
  if (context.screenHeight) result.screen_height = context.screenHeight;
  if (context.screenDensity) result.screen_density = context.screenDensity;
  if (context.networkType) result.network_type = context.networkType;
  if (context.networkCarrier) result.network_carrier = context.networkCarrier;
  if (context.customAttributes) result.custom_attributes = context.customAttributes;

  return result;
}

/**
 * Helper functions for ApplicationInfo
 */
export function applicationInfoFromMap(map: Record<string, any>): ApplicationInfo {
  return {
    appName: map.app_name as string | undefined,
    packageName: map.package_name as string | undefined,
    versionName: map.version_name as string | undefined,
    versionCode: map.version_code as number | undefined,
    buildNumber: map.build_number as string | undefined,
    launchCount: map.launch_count as number | undefined,
    installDate: map.install_date ? new Date(map.install_date) : undefined,
    updateDate: map.update_date ? new Date(map.update_date) : undefined,
    customAttributes: (map.custom_attributes as Record<string, any>) || {},
  };
}

export function applicationInfoToMap(info: ApplicationInfo): Record<string, any> {
  const result: Record<string, any> = {};

  if (info.appName) result.app_name = info.appName;
  if (info.packageName) result.package_name = info.packageName;
  if (info.versionName) result.version_name = info.versionName;
  if (info.versionCode) result.version_code = info.versionCode;
  if (info.buildNumber) result.build_number = info.buildNumber;
  if (info.launchCount) result.launch_count = info.launchCount;
  if (info.installDate) result.install_date = info.installDate.toISOString();
  if (info.updateDate) result.update_date = info.updateDate.toISOString();
  if (info.customAttributes) result.custom_attributes = info.customAttributes;

  return result;
}

/**
 * Convert string to ContextType enum
 */
export function contextTypeFromString(value: string): ContextType | null {
  switch (value.toLowerCase()) {
    case 'user':
      return ContextType.USER;
    case 'device':
      return ContextType.DEVICE;
    case 'app':
      return ContextType.APP;
    case 'session':
      return ContextType.SESSION;
    case 'organization':
      return ContextType.ORGANIZATION;
    case 'custom':
      return ContextType.CUSTOM;
    default:
      return null;
  }
}

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
  contexts?: EvaluationContext[];
  device?: DeviceContext;
  application?: ApplicationInfo;
  
  // Immutable update methods
  withUserCustomerId(userCustomerId: string): CFUser;
  withAnonymousId(anonymousId: string): CFUser;
  withDeviceId(deviceId: string): CFUser;
  withAnonymous(anonymous: boolean): CFUser;
  withProperties(properties: Record<string, any>): CFUser;
  withProperty(key: string, value: any): CFUser;
  withContext(context: EvaluationContext): CFUser;
  withDeviceContext(device: DeviceContext): CFUser;
  withApplicationInfo(application: ApplicationInfo): CFUser;
  removeContext(type: ContextType, key: string): CFUser;
  toUserMap(): Record<string, any>;
}

/**
 * Event data structure
 */
export interface EventData {
  id: string;
  name: string;
  eventType: EventType;
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
 * Event type for tracking
 */
export enum EventType {
  TRACK = 'TRACK',
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
  context(context: EvaluationContext): CFUserBuilder;
  deviceContext(device: DeviceContext): CFUserBuilder;
  applicationInfo(application: ApplicationInfo): CFUserBuilder;
  build(): CFUser;
} 