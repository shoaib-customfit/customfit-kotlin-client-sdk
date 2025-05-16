import 'dart:async';
import 'package:customfit_flutter_client_sdk/src/core/error/cf_result.dart';
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
import '../config/core/cf_config.dart';

/// Handles fetching configuration from the CustomFit API with support for offline mode
class ConfigFetcher {
  static const String _source = "ConfigFetcher";

  final HttpClient _httpClient;
  final CFConfig _config;
  final CFUser _user;

  final _offlineMode = ValueNotifier<bool>(false);
  final _fetchMutex = Completer<void>();
  Map<String, dynamic>? _lastConfigMap;
  final _mutex = Completer<void>();
  // ignore: unused_field
  int _lastFetchTime = 0;

  // Store metadata headers for conditional requests
  String? _lastModified;
  String? _lastEtag;

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
          "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}?cfenc=${_config.clientKey}";

      debugPrint("*** USER CONFIGS *** Fetching from URL: $url");
      if (lastModified != null) {
        debugPrint("*** USER CONFIGS *** Using Last-Modified: $lastModified");
      }

      // Build payload
      final jsonObject = {
        "user": _user.toMap(),
        "include_only_features_flags": true,
      };
      final payload = jsonEncode(jsonObject);

      debugPrint(
          "*** USER CONFIGS *** Request payload: ${payload.length > 500 ? payload.substring(0, 500) + '...' : payload}");

      final headers = <String, String>{
        CFConstants.http.headerContentType: CFConstants.http.contentTypeJson,
      };

      // Add If-Modified-Since header if available (match Kotlin)
      if (lastModified != null) {
        headers[CFConstants.http.headerIfModifiedSince] = lastModified;
      }

      debugPrint("*** USER CONFIGS *** Request headers: $headers");

      final result = await _httpClient.post(
        url,
        data: payload,
        options: Options(headers: headers),
      );

      // Handle 304 Not Modified (match Kotlin)
      if (result.getStatusCode() == 304) {
        debugPrint(
            "*** USER CONFIGS *** Configs not modified (304), using cached configs");
        return true;
      }

      if (!result.isSuccess) {
        debugPrint(
            "*** USER CONFIGS *** Failed to fetch: ${result.getOrNull()}");
        ErrorHandler.handleError(
          "Failed to fetch configuration: ${result.getOrNull()}",
          source: _source,
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
        );
        return false;
      }

      final responseBody = result.getOrNull();
      if (responseBody == null) {
        debugPrint("*** USER CONFIGS *** Empty response received");
        ErrorHandler.handleError(
          "Empty configuration response",
          source: _source,
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
        );
        return false;
      }

      debugPrint(
          "*** USER CONFIGS *** Received response with length: ${responseBody.toString().length}");
      final handled = _handleConfigResponse(responseBody);
      debugPrint(
          "*** USER CONFIGS *** Handled response successfully: $handled");
      return handled;
    } catch (e) {
      debugPrint("*** USER CONFIGS *** Exception during fetch: $e");
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

      // Debug: Print the raw response
      debugPrint('===== CONFIG FETCHER: RAW RESPONSE =====');
      debugPrint(jsonResponse.length > 1000
          ? '${jsonResponse.substring(0, 1000)}... (truncated)'
          : jsonResponse);
      debugPrint('=======================================');

      final configsJson = responseMap['configs'] as Map<String, dynamic>?;

      if (configsJson == null) {
        const message = "No 'configs' object found in the response";
        ErrorHandler.handleError(
          message,
          source: _source,
          category: ErrorCategory.validation,
          severity: ErrorSeverity.medium,
        );
        return CFResult.success(<String, dynamic>{});
      }

      // Debug: Print the configs section
      debugPrint('===== CONFIG FETCHER: CONFIGS SECTION =====');
      debugPrint(jsonEncode(configsJson).length > 1000
          ? '${jsonEncode(configsJson).substring(0, 1000)}... (truncated)'
          : jsonEncode(configsJson));
      debugPrint('=========================================');

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

        // Debug: Print the final processed config map
        debugPrint('===== CONFIG FETCHER: PROCESSED CONFIG MAP =====');
        finalConfigMap.forEach((key, value) {
          debugPrint('$key: $value');
        });
        debugPrint('=============================================');
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
    // If no URL is provided, construct the SDK settings URL (not user configs)
    final targetUrl = url ?? _buildSdkSettingsUrl();

    if (isOffline()) {
      debugPrint("Not fetching metadata because client is in offline mode");
      return Future<CFResult<Map<String, String>>>.value(
          CFResult.error("Client is in offline mode"));
    }

    try {
      debugPrint("Fetching metadata from $targetUrl");
      // Pass previously stored headers for conditional request
      final result = await _httpClient.fetchMetadata(targetUrl,
          lastModified: _lastModified, etag: _lastEtag);

      if (result.isSuccess) {
        // Store the headers for next request
        final headers = result.getOrNull() ?? {};
        _lastModified = headers[CFConstants.http.headerLastModified];
        _lastEtag = headers[CFConstants.http.headerEtag];

        debugPrint(
            "Stored headers for next request - Last-Modified: $_lastModified, ETag: $_lastEtag");
      }

      if (!result.isSuccess) {
        return CFResult.error("Error fetching metadata");
      }
      return result;
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error fetching metadata from $targetUrl",
        source: _source,
        severity: ErrorSeverity.high,
      );

      return Future<CFResult<Map<String, String>>>.value(
          CFResult.error("Error fetching metadata: ${e.toString()}"));
    }
  }

  /// Build SDK settings URL with dimension ID
  String _buildSdkSettingsUrl() {
    final String dimensionId = _config.dimensionId ?? "default";
    final sdkSettingsPath =
        CFConstants.api.sdkSettingsPathPattern.replaceFirst('%s', dimensionId);
    return "${CFConstants.api.sdkSettingsBaseUrl}$sdkSettingsPath";
  }

  /// Returns the last successfully fetched configuration map
  CFResult<Map<String, dynamic>> getConfigs() {
    if (_lastConfigMap != null) {
      // Debug: Print the full last config map
      debugPrint('===== CONFIG FETCHER: LAST CONFIG MAP =====');
      _lastConfigMap!.forEach((key, value) {
        debugPrint('$key: $value');
      });
      debugPrint('=========================================');

      return CFResult.success(_lastConfigMap!);
    } else {
      return CFResult.error("No configuration has been fetched yet");
    }
  }

  Future<CFResult<Map<String, dynamic>>> fetchSdkSettings() async {
    // Respect offline mode
    if (_offlineMode.value) {
      return CFResult.error("Cannot fetch SDK settings in offline mode",
          category: ErrorCategory.network);
    }

    try {
      // Build request URL with dimension ID
      final dimensionId = _config.dimensionId;
      if (dimensionId == null) {
        return CFResult.error("Failed to extract dimension ID from client key",
            category: ErrorCategory.validation);
      }

      // Use the same URL building helper method for consistency
      final url = _buildSdkSettingsUrl();

      // Make request using fetchJson
      final result = await _httpClient.fetchJson(url);

      return result;
    } catch (e) {
      ErrorHandler.handleException(e, "Unexpected error fetching SDK settings",
          source: _source, severity: ErrorSeverity.high);
      return CFResult.error("Failed to fetch SDK settings",
          exception: e, category: ErrorCategory.internal);
    }
  }
}
