// lib/src/analytics/summary/summary_manager.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import '../../core/error/cf_result.dart';
import '../../core/error/error_category.dart';
import '../../core/error/error_handler.dart';
import '../../core/error/error_severity.dart';
import '../../core/logging/logger.dart';
import '../../core/model/cf_user.dart';
import '../../config/core/cf_config.dart';
import '../../core/util/retry_util.dart';
import '../../network/http_client.dart';
import 'cf_config_request_summary.dart';
import 'package:intl/intl.dart';

/// Manages collection and flushing of configuration summaries, mirroring Kotlin's SummaryManager
class SummaryManager {
  static const _SOURCE = 'SummaryManager';

  final String _sessionId;
  final HttpClient _httpClient;
  final CFUser _user;
  final CFConfig _config;

  late final int _queueSize;
  late int _flushIntervalMs;
  final int _flushTimeSeconds;

  final Queue<CFConfigRequestSummary> _queue =
      ListQueue<CFConfigRequestSummary>();
  final Map<String, bool> _trackMap = {};

  Timer? _timer;
  final Object _timerLock = Object();
  final Object _trackLock = Object();

  SummaryManager(
    this._sessionId,
    this._httpClient,
    this._user,
    this._config,
  ) : _flushTimeSeconds = _config.summariesFlushTimeSeconds {
    _queueSize = _config.summariesQueueSize;
    _flushIntervalMs = _config.summariesFlushIntervalMs;
    Logger.i(
        'SummaryManager initialized with queueSize=$_queueSize, flushIntervalMs=$_flushIntervalMs, flushTimeSeconds=$_flushTimeSeconds');
    _startPeriodicFlush();
  }

  /// Updates the flush interval
  Future<CFResult<int>> updateFlushInterval(int intervalMs) async {
    try {
      if (intervalMs <= 0) throw ArgumentError('Interval must be > 0');
      _flushIntervalMs = intervalMs;
      await _restartPeriodicFlush();
      Logger.i('Updated summaries flush interval to $intervalMs ms');
      return CFResult.success(intervalMs);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to update flush interval to $intervalMs',
        source: _SOURCE,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(
        'Failed to update summaries flush interval',
        exception: e,
        category: ErrorCategory.validation,
      );
    }
  }

  /// Pushes a config summary into the queue
  Future<CFResult<bool>> pushSummary(Map<String, dynamic> config) async {
    // Log the config being processed
    Logger.i(
        '📊 SUMMARY: Processing summary for config: ${config["key"] ?? "unknown"}');

    // Validate map keys
    if (config.keys.any((k) => k.runtimeType != String)) {
      const msg = 'Config map has non-string keys';
      Logger.w('📊 SUMMARY: $msg');
      ErrorHandler.handleError(
        msg,
        source: _SOURCE,
        category: ErrorCategory.validation,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(msg, category: ErrorCategory.validation);
    }

    // Mandatory fields
    final experienceId = config['experience_id'] as String?;
    if (experienceId == null) {
      const msg = 'Missing mandatory experience_id in config';
      Logger.w('📊 SUMMARY: $msg, summary not tracked');
      ErrorHandler.handleError(
        msg,
        source: _SOURCE,
        category: ErrorCategory.validation,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(msg, category: ErrorCategory.validation);
    }

    final configId = config['config_id'] as String?;
    final variationId = config['variation_id'] as String?;
    final version = config['version']?.toString();

    final missingFields = <String>[];
    if (configId == null) missingFields.add('config_id');
    if (variationId == null) missingFields.add('variation_id');
    if (version == null) missingFields.add('version');

    if (missingFields.isNotEmpty) {
      final msg =
          'Missing mandatory fields for summary: ${missingFields.join(', ')}';
      Logger.w('📊 SUMMARY: $msg, summary not tracked');
      ErrorHandler.handleError(
        msg,
        source: _SOURCE,
        category: ErrorCategory.validation,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(msg, category: ErrorCategory.validation);
    }

    // Prevent duplicate using a synchronized lock
    bool shouldProcess = false;
    synchronized(_trackLock, () {
      if (_trackMap.containsKey(experienceId)) {
        Logger.d('📊 SUMMARY: Experience already processed: $experienceId');
      } else {
        _trackMap[experienceId] = true;
        shouldProcess = true;
      }
    });

    if (!shouldProcess) {
      return CFResult.success(true);
    }

    final summary = CFConfigRequestSummary(
      configId: configId,
      version: version,
      userId: config['user_id'] as String?,
      requestedTime:
          DateFormat('yyyy-MM-dd HH:mm:ss.SSSX').format(DateTime.now().toUtc()),
      variationId: variationId,
      userCustomerId: _user.userCustomerId ?? '',
      sessionId: _sessionId,
      behaviourId: config['behaviour_id'] as String?,
      experienceId: experienceId,
      ruleId: config['rule_id'] as String?,
    );

    Logger.i(
        '📊 SUMMARY: Created summary for experience: $experienceId, config: $configId');

    if (_queue.length >= _queueSize) {
      Logger.w('📊 SUMMARY: Queue full, forcing flush for new entry');
      ErrorHandler.handleError(
        'Summary queue full, forcing flush for new entry',
        source: _SOURCE,
        category: ErrorCategory.internal,
        severity: ErrorSeverity.medium,
      );

      await flushSummaries();

      if (_queue.length >= _queueSize) {
        Logger.e('📊 SUMMARY: Failed to queue summary after flush');
        ErrorHandler.handleError(
          'Failed to queue summary after flush',
          source: _SOURCE,
          category: ErrorCategory.internal,
          severity: ErrorSeverity.high,
        );
        return CFResult.error(
          'Queue still full after flush',
          category: ErrorCategory.internal,
        );
      }
    }

    _queue.addLast(summary);
    Logger.i(
        '📊 SUMMARY: Added to queue: experience=$experienceId, queue size=${_queue.length}');

    // Check if queue size threshold is reached
    if (_queue.length >= _queueSize) {
      Logger.i(
          '📊 SUMMARY: Queue size threshold reached (${_queue.length}/$_queueSize), triggering flush');
      flushSummaries();
    }

    return CFResult.success(true);
  }

  /// Flushes summaries and returns count flushed
  Future<CFResult<int>> flushSummaries() async {
    if (_queue.isEmpty) {
      Logger.d('📊 SUMMARY: No summaries to flush');
      return CFResult.success(0);
    }

    final batch = <CFConfigRequestSummary>[];
    while (_queue.isNotEmpty) {
      batch.add(_queue.removeFirst());
    }

    if (batch.isEmpty) {
      Logger.d('📊 SUMMARY: No summaries to flush after drain');
      return CFResult.success(0);
    }

    Logger.i('📊 SUMMARY: Flushing ${batch.length} summaries to server');

    try {
      final result = await _sendSummariesToServer(batch);
      if (result.isSuccess) {
        Logger.i(
            '📊 SUMMARY: Successfully flushed ${batch.length} summaries to server');
        return CFResult.success(batch.length);
      } else {
        Logger.w(
            '📊 SUMMARY: Failed to flush summaries: ${result.getErrorMessage()}');
        return CFResult.error(
          'Failed to flush summaries: ${result.getErrorMessage()}',
          category: ErrorCategory.network,
        );
      }
    } catch (e) {
      Logger.e(
          '📊 SUMMARY: Unexpected error during summary flush: ${e.toString()}');
      ErrorHandler.handleException(
        e,
        'Unexpected error during summary flush',
        source: _SOURCE,
        severity: ErrorSeverity.high,
      );
      return CFResult.error(
        'Failed to flush summaries',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  Future<CFResult<bool>> _sendSummariesToServer(
      List<CFConfigRequestSummary> summaries) async {
    Logger.i(
        '📊 SUMMARY HTTP: Preparing to send ${summaries.length} summaries');

    // Log detailed summary information before HTTP call
    summaries.asMap().forEach((index, summary) {
      Logger.d(
          '📊 SUMMARY HTTP: Summary #${index + 1}: experience_id=${summary.experienceId}, config_id=${summary.configId}');
    });

    final payload = jsonEncode({
      'user': _user.toMap(),
      'summaries': summaries.map((s) => s.toMap()).toList(),
      'cf_client_sdk_version': '1.1.1', // Match the version from Kotlin SDK
    });

    final url =
        'https://api.customfit.ai/v1/config/request/summary?cfenc=${_config.clientKey}';

    try {
      var success = false;
      final result = await RetryUtil.withRetry<CFResult<dynamic>>(
        block: () async {
          Logger.d('📊 SUMMARY: Attempting to send summaries');
          final res = await _httpClient.post(
            url,
            data: payload,
          );

          if (!res.isSuccess) {
            Logger.w('📊 SUMMARY: Server returned error, retrying...');
            throw Exception('Failed to send summaries - server returned error');
          }

          Logger.i('📊 SUMMARY: Server accepted summaries');
          success = true;
          return res;
        },
        maxAttempts: _config.maxRetryAttempts,
        initialDelayMs: _config.retryInitialDelayMs,
        maxDelayMs: _config.retryMaxDelayMs,
        backoffMultiplier: _config.retryBackoffMultiplier,
      );

      if (success) {
        Logger.i(
            '📊 SUMMARY: Successfully sent ${summaries.length} summaries to server');
        return CFResult.success(true);
      } else {
        Logger.w(
            '📊 SUMMARY: Failed to send summaries after ${_config.maxRetryAttempts} attempts');
        await _handleSendFailure(summaries);
        return CFResult.error(
          'Failed to send summaries after ${_config.maxRetryAttempts} attempts',
          category: ErrorCategory.network,
        );
      }
    } catch (e) {
      Logger.e(
          '📊 SUMMARY: Error sending summaries to server: ${e.toString()}');
      ErrorHandler.handleException(
        e,
        'Error sending summaries to server',
        source: _SOURCE,
        severity: ErrorSeverity.high,
      );
      await _handleSendFailure(summaries);
      return CFResult.error(
        'Error sending summaries to server: ${e.toString()}',
        exception: e,
        category: ErrorCategory.network,
      );
    }
  }

  /// Helper method to handle send failures by re-queueing summaries
  Future<void> _handleSendFailure(
      List<CFConfigRequestSummary> summaries) async {
    Logger.w(
        '📊 SUMMARY: Failed to send ${summaries.length} summaries after retries, re-queuing');
    var requeueFailCount = 0;

    for (final summary in summaries) {
      if (_queue.length >= _queueSize) {
        requeueFailCount++;
      } else {
        _queue.addLast(summary);
      }
    }

    if (requeueFailCount > 0) {
      Logger.e(
          '📊 SUMMARY: Failed to re-queue $requeueFailCount summaries after send failure');
      ErrorHandler.handleError(
        'Failed to re-queue $requeueFailCount summaries after send failure',
        source: _SOURCE,
        category: ErrorCategory.internal,
        severity: ErrorSeverity.high,
      );
    }
  }

  void _startPeriodicFlush() {
    synchronized(_timerLock, () {
      // Cancel existing timer
      _timer?.cancel();
      _timer = null;

      // Create new timer
      _timer = Timer.periodic(
        Duration(milliseconds: _flushIntervalMs),
        (_) async {
          try {
            Logger.d('📊 SUMMARY: Periodic flush triggered for summaries');
            await flushSummaries();
          } catch (e) {
            Logger.e(
                '📊 SUMMARY: Error during periodic summary flush: ${e.toString()}');
            ErrorHandler.handleException(
              e,
              'Error during periodic summary flush',
              source: _SOURCE,
              severity: ErrorSeverity.medium,
            );
          }
        },
      );

      Logger.d(
          '📊 SUMMARY: Started periodic summary flush with interval $_flushIntervalMs ms');
    });
  }

  Future<void> _restartPeriodicFlush() async {
    synchronized(_timerLock, () {
      // Cancel existing timer
      _timer?.cancel();
      _timer = null;

      // Create new timer with updated interval
      _timer = Timer.periodic(
        Duration(milliseconds: _flushIntervalMs),
        (_) async {
          try {
            Logger.d('📊 SUMMARY: Periodic flush triggered for summaries');
            await flushSummaries();
          } catch (e) {
            Logger.e(
                '📊 SUMMARY: Error during periodic summary flush: ${e.toString()}');
            ErrorHandler.handleException(
              e,
              'Error during periodic summary flush',
              source: _SOURCE,
              severity: ErrorSeverity.medium,
            );
          }
        },
      );

      Logger.d(
          '📊 SUMMARY: Restarted periodic flush with interval $_flushIntervalMs ms');
    });
  }

  /// Returns all tracked summaries
  Map<String, bool> getSummaries() => Map.unmodifiable(_trackMap);

  /// Shutdown method to clean up timers
  void shutdown() {
    _timer?.cancel();
    _timer = null;
    Logger.i('📊 SUMMARY: Summary manager shutdown');
  }
}

/// Helper for synchronized blocks (similar to Kotlin's mutex)
T synchronized<T>(Object lock, T Function() fn) {
  try {
    // In Dart we don't have actual synchronization primitives like in Kotlin
    // This is a placeholder that simulates that pattern for code organization
    return fn();
  } finally {
    // No implementation needed in Dart since we don't have actual mutexes
  }
}
