import { CFResult, CFError, ErrorCategory } from '../types/CFTypes';

/**
 * Result implementation for operations that can succeed or fail
 */
export class CFResultImpl<T> implements CFResult<T> {
  readonly isSuccess: boolean;
  readonly isError: boolean;
  readonly data?: T;
  readonly error?: CFError;

  private constructor(success: boolean, data?: T, error?: CFError) {
    this.isSuccess = success;
    this.isError = !success;
    this.data = data;
    this.error = error;
  }

  /**
   * Create a successful result
   */
  static success<T>(data: T): CFResult<T> {
    return new CFResultImpl(true, data);
  }

  /**
   * Create a successful result with no data
   */
  static successVoid(): CFResult<void> {
    return new CFResultImpl<void>(true);
  }

  /**
   * Create an error result
   */
  static error<T>(error: CFError): CFResult<T> {
    return new CFResultImpl<T>(false, undefined, error);
  }

  /**
   * Create an error result from message and category
   */
  static errorWithMessage<T>(message: string, category: ErrorCategory = ErrorCategory.UNKNOWN, originalError?: Error): CFResult<T> {
    const error: CFError = {
      message,
      category,
      originalError,
    };
    return new CFResultImpl<T>(false, undefined, error);
  }

  /**
   * Create an error result from an exception
   */
  static errorFromException<T>(exception: Error, category: ErrorCategory = ErrorCategory.UNKNOWN): CFResult<T> {
    const error: CFError = {
      message: exception.message,
      category,
      originalError: exception,
    };
    return new CFResultImpl<T>(false, undefined, error);
  }

  /**
   * Transform the data if this is a success result
   */
  map<U>(transform: (data: T) => U): CFResult<U> {
    if (this.isSuccess && this.data !== undefined) {
      try {
        const transformed = transform(this.data);
        return CFResultImpl.success(transformed);
      } catch (error) {
        return CFResultImpl.errorFromException(error as Error, ErrorCategory.INTERNAL);
      }
    }
    return CFResultImpl.error(this.error!);
  }

  /**
   * Chain another operation if this is a success result
   */
  flatMap<U>(transform: (data: T) => CFResult<U>): CFResult<U> {
    if (this.isSuccess && this.data !== undefined) {
      try {
        return transform(this.data);
      } catch (error) {
        return CFResultImpl.errorFromException(error as Error, ErrorCategory.INTERNAL);
      }
    }
    return CFResultImpl.error(this.error!);
  }

  /**
   * Execute a side effect if this is a success result
   */
  onSuccess(action: (data: T) => void): CFResult<T> {
    if (this.isSuccess && this.data !== undefined) {
      try {
        action(this.data);
      } catch (error) {
        // Ignore errors in side effects
      }
    }
    return this;
  }

  /**
   * Execute a side effect if this is an error result
   */
  onError(action: (error: CFError) => void): CFResult<T> {
    if (this.isError && this.error) {
      try {
        action(this.error);
      } catch (error) {
        // Ignore errors in side effects
      }
    }
    return this;
  }

  /**
   * Get the data or a default value
   */
  getOrDefault(defaultValue: T): T {
    return this.isSuccess && this.data !== undefined ? this.data : defaultValue;
  }

  /**
   * Get the data or throw the error
   */
  getOrThrow(): T {
    if (this.isSuccess && this.data !== undefined) {
      return this.data;
    }
    throw new Error(this.error?.message || 'Operation failed');
  }
}

export { CFResultImpl as CFResult }; 