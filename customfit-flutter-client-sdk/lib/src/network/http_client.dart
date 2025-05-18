import 'dart:async';

import 'package:dio/dio.dart';

import '../config/core/cf_config.dart';
import '../core/error/cf_result.dart';
import '../core/error/error_category.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../constants/cf_constants.dart';
import '../../logging/logger.dart';

/// HTTP client implementation mirroring Kotlin's HttpClient
class HttpClient {
  static const String _source = 'HttpClient';
  final CFConfig _config;
  late final Dio _dio;
  int _connectionTimeoutMs;
  int _readTimeoutMs;

  HttpClient(this._config)
      : _connectionTimeoutMs = _config.networkConnectionTimeoutMs,
        _readTimeoutMs = _config.networkReadTimeoutMs {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: _connectionTimeoutMs),
      receiveTimeout: Duration(milliseconds: _readTimeoutMs),
      headers: {
        CFConstants.http.headerContentType: CFConstants.http.contentTypeJson,
        'User-Agent': 'CustomFit-SDK/1.0 Flutter'
      },
    ));

    // Add custom interceptor for full request/response/error logging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          Logger.d('EXECUTING ${options.method} ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          Logger.d(
              '${response.requestOptions.method} SUCCESSFUL: ${response.statusCode}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          Logger.e('${e.requestOptions.method} FAILED: ${e.message}');
          ErrorHandler.handleError(
            '${e.requestOptions.method} request failed: ${e.message}',
            source: _source,
            category: ErrorCategory.network,
            severity: ErrorSeverity.medium,
          );
          return handler.next(e);
        },
      ),
    );

    Logger.i(
        'HttpClient initialized with connectTimeout=$_connectionTimeoutMs ms, readTimeout=$_readTimeoutMs ms');
  }

  /// Update connection timeout
  void updateConnectionTimeout(int timeoutMs) {
    if (timeoutMs <= 0) throw ArgumentError('Timeout must be > 0');
    _connectionTimeoutMs = timeoutMs;
    _dio.options.connectTimeout = Duration(milliseconds: timeoutMs);
    Logger.d('Updated connection timeout to $timeoutMs ms');
  }

  /// Update read timeout
  void updateReadTimeout(int timeoutMs) {
    if (timeoutMs <= 0) throw ArgumentError('Timeout must be > 0');
    _readTimeoutMs = timeoutMs;
    _dio.options.receiveTimeout = Duration(milliseconds: timeoutMs);
    Logger.d('Updated read timeout to $timeoutMs ms');
  }

  /// GET request for metadata (Last-Modified, ETag)
  Future<CFResult<Map<String, String>>> fetchMetadata(String url,
      {String? lastModified, String? etag}) async {
    try {
      Logger.d('EXECUTING GET METADATA REQUEST');

      // Add caching headers to avoid unnecessary network calls
      final headers = {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
      };

      // Add conditional request headers if available
      if (lastModified != null &&
          lastModified.isNotEmpty &&
          lastModified != 'unchanged') {
        headers['If-Modified-Since'] = lastModified;
      }

      if (etag != null && etag.isNotEmpty && etag != 'unchanged') {
        headers['If-None-Match'] = etag;
      }

      final options = Options(
        headers: headers,
        // Set validateStatus to accept 304 Not Modified responses
        validateStatus: (status) =>
            status != null && (status >= 200 && status < 300 || status == 304),
      );

      final resp = await _dio.get(url, options: options);

      // Handle 304 Not Modified (return the same headers)
      if (resp.statusCode == 304) {
        Logger.d('GET METADATA SUCCESSFUL (304 Not Modified)');
        return CFResult.success({
          CFConstants.http.headerLastModified: lastModified ?? 'unchanged',
          CFConstants.http.headerEtag: etag ?? 'unchanged',
        });
      }

      // Handle 200 OK with headers
      if (resp.statusCode == 200) {
        final headers = resp.headers;
        final resultHeaders = {
          CFConstants.http.headerLastModified:
              headers.value('Last-Modified') ?? '',
          CFConstants.http.headerEtag: headers.value('ETag') ?? '',
        };
        Logger.d('GET METADATA SUCCESSFUL: $resultHeaders');
        return CFResult.success(resultHeaders);
      } else {
        final msg = 'Failed to fetch metadata from $url: ${resp.statusCode}';
        Logger.w('GET METADATA FAILED: $msg');
        ErrorHandler.handleError(msg,
            source: _source,
            category: ErrorCategory.network,
            severity: ErrorSeverity.medium);
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      Logger.e('GET METADATA FAILED: ${e.toString()}');
      ErrorHandler.handleException(e, 'Error fetching metadata from $url',
          source: _source, severity: ErrorSeverity.high);
      return CFResult.error('Network error fetching metadata from $url',
          exception: e, category: ErrorCategory.network);
    }
  }

  /// GET request for a JSON object
  Future<CFResult<Map<String, dynamic>>> fetchJson(String url) async {
    try {
      Logger.d('EXECUTING GET JSON REQUEST');
      final resp = await _dio.get(url);
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map<String, dynamic>) {
          Logger.d('GET JSON SUCCESSFUL');
          return CFResult.success(data);
        } else {
          final message = 'Parsed JSON from $url is not an object';
          Logger.w('GET JSON FAILED: $message');
          ErrorHandler.handleError(message,
              source: _source,
              category: ErrorCategory.serialization,
              severity: ErrorSeverity.medium);
          return CFResult.error(message, category: ErrorCategory.serialization);
        }
      } else {
        final message = 'Failed to fetch JSON from $url: ${resp.statusCode}';
        Logger.w('GET JSON FAILED: $message');
        ErrorHandler.handleError(message,
            source: _source,
            category: ErrorCategory.network,
            severity: ErrorSeverity.high);
        return CFResult.error(message,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      Logger.e('GET JSON FAILED: ${e.toString()}');
      ErrorHandler.handleException(e, 'Error fetching JSON from $url',
          source: _source, severity: ErrorSeverity.high);
      return CFResult.error('Network error fetching JSON from $url',
          exception: e, category: ErrorCategory.network);
    }
  }

  /// POST raw JSON string
  Future<CFResult<bool>> postJson(String url, String payload) async {
    try {
      Logger.d('EXECUTING POST JSON REQUEST');

      // Log the request details based on endpoint type
      if (url.contains("summary")) {
        Logger.i('📊 SUMMARY HTTP: POST request');
      } else if (url.contains("events") || url.contains("cfe")) {
        Logger.i('🔔 TRACK HTTP: POST request to event API');
        Logger.i('🔔 TRACK HTTP: Request body size: ${payload.length} bytes');
      }

      final resp = await _dio.post(
        url,
        data: payload,
        options: Options(headers: {
          CFConstants.http.headerContentType: CFConstants.http.contentTypeJson
        }),
      );

      if (resp.statusCode == 200 || resp.statusCode == 202) {
        // Log the response details based on endpoint type
        if (url.contains("summary")) {
          Logger.i('📊 SUMMARY HTTP: Response code: ${resp.statusCode}');
          Logger.i('📊 SUMMARY HTTP: Summary successfully sent to server');
        } else if (url.contains("events") || url.contains("cfe")) {
          Logger.i('🔔 TRACK HTTP: Response code: ${resp.statusCode}');
          Logger.i('🔔 TRACK HTTP: Events successfully sent to server');
        }

        Logger.d('POST JSON SUCCESSFUL');
        return CFResult.success(true);
      } else {
        final body = resp.data?.toString() ?? 'No error body';

        // Log the error details based on endpoint type
        if (url.contains("summary")) {
          Logger.w('📊 SUMMARY HTTP: Error code: ${resp.statusCode}');
          Logger.w('📊 SUMMARY HTTP: Error body: $body');
        } else if (url.contains("events") || url.contains("cfe")) {
          Logger.w('🔔 TRACK HTTP: Error code: ${resp.statusCode}');
          Logger.w('🔔 TRACK HTTP: Error body: $body');
        }

        // Use our error handling system
        final message = 'API error response: ${resp.statusCode}';
        Logger.w('POST JSON FAILED: $message - $body');
        ErrorHandler.handleError(
          '$message - $body',
          source: _source,
          category: ErrorCategory.network,
          severity: ErrorSeverity.high,
        );

        Logger.e('Error: $body');
        return CFResult.error(message,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      if (url.contains("summary")) {
        Logger.e('📊 SUMMARY HTTP: Exception: ${e.toString()}');
      } else if (url.contains("events") || url.contains("cfe")) {
        Logger.e('🔔 TRACK HTTP: Exception: ${e.toString()}');
      }

      Logger.e('POST JSON FAILED: ${e.toString()}');
      ErrorHandler.handleException(
        e,
        'Failed to read API response',
        source: _source,
        severity: ErrorSeverity.high,
      );
      return CFResult.error('Failed to read API response',
          exception: e, category: ErrorCategory.network);
    }
  }

  /// Generic POST with dynamic body & query
  Future<CFResult<dynamic>> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      Logger.d('EXECUTING POST REQUEST');

      // Determine if this is a tracking or summary request
      final bool isTracking = url.contains("events") || url.contains("cfe");
      final bool isSummary = url.contains("summary");

      if (isTracking) {
        Logger.i('🔔 TRACK HTTP: POST request');
        if (data != null) {
          Logger.i(
              '🔔 TRACK HTTP: Request body size: ${data.toString().length} bytes');
        }
      } else if (isSummary) {
        Logger.i('📊 SUMMARY HTTP: POST request');
      }

      final resp = await _dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      if (resp.statusCode == 200 || resp.statusCode == 202) {
        if (isTracking) {
          Logger.i('🔔 TRACK HTTP: Response code: ${resp.statusCode}');
          Logger.i('🔔 TRACK HTTP: Events successfully sent to server');
        } else if (isSummary) {
          Logger.i('📊 SUMMARY HTTP: Response code: ${resp.statusCode}');
          Logger.i('📊 SUMMARY HTTP: Summary successfully sent to server');
        }

        Logger.d('POST REQUEST SUCCESSFUL');
        return CFResult.success(resp.data);
      } else {
        final body = resp.data?.toString() ?? 'No error body';
        final msg = 'Error POST $url: ${resp.statusCode}';

        if (isTracking) {
          Logger.w('🔔 TRACK HTTP: Error code: ${resp.statusCode}');
          Logger.w('🔔 TRACK HTTP: Error body: $body');
        } else if (isSummary) {
          Logger.w('📊 SUMMARY HTTP: Error code: ${resp.statusCode}');
          Logger.w('📊 SUMMARY HTTP: Error body: $body');
        }

        ErrorHandler.handleError('$msg – $body',
            source: _source,
            category: ErrorCategory.network,
            severity: ErrorSeverity.high);
        Logger.e('Error: $body');
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      final bool isTracking = url.contains("events") || url.contains("cfe");
      final bool isSummary = url.contains("summary");

      if (isTracking) {
        Logger.e('🔔 TRACK HTTP: Exception: ${e.toString()}');
      } else if (isSummary) {
        Logger.e('📊 SUMMARY HTTP: Exception: ${e.toString()}');
      }

      ErrorHandler.handleException(e, 'Error POST $url',
          source: _source, severity: ErrorSeverity.high);
      return CFResult.error('Network error POST $url: ${e.toString()}',
          exception: e, category: ErrorCategory.network);
    }
  }

  /// HEAD request to efficiently check for metadata changes without downloading the full response body
  Future<CFResult<Response>> head(String url, {Options? options}) async {
    try {
      Logger.i('API POLL: HEAD request to $url');
      final headOptions = options ??
          Options(
            headers: {
              'Cache-Control': 'no-cache',
            },
          );

      Logger.d('EXECUTING HEAD REQUEST');

      final resp = await _dio.head(url, options: headOptions);

      if (resp.statusCode == 200) {
        // Extract headers
        final headers = resp.headers;

        // Log important headers for caching
        final lastModified = headers.value('Last-Modified');
        final etag = headers.value('ETag');

        Logger.i(
            'API POLL: HEAD request successful - Last-Modified: $lastModified, ETag: $etag');
        return CFResult.success(resp);
      } else {
        Logger.w('API POLL: HEAD request failed with code: ${resp.statusCode}');
        return CFResult.error(
            'HEAD request failed with code: ${resp.statusCode}',
            code: resp.statusCode ?? 0,
            category: ErrorCategory.network);
      }
    } catch (e) {
      Logger.e('API POLL: HEAD request exception: ${e.toString()}');
      return CFResult.error(
          'HEAD request failed with exception: ${e.toString()}',
          exception: e,
          category: ErrorCategory.network);
    }
  }
}
