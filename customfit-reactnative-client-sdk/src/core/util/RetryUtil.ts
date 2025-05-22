import { CFResult } from '../error/CFResult';
import { ErrorCategory } from '../types/CFTypes';
import { Logger } from '../../logging/Logger';

/**
 * Configuration for retry operations
 */
export interface RetryConfig {
  maxAttempts: number;
  initialDelayMs: number;
  maxDelayMs: number;
  backoffMultiplier: number;
  retryableErrors?: ErrorCategory[];
}

/**
 * Utility class for retry operations with exponential backoff
 */
export class RetryUtil {
  private static readonly DEFAULT_RETRYABLE_ERRORS = [
    ErrorCategory.NETWORK,
    ErrorCategory.TIMEOUT,
  ];

  /**
   * Execute an operation with retry logic
   */
  static async execute<T>(
    operation: () => Promise<CFResult<T>>,
    config: RetryConfig,
    operationName: string = 'operation'
  ): Promise<CFResult<T>> {
    const retryableErrors = config.retryableErrors || RetryUtil.DEFAULT_RETRYABLE_ERRORS;
    let lastResult: CFResult<T>;
    let delay = config.initialDelayMs;

    for (let attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        Logger.debug(`Executing ${operationName} (attempt ${attempt}/${config.maxAttempts})`);
        
        lastResult = await operation();
        
        if (lastResult.isSuccess) {
          if (attempt > 1) {
            Logger.info(`${operationName} succeeded after ${attempt} attempts`);
          }
          return lastResult;
        }

        // Check if error is retryable
        if (lastResult.error && retryableErrors.includes(lastResult.error.category)) {
          if (attempt < config.maxAttempts) {
            Logger.warning(
              `${operationName} failed (attempt ${attempt}): ${lastResult.error.message}. Retrying in ${delay}ms...`
            );
            await RetryUtil.delay(delay);
            delay = Math.min(delay * config.backoffMultiplier, config.maxDelayMs);
          } else {
            Logger.error(
              `${operationName} failed after ${config.maxAttempts} attempts: ${lastResult.error.message}`
            );
          }
        } else {
          Logger.error(
            `${operationName} failed with non-retryable error: ${lastResult.error?.message}`
          );
          return lastResult;
        }
      } catch (error) {
        Logger.error(`${operationName} threw exception: ${error}`);
        lastResult = CFResult.errorFromException<T>(error as Error, ErrorCategory.INTERNAL);
        
        if (attempt >= config.maxAttempts) {
          break;
        }
        
        await RetryUtil.delay(delay);
        delay = Math.min(delay * config.backoffMultiplier, config.maxDelayMs);
      }
    }

    return lastResult!;
  }

  /**
   * Execute an operation with simple retry (no exponential backoff)
   */
  static async executeSimple<T>(
    operation: () => Promise<CFResult<T>>,
    maxAttempts: number,
    delayMs: number,
    operationName: string = 'operation'
  ): Promise<CFResult<T>> {
    const config: RetryConfig = {
      maxAttempts,
      initialDelayMs: delayMs,
      maxDelayMs: delayMs,
      backoffMultiplier: 1.0,
    };
    
    return RetryUtil.execute(operation, config, operationName);
  }

  /**
   * Create a retry configuration from SDK config
   */
  static createConfig(
    maxAttempts: number,
    initialDelayMs: number,
    maxDelayMs: number,
    backoffMultiplier: number
  ): RetryConfig {
    return {
      maxAttempts,
      initialDelayMs,
      maxDelayMs,
      backoffMultiplier,
    };
  }

  /**
   * Check if an error category is retryable
   */
  static isRetryable(category: ErrorCategory): boolean {
    return RetryUtil.DEFAULT_RETRYABLE_ERRORS.includes(category);
  }

  /**
   * Create a delay promise
   */
  private static delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Calculate next delay with jitter to avoid thundering herd
   */
  static calculateDelayWithJitter(baseDelay: number, maxJitter: number = 0.1): number {
    const jitter = Math.random() * maxJitter * baseDelay;
    return Math.floor(baseDelay + jitter);
  }
} 