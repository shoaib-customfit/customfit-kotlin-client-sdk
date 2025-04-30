// lib/models/error_severity.dart

/// An enum representing the severity of an error.
enum ErrorSeverity {
  /// High severity errors that require immediate attention.
  high,

  /// Medium severity errors.
  medium,

  /// Low severity errors.
  low,

  critical
}

/// Extension methods for ErrorSeverity.
extension ErrorSeverityExtension on ErrorSeverity {
  /// Convert to string representation.
  String toValue() {
    switch (this) {
      case ErrorSeverity.high:
        return 'high';
      case ErrorSeverity.medium:
        return 'medium';
      case ErrorSeverity.low:
        return 'low';
      case ErrorSeverity.critical:
        return 'critical';
    }
  }

  /// Create from string representation.
  static ErrorSeverity fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return ErrorSeverity.high;
      case 'medium':
        return ErrorSeverity.medium;
      case 'low':
        return ErrorSeverity.low;
      default:
        return ErrorSeverity.medium;
    }
  }
}
