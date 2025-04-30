import 'dart:async';
import 'package:customfit_flutter_client/src/core/error/cf_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../core/model/sdk_settings.dart';
import '../core/model/cf_user.dart';
import '../core/error/error_category.dart';
import '../core/error/error_severity.dart';
import '../core/error/error_handler.dart';
import '../constants/cf_constants.dart';
import 'http_client.dart';

/// Handles fetching configuration from the CustomFit API with support for offline mode
class ConfigFetcher {
  static const String _source = "ConfigFetcher";

  final HttpClient _httpClient;
  final SdkSettings _config;
  final CFUser _user;

  final _offlineMode = ValueNotifier<bool>(false);
  final _fetchMutex = Completer<void>();
  Map<String, dynamic>? _lastConfigMap;
  final _mutex = Completer<void>();
  // ignore: unused_field
  int _lastFetchTime = 0;

  ConfigFetcher(this._httpClient, this._config, this._user) {
    _fetchMutex.complete();
    _mutex.complete();
  }

  /// Returns whether the client is in offline mode
  bool isOffline() => _offlineMode.value;

  /// Sets the offline mode status
  void setOffline(bool offline) {
    _offlineMode.value = offline;
    debugPrint("ConfigFetcher offline mode set to: $offline");
  }

  /// Fetches configuration from the API with improved error handling
  Future<bool> fetchConfig({String? lastModified}) async {
    // Don't fetch if in offline mode
    if (isOffline()) {
      debugPrint("Not fetching config because client is in offline mode");
      return false;
    }

    await _fetchMutex.future;
    try {
      final url =
          "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}?cfenc=${_config.cfKey}";

      // Build payload
      final jsonObject = {
        "user": _user.toMap(),
        "include_only_features_flags": true,
      };
      final payload = jsonEncode(jsonObject);

      debugPrint("Config fetch payload: $payload");

      final headers = <String, String>{
        CFConstants.http.headerContentType: CFConstants.http.contentTypeJson,
      };
      if (lastModified != null) {
        headers[CFConstants.http.headerIfModifiedSince] = lastModified;
      }

      final result = await _httpClient.post(
        url,
        data: payload,
        options: Options(headers: headers),
      );

      if (!result.isSuccess) {
        ErrorHandler.handleError(
          "Failed to fetch configuration",
          source: _source,
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
        );
        return false;
      }

      final responseBody = result.getOrNull();
      if (responseBody == null) {
        ErrorHandler.handleError(
          "Empty configuration response",
          source: _source,
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
        );
        return false;
      }

      return _handleConfigResponse(responseBody);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error fetching configuration",
        source: _source,
        severity: ErrorSeverity.high,
      );
      return false;
    }
  }

  /// Handle different response types
  bool _handleConfigResponse(dynamic responseBody) {
    // Direct boolean responses (e.g., 304 Not Modified)
    if (responseBody is bool) {
      return responseBody;
    }

    try {
      // String response (JSON)
      if (responseBody is String) {
        final processResult = _processConfigResponse(responseBody);
        return processResult.isSuccess;
      }

      // Map response
      else if (responseBody is Map) {
        final jsonStr = jsonEncode(responseBody);
        final processResult = _processConfigResponse(jsonStr);
        return processResult.isSuccess;
      }

      // Unexpected response type
      else {
        debugPrint("Unexpected response type: ${responseBody.runtimeType}");
        return false;
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error processing response",
        source: _source,
        severity: ErrorSeverity.high,
      );
      return false;
    }
  }

  /// Process the configuration response, with improved error handling
  CFResult<Map<String, dynamic>> _processConfigResponse(String jsonResponse) {
    final finalConfigMap = <String, dynamic>{};

    try {
      // Parse the entire response string into a Map
      final responseMap = jsonDecode(jsonResponse) as Map<String, dynamic>;
      final configsJson = responseMap['configs'] as Map<String, dynamic>?;

      if (configsJson == null) {
        final message = "No 'configs' object found in the response";
        ErrorHandler.handleError(
          message,
          source: _source,
          category: ErrorCategory.validation,
          severity: ErrorSeverity.medium,
        );
        return CFResult.success(<String, dynamic>{});
      }

      // Iterate through each config entry
      configsJson.forEach((key, configElement) {
        try {
          if (configElement is! Map<String, dynamic>) {
            ErrorHandler.handleError(
              "Config entry for '$key' is not a JSON object",
              source: _source,
              category: ErrorCategory.serialization,
              severity: ErrorSeverity.medium,
            );
            return;
          }

          final configObject = configElement;
          final experienceObject = configObject['experience_behaviour_response']
              as Map<String, dynamic>?;

          // Convert the config object to a map
          final flattenedMap = Map<String, dynamic>.from(configObject);

          // Remove the nested object itself (it will be merged)
          flattenedMap.remove('experience_behaviour_response');

          // Merge fields from the nested experience object if it exists
          if (experienceObject != null) {
            flattenedMap.addAll(experienceObject);
          }

          // Store the flattened map, filtering out null values
          finalConfigMap[key] = Map<String, dynamic>.from(
            flattenedMap..removeWhere((_, value) => value == null),
          );
        } catch (e) {
          ErrorHandler.handleException(
            e,
            "Error processing individual config key '$key'",
            source: _source,
            severity: ErrorSeverity.medium,
          );
        }
      });

      // Notify observers of config changes
      if (finalConfigMap != _lastConfigMap) {
        _lastConfigMap = finalConfigMap;
        _lastFetchTime = DateTime.now().millisecondsSinceEpoch;
      }

      return CFResult.success(finalConfigMap);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error parsing configuration response",
        source: _source,
        severity: ErrorSeverity.high,
      );

      return CFResult.error("Error parsing configuration response");
    }
  }

  /// Fetches metadata from a URL with improved error handling
  Future<CFResult<Map<String, String>>> fetchMetadata([String? url]) async {
    final targetUrl = url ??
        "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}?cfenc=${_config.cfKey}";

    if (isOffline()) {
      debugPrint("Not fetching metadata because client is in offline mode");
      return Future<CFResult<Map<String, String>>>.value(
          CFResult.error("Client is in offline mode"));
    }

    try {
      final result = await _httpClient.head(targetUrl);
      if (result.isSuccess) {
        final response = result.getOrNull();
        final headers = response?.headers.map
            .map((key, values) => MapEntry(key, values.join(',')));
        return CFResult.success(headers ?? {});
      } else {
        return CFResult.error("Error fetching metadata");
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error fetching metadata from $targetUrl",
        source: _source,
        severity: ErrorSeverity.high,
      );

      return Future<CFResult<Map<String, String>>>.value(
          CFResult.error("Error fetching metadata"));
    }
  }

  /// Returns the last successfully fetched configuration map
  CFResult<Map<String, dynamic>> getConfigs() {
    if (_lastConfigMap != null) {
      return CFResult.success(_lastConfigMap!);
    } else {
      return CFResult.error("No configuration has been fetched yet");
    }
  }
}
