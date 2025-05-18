// lib/models/error_category.dart

/// Describes the category of an error for better debugging and handling
/// This is modeled after the Kotlin ErrorCategory enum
class ErrorCategory {
  /// Network errors (connectivity, server issues, etc)
  static const network = ErrorCategory._('NETWORK');

  /// Internal SDK errors
  static const internal = ErrorCategory._('INTERNAL');

  /// Serialization/deserialization errors
  static const serialization = ErrorCategory._('SERIALIZATION');

  /// Validation errors (invalid parameters, etc)
  static const validation = ErrorCategory._('VALIDATION');

  /// Storage-related errors
  static const storage = ErrorCategory._('STORAGE');

  /// Permission-related errors
  static const permission = ErrorCategory._('PERMISSION');

  /// Authentication-related errors
  static const authentication = ErrorCategory._('AUTHENTICATION');

  /// Configuration-related errors
  static const configuration = ErrorCategory._('CONFIGURATION');

  /// Timeout-related errors
  static const timeout = ErrorCategory._('TIMEOUT');

  /// Rate limit errors
  static const rateLimit = ErrorCategory._('RATE_LIMIT');

  /// Circuit breaker errors
  static const circuitBreaker = ErrorCategory._('CIRCUIT_BREAKER');

  /// Thread/concurrency-related errors
  static const concurrency = ErrorCategory._('CONCURRENCY');

  /// User-related errors
  static const user = ErrorCategory._('USER');

  /// Analytics-related errors
  static const analytics = ErrorCategory._('ANALYTICS');

  /// Feature flag-related errors
  static const feature = ErrorCategory._('FEATURE');

  /// Unknown error category
  static const unknown = ErrorCategory._('UNKNOWN');

  /// String identifier for this category
  final String name;

  /// Creates a new error category (internal constructor)
  const ErrorCategory._(this.name);

  @override
  String toString() => name;

  /// Get category from a string name
  static ErrorCategory fromString(String name) {
    switch (name.toUpperCase()) {
      case 'NETWORK':
        return network;
      case 'INTERNAL':
        return internal;
      case 'SERIALIZATION':
        return serialization;
      case 'VALIDATION':
        return validation;
      case 'STORAGE':
        return storage;
      case 'PERMISSION':
        return permission;
      case 'AUTHENTICATION':
        return authentication;
      case 'CONFIGURATION':
        return configuration;
      case 'TIMEOUT':
        return timeout;
      case 'RATE_LIMIT':
        return rateLimit;
      case 'CIRCUIT_BREAKER':
        return circuitBreaker;
      case 'CONCURRENCY':
        return concurrency;
      case 'USER':
        return user;
      case 'ANALYTICS':
        return analytics;
      case 'FEATURE':
        return feature;
      default:
        return unknown;
    }
  }
}
