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

  final Queue<CFConfigRequestSummary> _queue =
      ListQueue<CFConfigRequestSummary>();
  final Map<String, bool> _trackMap = {};

  Timer? _timer;

  SummaryManager(
    this._sessionId,
    this._httpClient,
    this._user,
    this._config,
  ) {
    _queueSize = _config.summariesQueueSize;
    _flushIntervalMs = _config.summariesFlushIntervalMs;
    Logger.i(
        'SummaryManager initialized with queueSize=\$_queueSize, flushIntervalMs=\$_flushIntervalMs');
    _startPeriodicFlush();
  }

  /// Updates the flush interval
  Future<CFResult<int>> updateFlushInterval(int intervalMs) async {
    try {
      if (intervalMs <= 0) throw ArgumentError('Interval must be > 0');
      _flushIntervalMs = intervalMs;
      _restartPeriodicFlush();
      Logger.i('Updated summaries flush interval to \$intervalMs ms');
      return CFResult.success(intervalMs);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to update flush interval to \$intervalMs',
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
  CFResult<bool> pushSummary(Map<String, dynamic> config) {
    // Validate map keys
    if (config.keys.any((k) => k.runtimeType != String)) {
      const msg = 'Config map has non-string keys: \$config';
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
      ErrorHandler.handleError(
        msg,
        source: _SOURCE,
        category: ErrorCategory.validation,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(msg, category: ErrorCategory.validation);
    }

    // Prevent duplicate
    if (_trackMap.containsKey(experienceId)) {
      Logger.d('Experience already processed: \$experienceId');
      return CFResult.success(true);
    }
    _trackMap[experienceId] = true;

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

    if (_queue.length >= _queueSize) {
      ErrorHandler.handleError(
        'Summary queue full, forcing flush for new entry',
        source: _SOURCE,
        category: ErrorCategory.internal,
        severity: ErrorSeverity.medium,
      );
      flushSummaries();
      if (_queue.length >= _queueSize) {
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
    Logger.d('Summary added to queue: \$summary');
    if (_queue.length >= _queueSize) {
      flushSummaries();
    }

    return CFResult.success(true);
  }

  /// Flushes summaries and returns count flushed
  Future<CFResult<int>> flushSummaries() async {
    if (_queue.isEmpty) {
      Logger.d('No summaries to flush');
      return CFResult.success(0);
    }

    final batch = <CFConfigRequestSummary>[];
    while (_queue.isNotEmpty) {
      batch.add(_queue.removeFirst());
    }

    try {
      final result = await _sendSummariesToServer(batch);
      if (result.isSuccess) {
        Logger.i('Flushed ${batch.length} summaries successfully');
        return CFResult.success(batch.length);
      } else {
        return CFResult.error(
          'Failed to flush summaries',
          category: ErrorCategory.network,
        );
      }
    } catch (e) {
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
    final payload = jsonEncode({
      'user': _user.toMap(),
      'summaries': summaries.map((s) => s.toMap()).toList(),
      'cf_client_sdk_version': _config.clientKey,
    });

    try {
      final result = await RetryUtil.withRetry<CFResult<dynamic>>(
        block: () async {
          final res = await _httpClient.post(
            'https://api.customfit.ai/v1/config/request/summary?cfenc=${_config.clientKey}',
            data: payload,
          );
          return res;
        },
        maxAttempts: 3,
        initialDelayMs: 1000,
        maxDelayMs: 10000,
        backoffMultiplier: 1.5,
      );

      if (result.isSuccess) {
        return CFResult.success(true);
      } else {
        return CFResult.error('Failed to send summaries');
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Error sending summaries to server',
        source: _SOURCE,
        severity: ErrorSeverity.high,
      );
      // Requeue on failure
      var requeueFail = false;
      for (var s in summaries) {
        if (_queue.length < _queueSize) {
          _queue.addLast(s);
        } else {
          requeueFail = true;
        }
      }
      if (requeueFail) {
        ErrorHandler.handleError(
          'Failed to re-queue some summaries after send failure',
          source: _SOURCE,
          category: ErrorCategory.internal,
          severity: ErrorSeverity.high,
        );
      }
      return CFResult.error(
        'Error sending summaries to server',
        exception: e,
        category: ErrorCategory.network,
      );
    }
  }

  void _startPeriodicFlush() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _flushIntervalMs),
      (_) => flushSummaries(),
    );
  }

  void _restartPeriodicFlush() {
    _startPeriodicFlush();
  }

  /// Returns the map of processed experiences
  Map<String, bool> getSummaries() => Map.unmodifiable(_trackMap);

  /// Shutdown and clean up
  Future<void> shutdown() async {
    _timer?.cancel();
    await flushSummaries();
  }
}
