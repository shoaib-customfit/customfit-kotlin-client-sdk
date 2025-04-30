// lib/models/cf_result.dart

import 'error_category.dart';
import 'error_handler.dart';
import 'error_severity.dart';

/// Mirrors Kotlin’s sealed CFResult<T>.
class CFResult<T> {
  final T? _value;
  final String? _errorMessage;
  final dynamic _exception;
  final int _code;
  final ErrorCategory _category;
  final bool isSuccess;

  CFResult._({
    T? value,
    String? errorMessage,
    dynamic exception,
    int code = 0,
    ErrorCategory category = ErrorCategory.unknown,
    required this.isSuccess,
  })  : _value = value,
        _errorMessage = errorMessage,
        _exception = exception,
        _code = code,
        _category = category;

  /// Successful result
  factory CFResult.success(T value) =>
      CFResult._(value: value, isSuccess: true);

  /// Error result (logs automatically, like Kotlin’s companion.error)
  factory CFResult.error(
    String message, {
    dynamic exception,
    int code = 0,
    ErrorCategory category = ErrorCategory.unknown,
  }) {
    if (exception != null) {
      ErrorHandler.handleException(
        exception,
        message,
        source: 'CFResult',
        severity: ErrorSeverity.medium,
      );
    } else {
      ErrorHandler.handleError(
        message,
        source: 'CFResult',
        category: category,
        severity: ErrorSeverity.medium,
      );
    }
    return CFResult._(
      errorMessage: message,
      exception: exception,
      code: code,
      category: category,
      isSuccess: false,
    );
  }

  /// Wraps a block into a CFResult (like fromResult(Result<T>))
  static CFResult<T> fromResult<T>(
    T Function() block, {
    String errorMessage = 'Operation failed',
  }) {
    try {
      return CFResult.success(block());
    } catch (e) {
      return CFResult.error(errorMessage, exception: e);
    }
  }

  /// Returns the value or null if error
  T? getOrNull() => isSuccess ? _value : null;

  /// Returns the value or calls [onError]
  T getOrElse(T Function(CFResult<T>) onError) =>
      isSuccess ? _value as T : onError(this);

  /// Returns the value or [defaultValue]
  T getOrDefault(T defaultValue) => isSuccess ? _value as T : defaultValue;

  /// Transforms a success result, propagates error otherwise
  CFResult<R> map<R>(R Function(T) transform) {
    return isSuccess
        ? CFResult.success(transform(_value as T))
        : CFResult.error(
            _errorMessage ?? '',
            exception: _exception,
            code: _code,
            category: _category,
          );
  }

  /// Folds into a single R
  R fold<R>(
    R Function(T) onSuccess,
    R Function(CFResult<T>) onError,
  ) =>
      isSuccess ? onSuccess(_value as T) : onError(this);

  /// Side-effect on success
  CFResult<T> onSuccess(void Function(T) action) {
    if (isSuccess) action(_value as T);
    return this;
  }

  /// Side-effect on error
  CFResult<T> onError(void Function(CFResult<T>) action) {
    if (!isSuccess) action(this);
    return this;
  }
}
