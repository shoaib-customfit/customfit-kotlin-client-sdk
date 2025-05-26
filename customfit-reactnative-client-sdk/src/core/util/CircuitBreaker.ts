import { CircuitBreakerState } from '../types/CFTypes';
import { Logger } from '../../logging/Logger';

/**
 * Circuit breaker configuration
 */
export interface CircuitBreakerConfig {
  failureThreshold: number;
  resetTimeoutMs: number;
  name?: string;
}

/**
 * Circuit breaker implementation for handling cascading failures
 */
export class CircuitBreaker {
  private state: CircuitBreakerState = CircuitBreakerState.CLOSED;
  private failureCount: number = 0;
  private lastFailureTime: number = 0;
  private readonly config: CircuitBreakerConfig;

  constructor(config: CircuitBreakerConfig) {
    this.config = {
      name: 'CircuitBreaker',
      ...config,
    };
    
    Logger.debug(`${this.config.name} initialized with threshold=${config.failureThreshold}, timeout=${config.resetTimeoutMs}ms`);
  }

  /**
   * Execute an operation through the circuit breaker
   */
  async execute<T>(operation: () => Promise<T>, operationName?: string): Promise<T> {
    const opName = operationName || 'operation';
    
    if (this.state === CircuitBreakerState.OPEN) {
      if (this.shouldAttemptReset()) {
        this.state = CircuitBreakerState.HALF_OPEN;
        Logger.info(`${this.config.name} moving to HALF_OPEN state for ${opName}`);
      } else {
        const error = new Error(`${this.config.name} is OPEN - rejecting ${opName}`);
        Logger.warning(error.message);
        throw error;
      }
    }

    try {
      const result = await operation();
      this.onSuccess(opName);
      return result;
    } catch (error) {
      this.onFailure(error as Error, opName);
      throw error;
    }
  }

  /**
   * Check if the circuit breaker allows calls
   */
  canExecute(): boolean {
    if (this.state === CircuitBreakerState.CLOSED) {
      return true;
    }
    
    if (this.state === CircuitBreakerState.HALF_OPEN) {
      return true;
    }
    
    // OPEN state - check if we should attempt reset
    return this.shouldAttemptReset();
  }

  /**
   * Get current state
   */
  getState(): CircuitBreakerState {
    return this.state;
  }

  /**
   * Get current failure count
   */
  getFailureCount(): number {
    return this.failureCount;
  }

  /**
   * Reset the circuit breaker manually
   */
  reset(): void {
    Logger.info(`${this.config.name} manually reset`);
    this.state = CircuitBreakerState.CLOSED;
    this.failureCount = 0;
    this.lastFailureTime = 0;
  }

  /**
   * Force the circuit breaker to open
   */
  forceOpen(): void {
    Logger.warning(`${this.config.name} forced to OPEN state`);
    this.state = CircuitBreakerState.OPEN;
    this.lastFailureTime = Date.now();
  }

  /**
   * Get circuit breaker metrics
   */
  getMetrics(): {
    state: CircuitBreakerState;
    failureCount: number;
    lastFailureTime: number;
    isHealthy: boolean;
  } {
    return {
      state: this.state,
      failureCount: this.failureCount,
      lastFailureTime: this.lastFailureTime,
      isHealthy: this.state === CircuitBreakerState.CLOSED,
    };
  }

  private onSuccess(operationName: string): void {
    if (this.state === CircuitBreakerState.HALF_OPEN) {
      Logger.info(`${this.config.name} operation ${operationName} succeeded in HALF_OPEN state - resetting to CLOSED`);
      this.reset();
    } else if (this.failureCount > 0) {
      Logger.debug(`${this.config.name} operation ${operationName} succeeded - resetting failure count`);
      this.failureCount = 0;
    }
  }

  private onFailure(error: Error, operationName: string): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    
    // In web environments, ignore CORS-related failures for circuit breaker logic
    // These are environmental issues, not service failures
    const isCorsError = this.isCorsRelatedError(error);
    const isWebEnvironment = typeof window !== 'undefined';
    
    if (isWebEnvironment && isCorsError) {
      Logger.warning(`${this.config.name} operation ${operationName} failed due to CORS (${this.failureCount}/${this.config.failureThreshold}): ${error.message} - not counting toward circuit breaker`);
      // Reset failure count for CORS errors in web environment
      this.failureCount = Math.max(0, this.failureCount - 1);
      return;
    }
    
    Logger.warning(`${this.config.name} operation ${operationName} failed (${this.failureCount}/${this.config.failureThreshold}): ${error.message}`);

    if (this.state === CircuitBreakerState.HALF_OPEN) {
      Logger.warning(`${this.config.name} operation failed in HALF_OPEN state - moving to OPEN`);
      this.state = CircuitBreakerState.OPEN;
    } else if (this.failureCount >= this.config.failureThreshold) {
      Logger.error(`${this.config.name} failure threshold exceeded - moving to OPEN state`);
      this.state = CircuitBreakerState.OPEN;
    }
  }

  private isCorsRelatedError(error: Error): boolean {
    const message = error.message.toLowerCase();
    return message.includes('cors') ||
           message.includes('cross-origin') ||
           message.includes('network error') ||
           message.includes('fetch') ||
           message.includes('access-control-allow-origin') ||
           message.includes('blocked by cors policy') ||
           (message.includes('failed to fetch') && typeof window !== 'undefined');
  }

  private shouldAttemptReset(): boolean {
    const now = Date.now();
    const baseTimeout = this.config.resetTimeoutMs;
    
    // In web environments, use shorter timeout for faster recovery from CORS issues
    const isWebEnvironment = typeof window !== 'undefined';
    const timeoutMs = isWebEnvironment ? Math.min(baseTimeout, 5000) : baseTimeout; // 5 second timeout in web
    
    return now - this.lastFailureTime >= timeoutMs;
  }
} 