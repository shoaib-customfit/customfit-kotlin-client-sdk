// lib/models/error_category.dart

/// Error categories for the CustomFit SDK.
enum ErrorCategory {
  /// Network-related errors.
  network,

  /// Serialization-related errors.
  serialization,

  /// Validation-related errors.
  validation,

  /// Permission-related errors.
  permission,

  /// Timeout-related errors.
  timeout,

  /// Internal errors.
  internal,

  /// Unknown errors.
  unknown,

  /// Configuration-related errors.
  configuration,

  /// User-related errors.
  user,

  /// Analytics-related errors.
  analytics,

  /// Feature flag-related errors.
  feature,

  /// General errors.
  general,
}

/// Extension methods for ErrorCategory.
extension ErrorCategoryExtension on ErrorCategory {
  /// Convert to string representation.
  String toValue() {
    switch (this) {
      case ErrorCategory.network:
        return 'network';
      case ErrorCategory.serialization:
        return 'serialization';
      case ErrorCategory.validation:
        return 'validation';
      case ErrorCategory.permission:
        return 'permission';
      case ErrorCategory.timeout:
        return 'timeout';
      case ErrorCategory.internal:
        return 'internal';
      case ErrorCategory.unknown:
        return 'unknown';
      case ErrorCategory.configuration:
        return 'configuration';
      case ErrorCategory.user:
        return 'user';
      case ErrorCategory.analytics:
        return 'analytics';
      case ErrorCategory.feature:
        return 'feature';
      case ErrorCategory.general:
        return 'general';
    }
  }

  /// Create from string representation.
  static ErrorCategory fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'network':
        return ErrorCategory.network;
      case 'serialization':
        return ErrorCategory.serialization;
      case 'validation':
        return ErrorCategory.validation;
      case 'permission':
        return ErrorCategory.permission;
      case 'timeout':
        return ErrorCategory.timeout;
      case 'internal':
        return ErrorCategory.internal;
      case 'configuration':
        return ErrorCategory.configuration;
      case 'user':
        return ErrorCategory.user;
      case 'analytics':
        return ErrorCategory.analytics;
      case 'feature':
        return ErrorCategory.feature;
      default:
        return ErrorCategory.unknown;
    }
  }
}
