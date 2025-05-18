import 'dart:async';
import '../../logging/logger.dart';
import '../../core/util/synchronization.dart';

/// Implements the Circuit Breaker pattern to prevent repeated calls to failing services
/// Similar to the Kotlin implementation but adapted for Dart's async model
class CircuitBreaker {
  final String _operationKey;
  final int _failureThreshold;
  final int _resetTimeoutMs;

  // Circuit state
  int _consecutiveFailures = 0;
  int _openUntil = 0;
  final _stateLock = Object();

  // Circuit states
  static const int _closed = 0; // Working normally
  static const int _open = 1; // Preventing calls
  static const int _halfOpen = 2; // Testing if system is back to normal

  int _state = _closed;

  // Operation map for tracking multiple circuit breakers
  static final Map<String, CircuitBreaker> _operationMap = {};

  /// Creates a new CircuitBreaker
  ///
  /// [operationKey] Unique identifier for this circuit breaker
  /// [failureThreshold] Number of consecutive failures before opening circuit
  /// [resetTimeoutMs] Time in milliseconds before allowing retries
  CircuitBreaker._(
      this._operationKey, this._failureThreshold, this._resetTimeoutMs);

  /// Gets or creates a CircuitBreaker instance for the given operation
  static CircuitBreaker getInstance(
      String operationKey, int failureThreshold, int resetTimeoutMs) {
    if (!_operationMap.containsKey(operationKey)) {
      _operationMap[operationKey] =
          CircuitBreaker._(operationKey, failureThreshold, resetTimeoutMs);
    }
    return _operationMap[operationKey]!;
  }

  /// Executes a function with circuit breaker protection
  Future<T> executeWithCircuitBreaker<T>(Future<T> Function() block,
      {T? fallback}) async {
    // Check if circuit is open
    if (_isOpen()) {
      final canRetry = _canRetry();
      if (!canRetry) {
        Logger.w('Circuit open for $_operationKey, skipping operation');
        if (fallback != null) {
          return fallback;
        }
        throw CircuitOpenException(
            'Circuit breaker open for operation: $_operationKey');
      }

      // Half-open state - allowing a test call
      Logger.i(
          'Testing circuit for $_operationKey - moving to half-open state');
      synchronized(_stateLock, () {
        _state = _halfOpen;
      });
    }

    try {
      final result = await block();
      _recordSuccess();
      return result;
    } catch (e) {
      _recordFailure();
      if (fallback != null) {
        Logger.w('Circuit breaker caught error, using fallback: $e');
        return fallback;
      }
      rethrow;
    }
  }

  /// Records a successful operation
  void _recordSuccess() {
    synchronized(_stateLock, () {
      _consecutiveFailures = 0;
      _openUntil = 0;
      _state = _closed;
      Logger.d('Circuit for $_operationKey reset after success');
    });
  }

  /// Records a failed operation
  void _recordFailure() {
    synchronized(_stateLock, () {
      _consecutiveFailures++;
      Logger.d(
          'Circuit for $_operationKey recorded failure: $_consecutiveFailures/$_failureThreshold');

      if (_consecutiveFailures >= _failureThreshold) {
        _openCircuit();
      }
    });
  }

  /// Opens the circuit
  void _openCircuit() {
    synchronized(_stateLock, () {
      _openUntil = DateTime.now().millisecondsSinceEpoch + _resetTimeoutMs;
      _state = _open;
      Logger.w(
          'Circuit for $_operationKey opened until ${DateTime.fromMillisecondsSinceEpoch(_openUntil)}');
    });
  }

  /// Checks if the circuit is open
  bool _isOpen() {
    return synchronized(_stateLock, () => _state == _open);
  }

  /// Checks if we should try again after circuit was open
  bool _canRetry() {
    return synchronized(_stateLock, () {
      final now = DateTime.now().millisecondsSinceEpoch;
      return now >= _openUntil;
    });
  }

  /// Resets the circuit breaker state
  void reset() {
    synchronized(_stateLock, () {
      _consecutiveFailures = 0;
      _openUntil = 0;
      _state = _closed;
      Logger.i('Circuit for $_operationKey manually reset');
    });
  }

  /// Remove all circuit breakers
  static void resetAll() {
    _operationMap.clear();
    Logger.i('All circuit breakers reset');
  }
}

/// Exception thrown when a circuit is open
class CircuitOpenException implements Exception {
  final String message;
  CircuitOpenException(this.message);

  @override
  String toString() => message;
}
