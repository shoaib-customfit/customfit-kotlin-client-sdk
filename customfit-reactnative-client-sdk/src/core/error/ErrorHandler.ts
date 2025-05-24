/**
 * Centralized error handling utility providing standardized error handling,
 * categorization, and reporting capabilities.
 */

import { Logger } from '../../logging/Logger';

/**
 * Error categories for classification
 */
export enum ErrorCategory {
  NETWORK = 'NETWORK',
  SERIALIZATION = 'SERIALIZATION',
  VALIDATION = 'VALIDATION',
  PERMISSION = 'PERMISSION',
  TIMEOUT = 'TIMEOUT',
  INTERNAL = 'INTERNAL',
  UNKNOWN = 'UNKNOWN',
}

/**
 * Error severity levels
 */
export enum ErrorSeverity {
  LOW = 'LOW',      // Minor issues that don't impact functionality
  MEDIUM = 'MEDIUM', // Important issues that may impact some functionality
  HIGH = 'HIGH',     // Critical issues that significantly impact functionality
  CRITICAL = 'CRITICAL', // Fatal issues that completely break functionality
}

/**
 * Centralized error handling utility
 */
export class ErrorHandler {
  // Track error occurrences for rate limiting and pattern detection
  private static errorCounts = new Map<string, number>();
  private static readonly MAX_LOG_RATE = 10; // Max times to log same error in a session

  /**
   * Handles and logs an exception with standard categorization
   * 
   * @param error The error to handle
   * @param message The error message
   * @param source The component where the error occurred
   * @param severity The error severity
   * @returns The appropriate ErrorCategory for the exception
   */
  static handleException(
    error: Error,
    message: string,
    source: string = 'unknown',
    severity: ErrorSeverity = ErrorSeverity.MEDIUM
  ): ErrorCategory {
    // Categorize the error
    const category = this.categorizeException(error);
    
    // Build enhanced error message
    const enhancedMessage = this.buildErrorMessage(message, source, severity, category);
    
    // Rate-limit repeated errors
    const errorKey = `${error.constructor.name}:${source}:${message}`;
    const count = this.incrementErrorCount(errorKey);
    
    if (count <= this.MAX_LOG_RATE) {
      // Log with appropriate level based on severity
      switch (severity) {
        case ErrorSeverity.LOW:
          Logger.debug(`${enhancedMessage}: ${error.message}`);
          break;
        case ErrorSeverity.MEDIUM:
          Logger.warning(`${enhancedMessage}: ${error.message}`);
          break;
        case ErrorSeverity.HIGH:
        case ErrorSeverity.CRITICAL:
          Logger.error(`${enhancedMessage}: ${error.message}`);
          break;
      }
    } else if (count === this.MAX_LOG_RATE + 1) {
      // Log that we're rate limiting this error
      Logger.warning(`Rate limiting similar error: ${errorKey}. Further occurrences won't be logged.`);
    }
    
    return category;
  }

  /**
   * Handles an error condition without an exception
   * 
   * @param message The error message
   * @param source The component where the error occurred
   * @param category The error category
   * @param severity The error severity
   */
  static handleError(
    message: string,
    source: string = 'unknown',
    category: ErrorCategory = ErrorCategory.UNKNOWN,
    severity: ErrorSeverity = ErrorSeverity.MEDIUM
  ): void {
    // Build enhanced error message
    const enhancedMessage = this.buildErrorMessage(message, source, severity, category);
    
    // Rate-limit repeated errors
    const errorKey = `${source}:${message}:${category}`;
    const count = this.incrementErrorCount(errorKey);
    
    if (count <= this.MAX_LOG_RATE) {
      // Log with appropriate level based on severity
      switch (severity) {
        case ErrorSeverity.LOW:
          Logger.debug(enhancedMessage);
          break;
        case ErrorSeverity.MEDIUM:
          Logger.warning(enhancedMessage);
          break;
        case ErrorSeverity.HIGH:
        case ErrorSeverity.CRITICAL:
          Logger.error(enhancedMessage);
          break;
      }
    } else if (count === this.MAX_LOG_RATE + 1) {
      // Log that we're rate limiting this error
      Logger.warning(`Rate limiting similar error: ${errorKey}. Further occurrences won't be logged.`);
    }
  }

  /**
   * Clears the error count tracking
   */
  static resetErrorCounts(): void {
    this.errorCounts.clear();
  }

  /**
   * Determines the category of an exception
   */
  private static categorizeException(error: Error): ErrorCategory {
    const errorName = error.constructor.name.toLowerCase();
    const errorMessage = error.message.toLowerCase();

    // Check error types
    if (errorName.includes('timeout') || errorMessage.includes('timeout')) {
      return ErrorCategory.TIMEOUT;
    } else if (errorName.includes('network') || errorMessage.includes('network') ||
               errorMessage.includes('fetch') || errorMessage.includes('connection')) {
      return ErrorCategory.NETWORK;
    } else if (errorName.includes('syntax') || errorName.includes('parse') ||
               errorMessage.includes('json') || errorMessage.includes('parse')) {
      return ErrorCategory.SERIALIZATION;
    } else if (errorName.includes('permission') || errorMessage.includes('permission') ||
               errorMessage.includes('denied') || errorMessage.includes('unauthorized')) {
      return ErrorCategory.PERMISSION;
    } else if (errorMessage.includes('invalid') || errorMessage.includes('illegal') ||
               errorName.includes('validation')) {
      return ErrorCategory.VALIDATION;
    }

    return ErrorCategory.UNKNOWN;
  }

  /**
   * Thread-safe increment of error count
   */
  private static incrementErrorCount(key: string): number {
    const currentCount = this.errorCounts.get(key) || 0;
    const newCount = currentCount + 1;
    this.errorCounts.set(key, newCount);
    return newCount;
  }

  /**
   * Builds a standardized error message
   */
  private static buildErrorMessage(
    message: string,
    source: string,
    severity: ErrorSeverity,
    category: ErrorCategory
  ): string {
    return `[${source}] [${severity}] [${category}] ${message}`;
  }
} 