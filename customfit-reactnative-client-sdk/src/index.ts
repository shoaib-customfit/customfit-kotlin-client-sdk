/**
 * CustomFit React Native SDK
 * 
 * Main entry point for the SDK - exports all public APIs
 */

// Core types and interfaces
export * from './core/types/CFTypes';

// Core utilities
export { CFResult } from './core/error/CFResult';

// Configuration
export { CFConfigImpl as CFConfig } from './config/core/CFConfig';

// User model
export { CFUserImpl as CFUser } from './core/model/CFUser';

// Main client
export { CFClient } from './client/CFClient';

// Logger
export { Logger } from './logging/Logger';

// Constants
export { CFConstants } from './constants/CFConstants';

// React hooks
export * from './hooks/useCustomFit';

// Platform utilities
export { DeviceInfoUtil } from './platform/DeviceInfo';
export { ConnectionMonitor } from './platform/ConnectionMonitor';
export { AppStateManager } from './platform/AppStateManager';
export { EnvironmentAttributesCollector } from './platform/EnvironmentAttributesCollector';

// Storage utilities
export { Storage } from './utils/Storage';

// Core utilities
export { RetryUtil } from './core/util/RetryUtil';
export { CircuitBreaker } from './core/util/CircuitBreaker';

// Serialization utilities
export { JsonSerializer } from './serialization/JsonSerializer';

// Extension utilities
export { StringExtensions } from './extensions/StringExtensions';

// Performance utilities
export { PerformanceTimer, ScopedTimer, PerformanceMetricsCollector } from './utils/PerformanceTimer';

// Lifecycle management
export { CFLifecycleManager } from './lifecycle/CFLifecycleManager';

// Session management
export { 
  SessionManager, 
  SessionData, 
  SessionConfig, 
  SessionRotationListener, 
  RotationReason, 
  DEFAULT_SESSION_CONFIG,
  createSessionData,
  updateSessionActivity
} from './core/session/SessionManager';

// Additional exports for complete API coverage
export * from './core/types/CFTypes';

/**
 * Version information
 */
export const SDK_VERSION = '1.0.0';
export const SDK_NAME = 'CustomFit React Native SDK'; 