import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../../config/core/cf_config.dart';
import '../../core/model/cf_user.dart';
import '../../core/error/cf_result.dart';
import '../../core/error/error_category.dart';
import '../../core/error/error_severity.dart';
import '../../core/error/error_handler.dart';
import '../../constants/cf_constants.dart';
import '../../../logging/logger.dart';
import '../http_client.dart';

/// Handles fetching configuration from the CustomFit API with support for offline mode
class ConfigFetcher {
  /// HTTP client for API requests
  final HttpClient _httpClient;

  /// Configuration
  // ignore: unused_field
  final CFConfig _config;

  /// Current user
  final CFUser _user;

  /// Whether the client is in offline mode
  bool _offlineMode = false;

  /// Lock to prevent concurrent fetches
  Completer<void> _fetchLock = Completer<void>()..complete();

  /// Last fetched config map
  Map<String, dynamic>? _lastConfigMap;

  /// Last fetch time
  int _lastFetchTime = 0;

  /// Source name for logging
  static const String _source = 'ConfigFetcher';

  /// Creates a new config fetcher
  ConfigFetcher(this._httpClient, this._config, this._user) {
    Logger.d('ConfigFetcher initialized');
  }

  /// Returns whether the client is in offline mode
  bool isOffline() => _offlineMode;

  /// Sets the offline mode status
  void setOffline(bool offline) {
    _offlineMode = offline;
    Logger.d('ConfigFetcher offline mode set to: $_offlineMode');
  }

  /// Fetches configuration from the API
  ///
  /// [lastModified] Optional last-modified header value for conditional requests
  Future<bool> fetchConfig({String? lastModified}) async {
    // Don't fetch if in offline mode
    if (isOffline()) {
      Logger.d('Not fetching config because client is in offline mode');
      return false;
    }

    // Prevent concurrent fetches
    final currentLock = _fetchLock;
    if (!currentLock.isCompleted) {
      await currentLock.future;
    }

    final newLock = Completer<void>();
    _fetchLock = newLock;

    try {
      // Build URL
      final url =
          '${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}';

      // Build payload using user's toMap method
      final userJson = _user.toMap();
      final payload = jsonEncode({
        'user': userJson,
        'include_only_features_flags': true,
      });

      Logger.d('Config fetch payload: $payload');

      // Build headers
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
      };

      if (lastModified != null) {
        headers['If-Modified-Since'] = lastModified;
      }

      // Make the request
      final result = await _httpClient.post(
        url,
        data: payload,
        options: Options(headers: headers),
      );

      if (result.isSuccess) {
        Logger.d('Successfully fetched configuration');

        // Process the response
        final data = result.getOrNull();
        if (data != null) {
          final processResult = _processConfigResponse(data);
          return processResult.isSuccess;
        }
        return false;
      } else {
        ErrorHandler.handleError(
          'Failed to fetch configuration: ${result.getOrNull()}',
          source: _source,
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
        );
        return false;
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Error fetching configuration',
        source: _source,
        severity: ErrorSeverity.high,
      );
      return false;
    } finally {
      newLock.complete();
    }
  }

  /// Process the configuration response
  ///
  /// [response] The JSON response from the API
  CFResult<Map<String, dynamic>> _processConfigResponse(
      Map<String, dynamic> response) {
    try {
      final configsMap = response['configs'] as Map<String, dynamic>?;

      if (configsMap == null) {
        const message = "No 'configs' object found in the response";
        ErrorHandler.handleError(
          message,
          source: _source,
          category: ErrorCategory.validation,
          severity: ErrorSeverity.medium,
        );
        return CFResult.error(
          message,
          category: ErrorCategory.validation,
        );
      }

      // Extract and process feature flags
      final configMap = <String, dynamic>{};

      for (final entry in configsMap.entries) {
        final configObj = entry.value as Map<String, dynamic>;
        final enabled = configObj['enabled'] as bool? ?? false;
        final attributes =
            configObj['attributes'] as Map<String, dynamic>? ?? {};

        // Store the flag with its attributes
        configMap[entry.key] = {
          'enabled': enabled,
          ...attributes,
        };
      }

      // Store the last config map
      _lastConfigMap = configMap;
      _lastFetchTime = DateTime.now().millisecondsSinceEpoch;

      Logger.d('Processed ${configMap.length} feature flags');

      return CFResult.success(configMap);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Error processing configuration response',
        source: _source,
        severity: ErrorSeverity.high,
      );
      return CFResult.error(
        'Error processing configuration response: ${e.toString()}',
        exception: e,
        category: ErrorCategory.serialization,
      );
    }
  }

  /// Get the last fetched configuration
  Map<String, dynamic>? getLastConfigMap() => _lastConfigMap;

  /// Get the last fetch time
  int getLastFetchTime() => _lastFetchTime;
}
