import 'dart:async';
import 'dart:math' as math;
import 'package:battery_plus/battery_plus.dart';

import '../../logging/logger.dart';
import '../../core/util/synchronization.dart';

/// Strategy for polling with exponential backoff, battery awareness, and adaptive intervals
class PollingStrategy {
  static const String _source = 'PollingStrategy';

  /// Base interval for normal battery conditions
  final int _baseIntervalMs;

  /// Maximum interval for normal battery conditions
  final int _maxIntervalMs;

  /// Minimum interval regardless of conditions
  final int _minIntervalMs;

  /// Current polling interval
  int _currentIntervalMs;

  /// Factor by which to increase interval on errors
  final double _backoffMultiplier;

  /// Battery threshold to consider as low
  final int _lowBatteryThreshold;

  /// How much to increase intervals when battery is low (multiplier)
  final double _lowBatteryMultiplier;

  /// Counter for consecutive errors
  int _consecutiveErrors = 0;

  /// Maximum consecutive errors before reaching max interval
  final int _maxConsecutiveErrors;

  /// Is polling currently paused
  bool _isPaused = false;

  /// Timer for scheduling the next poll
  Timer? _timer;

  /// Callback to execute when it's time to poll
  final Future<bool> Function() _pollCallback;

  /// Lock for synchronization
  final _lock = Object();

  /// Battery instance
  final Battery _battery = Battery();

  /// Create a new polling strategy
  PollingStrategy({
    required int baseIntervalMs,
    required int maxIntervalMs,
    required int minIntervalMs,
    required Future<bool> Function() pollCallback,
    double backoffMultiplier = 1.5,
    int lowBatteryThreshold = 15,
    double lowBatteryMultiplier = 2.0,
    int maxConsecutiveErrors = 5,
  })  : _baseIntervalMs = baseIntervalMs,
        _maxIntervalMs = maxIntervalMs,
        _minIntervalMs = minIntervalMs,
        _currentIntervalMs = baseIntervalMs,
        _backoffMultiplier = backoffMultiplier,
        _lowBatteryThreshold = lowBatteryThreshold,
        _lowBatteryMultiplier = lowBatteryMultiplier,
        _maxConsecutiveErrors = maxConsecutiveErrors,
        _pollCallback = pollCallback {
    // Start polling
    _scheduleNextPoll();

    // Monitor battery status
    _monitorBatteryStatus();
  }

  /// Start or resume polling
  void start() {
    synchronized(_lock, () {
      _isPaused = false;

      // Only schedule if no active timer
      if (_timer == null || !_timer!.isActive) {
        _scheduleNextPoll();
      }

      Logger.i('Polling started with interval: $_currentIntervalMs ms');
    });
  }

  /// Pause polling
  void pause() {
    synchronized(_lock, () {
      _isPaused = true;

      // Cancel any active timer
      _timer?.cancel();
      _timer = null;

      Logger.i('Polling paused');
    });
  }

  /// Update the base polling interval (resets current interval)
  void updateBaseInterval(int baseIntervalMs) {
    synchronized(_lock, () {
      if (baseIntervalMs < _minIntervalMs) {
        Logger.w(
            'Requested base interval ($baseIntervalMs ms) is below minimum ($_minIntervalMs ms), using minimum');
        baseIntervalMs = _minIntervalMs;
      }

      Logger.i(
          'Updating base polling interval from $_baseIntervalMs ms to $baseIntervalMs ms');

      // Reset the current interval to the new base
      _currentIntervalMs = baseIntervalMs;

      // Reschedule with new interval
      if (!_isPaused) {
        _timer?.cancel();
        _scheduleNextPoll();
      }
    });
  }

  /// Force an immediate poll
  Future<bool> forcePoll() async {
    // Cancel any scheduled poll
    _timer?.cancel();

    Logger.i('Forcing immediate poll');

    // Execute poll
    final success = await _executePoll();

    // Schedule next poll if not paused
    if (!_isPaused) {
      _scheduleNextPoll();
    }

    return success;
  }

  /// Schedule the next poll based on current interval
  void _scheduleNextPoll() {
    synchronized(_lock, () {
      if (_isPaused) {
        return;
      }

      // Cancel any existing timer
      _timer?.cancel();

      // Schedule the next poll
      _timer = Timer(Duration(milliseconds: _currentIntervalMs), () async {
        await _executePoll();

        // Schedule the next poll if not paused
        if (!_isPaused) {
          _scheduleNextPoll();
        }
      });

      Logger.d('Next poll scheduled in $_currentIntervalMs ms');
    });
  }

  /// Execute the poll operation and adjust the interval based on result
  Future<bool> _executePoll() async {
    try {
      Logger.d('Executing poll operation');
      final success = await _pollCallback();

      synchronized(_lock, () {
        if (success) {
          // Reset consecutive error count
          _consecutiveErrors = 0;

          // Gradually decrease interval back to base on success
          if (_currentIntervalMs > _baseIntervalMs) {
            // Decrease by 10%, but don't go below base
            _currentIntervalMs = math.max(
              _baseIntervalMs,
              (_currentIntervalMs * 0.9).toInt(),
            );
            Logger.d(
                'Poll succeeded, decreasing interval to $_currentIntervalMs ms');
          }
        } else {
          // If not a success but not an exception, count as an error
          _consecutiveErrors++;
          _adjustIntervalForError();
        }
      });

      return success;
    } catch (e) {
      synchronized(_lock, () {
        _consecutiveErrors++;
        _adjustIntervalForError();
      });

      Logger.e('Error during poll operation: $e');
      return false;
    }
  }

  /// Adjust the polling interval after an error
  void _adjustIntervalForError() {
    synchronized(_lock, () {
      // Only backoff up to max consecutive errors
      if (_consecutiveErrors <= _maxConsecutiveErrors) {
        // Calculate new interval with exponential backoff
        final factor = math.min(
          math.pow(_backoffMultiplier, _consecutiveErrors),
          math.pow(_backoffMultiplier, _maxConsecutiveErrors),
        );

        _currentIntervalMs = math.min(
          (_baseIntervalMs * factor).toInt(),
          _maxIntervalMs,
        );

        Logger.w('Poll failed, backing off to $_currentIntervalMs ms '
            'after $_consecutiveErrors consecutive errors');
      }
    });
  }

  /// Monitor battery status and adjust polling accordingly
  void _monitorBatteryStatus() {
    // Check battery level periodically
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        final batteryLevel = await _battery.batteryLevel;
        final isLow = batteryLevel <= _lowBatteryThreshold;

        _adjustForBatteryStatus(isLow);
      } catch (e) {
        Logger.e('Error checking battery status: $e');
      }
    });

    // Also listen for low battery state
    _battery.onBatteryStateChanged.listen((state) {
      if (state == BatteryState.discharging) {
        _checkAndAdjustForLowBattery();
      }
    });

    // Initial check
    _checkAndAdjustForLowBattery();
  }

  /// Check if battery is low and adjust accordingly
  Future<void> _checkAndAdjustForLowBattery() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      final isLow = batteryLevel <= _lowBatteryThreshold;

      _adjustForBatteryStatus(isLow);
    } catch (e) {
      Logger.e('Error checking battery status: $e');
    }
  }

  /// Adjust polling strategy based on battery status
  void _adjustForBatteryStatus(bool isLowBattery) {
    synchronized(_lock, () {
      if (isLowBattery) {
        // Increase interval for low battery
        final newInterval = math.min(
          (_baseIntervalMs * _lowBatteryMultiplier).toInt(),
          _maxIntervalMs,
        );

        if (_currentIntervalMs < newInterval) {
          Logger.i('Low battery detected, increasing polling interval '
              'from $_currentIntervalMs ms to $newInterval ms');
          _currentIntervalMs = newInterval;

          // Reschedule with new interval
          if (!_isPaused && _timer != null && _timer!.isActive) {
            _timer?.cancel();
            _scheduleNextPoll();
          }
        }
      } else if (_consecutiveErrors == 0) {
        // If battery is normal and we're not in backoff mode,
        // restore normal interval
        if (_currentIntervalMs > _baseIntervalMs && _consecutiveErrors == 0) {
          Logger.i(
              'Battery normal, restoring base polling interval: $_baseIntervalMs ms');
          _currentIntervalMs = _baseIntervalMs;

          // Reschedule with new interval
          if (!_isPaused && _timer != null && _timer!.isActive) {
            _timer?.cancel();
            _scheduleNextPoll();
          }
        }
      }
    });
  }

  /// Get the current polling interval
  int getCurrentInterval() {
    return synchronized(_lock, () => _currentIntervalMs);
  }

  /// Shutdown the polling strategy
  void shutdown() {
    synchronized(_lock, () {
      _isPaused = true;
      _timer?.cancel();
      _timer = null;
      Logger.i('Polling strategy shut down');
    });
  }
}
