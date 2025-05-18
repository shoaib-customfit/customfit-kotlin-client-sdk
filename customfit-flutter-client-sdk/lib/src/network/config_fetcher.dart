import 'dart:async';
import 'package:customfit_flutter_client_sdk/src/core/error/cf_result.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

import '../core/model/cf_user.dart';
import '../core/error/error_category.dart';
import '../core/error/error_severity.dart';
import '../core/error/error_handler.dart';
import '../constants/cf_constants.dart';
import '../../logging/logger.dart';
import 'http_client.dart';
import '../config/core/cf_config.dart';

/// Handles fetching configuration from the CustomFit API with support for offline mode
class ConfigFetcher {
  static const String _source = "ConfigFetcher";

  final HttpClient _httpClient;
  final CFConfig _config;
  final CFUser _user;

  bool _offlineMode = false;
  Completer<void> _fetchMutex = Completer<void>();
  Map<String, dynamic>? _lastConfigMap;
  final _mutex = Completer<void>();
  int _lastFetchTime = 0;

  // Store metadata headers for conditional requests
  String? _lastModified;
  String? _lastEtag;

  ConfigFetcher(this._httpClient, this._config, this._user) {
    _fetchMutex.complete();
    _mutex.complete();
    Logger.d('ConfigFetcher initialized with user: ${_user.userCustomerId}');
  }

  /// Returns whether the client is in offline mode
  bool isOffline() => _offlineMode;

  /// Sets the offline mode status
  void setOffline(bool offline) {
    _offlineMode = offline;
    Logger.i("ConfigFetcher offline mode set to: $offline");
  }

  /// Fetches configuration from the API with improved error handling
  Future<bool> fetchConfig({String? lastModified}) async {
    // Don't fetch if in offline mode
    if (isOffline()) {
      Logger.d("Not fetching config because client is in offline mode");
      return false;
    }

    // Create a new mutex if needed
    final completer = Completer<void>();
    final oldCompleter = _fetchMutex;
    if (oldCompleter.isCompleted) {
      _fetchMutex = completer;
    } else {
      Logger.d("Fetch already in progress, waiting...");
      await _fetchMutex.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          Logger.w("Timed out waiting for previous fetch to complete");
          // Continue anyway, but create a new mutex
          _fetchMutex = completer;
        },
      );
    }

    try {
      final url =
          "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}?cfenc=${_config.clientKey}";

      Logger.i("API POLL: Fetching config from URL: $url");
      if (lastModified != null) {
        Logger.i("API POLL: Using If-Modified-Since: $lastModified");
      }

      // Build payload
      final jsonObject = {
        "user": _user.toMap(),
        "include_only_features_flags": true,
      };
      final payload = jsonEncode(jsonObject);

      Logger.d("Config fetch payload size: ${payload.length} bytes");

      final headers = <String, String>{
        CFConstants.http.headerContentType: CFConstants.http.contentTypeJson,
      };

      // Add If-Modified-Since header if available (match Kotlin)
      if (lastModified != null) {
        headers[CFConstants.http.headerIfModifiedSince] = lastModified;
      }

      // Add timeout to the HTTP request
      final result = await _httpClient
          .post(
        url,
        data: payload,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(milliseconds: 10000),
          receiveTimeout: const Duration(milliseconds: 10000),
        ),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Logger.w("API POLL: Request timed out after 10 seconds");
          return CFResult.error("Request timed out",
              category: ErrorCategory.network);
        },
      );

      // Handle 304 Not Modified (match Kotlin)
      if (result.getStatusCode() == 304) {
        Logger.i("API POLL: Configs not modified (304), using cached configs");
        completer.complete();
        return true;
      }

      if (!result.isSuccess) {
        Logger.w("API POLL: Failed to fetch: ${result.getErrorMessage()}");
        ErrorHandler.handleError(
          "Failed to fetch configuration: ${result.getErrorMessage()}",
          source: _source,
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
        );
        completer.complete();
        return false;
      }

      final responseBody = result.getOrNull();
      if (responseBody == null) {
        Logger.w("API POLL: Empty response received");
        ErrorHandler.handleError(
          "Empty configuration response",
          source: _source,
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
        );
        completer.complete();
        return false;
      }

      Logger.i(
          "API POLL: Successfully fetched config, response size: ${responseBody.toString().length} bytes");
      final handled = _handleConfigResponse(responseBody);
      Logger.i("API POLL: Handled response successfully: $handled");
      completer.complete();
      return handled;
    } catch (e) {
      Logger.e("API POLL: Error fetching configuration: ${e.toString()}");
      ErrorHandler.handleException(
        e,
        "Error fetching configuration",
        source: _source,
        severity: ErrorSeverity.high,
      );
      completer.complete();
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
        Logger.w("Unexpected response type: ${responseBody.runtimeType}");
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
        const message = "No 'configs' object found in the response";
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

      // Log config keys
      Logger.d("Config keys: ${finalConfigMap.keys.join(', ')}");

      // Print each config key and its variation value only (match Kotlin)
      finalConfigMap.forEach((key, value) {
        if (value is Map<String, dynamic> && value.containsKey('variation')) {
          final variation = value['variation'];
          Logger.d("$key: $variation");
        } else {
          Logger.d("$key: $value");
        }
      });

      // Keep existing hero_text debug logging for backward compatibility
      try {
        final heroText = finalConfigMap['hero_text'] is Map<String, dynamic>
            ? (finalConfigMap['hero_text'] as Map<String, dynamic>)['variation']
            : null;
        if (heroText != null) {
          Logger.d("Hero text if present: $heroText");
        }
      } catch (e) {
        // Ignore error
      }

      return CFResult.success(finalConfigMap);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Error parsing configuration response",
        source: _source,
        severity: ErrorSeverity.high,
      );

      return CFResult.error(
        "Error parsing configuration response: ${e.toString()}",
        exception: e,
        category: ErrorCategory.serialization,
      );
    }
  }

  /// Fetches metadata from a URL with improved error handling
  Future<CFResult<Map<String, String>>> fetchMetadata([String? url]) async {
    // If no URL is provided, construct the SDK settings URL (not user configs)
    final targetUrl = url ?? _buildSdkSettingsUrl();

    if (isOffline()) {
      Logger.d("Not fetching metadata because client is in offline mode");
      return CFResult.error("Client is in offline mode",
          category: ErrorCategory.network);
    }

    try {
      Logger.i(
          "API POLL: Fetch metadata strategy - First trying HEAD request: $targetUrl");

      // First try a lightweight HEAD request (match Kotlin)
      final headResult = await _httpClient.head(targetUrl);

      if (headResult.isSuccess) {
        final headers = headResult.getOrNull()?.headers.map ?? {};
        final metadata = {
          CFConstants.http.headerLastModified:
              headers['last-modified']?.first ?? '',
          CFConstants.http.headerEtag: headers['etag']?.first ?? '',
        };
        Logger.i("API POLL: HEAD request successful, using result: $metadata");
        return CFResult.success(metadata);
      }

      // If HEAD fails, fall back to the original GET method
      Logger.i(
          "API POLL: HEAD request failed, falling back to GET: $targetUrl");
      final getResult = await _httpClient.fetchMetadata(targetUrl,
          lastModified: _lastModified, etag: _lastEtag);

      if (getResult.isSuccess) {
        Logger.i("API POLL: Fallback GET successful: ${getResult.getOrNull()}");
      } else {
        Logger.w("API POLL: Both HEAD and GET failed for $targetUrl");
      }

      if (getResult.isSuccess) {
        // Store the headers for next request
        final headers = getResult.getOrNull() ?? {};
        _lastModified = headers[CFConstants.http.headerLastModified];
        _lastEtag = headers[CFConstants.http.headerEtag];
      }

      return getResult;
    } catch (e) {
      Logger.e(
          "API POLL: Exception during metadata fetch attempts: ${e.toString()}");
      ErrorHandler.handleException(
        e,
        "Error fetching metadata from $targetUrl",
        source: _source,
        severity: ErrorSeverity.high,
      );

      return CFResult.error(
        "Error fetching metadata: ${e.toString()}",
        exception: e,
        category: ErrorCategory.network,
      );
    }
  }

  /// Build SDK settings URL with dimension ID
  String _buildSdkSettingsUrl() {
    final String dimensionId = _config.dimensionId ?? "default";
    final sdkSettingsPath =
        CFConstants.api.sdkSettingsPathPattern.replaceFirst('%s', dimensionId);
    return CFConstants.api.sdkSettingsBaseUrl + sdkSettingsPath;
  }

  /// Returns the last successfully fetched configuration map
  CFResult<Map<String, dynamic>> getConfigs() {
    if (_lastConfigMap != null) {
      // Log the full last config map for easier debugging
      Logger.d('===== CONFIG FETCHER: LAST CONFIG MAP =====');
      _lastConfigMap!.forEach((key, value) {
        Logger.d('$key: $value');
      });
      Logger.d('=========================================');

      return CFResult.success(_lastConfigMap!);
    } else {
      return CFResult.error("No configuration has been fetched yet",
          category: ErrorCategory.validation);
    }
  }

  Future<CFResult<Map<String, dynamic>>> fetchSdkSettings() async {
    // Respect offline mode
    if (_offlineMode) {
      Logger.d('Not fetching SDK settings because client is in offline mode');
      return CFResult.error("Cannot fetch SDK settings in offline mode",
          category: ErrorCategory.network);
    }

    try {
      // Use the same URL building helper method for consistency
      final url = _buildSdkSettingsUrl();

      Logger.i("API POLL: Fetching full SDK settings with GET: $url");

      // Make request using fetchJson
      final result = await _httpClient.fetchJson(url);

      if (result.isSuccess) {
        Logger.i("API POLL: SDK settings parsed successfully");
      } else {
        Logger.w("API POLL: Failed to parse SDK settings response");
      }

      return result;
    } catch (e) {
      Logger.e(
          "API POLL: Exception during SDK settings fetch: ${e.toString()}");
      ErrorHandler.handleException(e, "Unexpected error fetching SDK settings",
          source: _source, severity: ErrorSeverity.high);

      return CFResult.error("Failed to fetch SDK settings",
          exception: e, category: ErrorCategory.internal);
    }
  }
}
