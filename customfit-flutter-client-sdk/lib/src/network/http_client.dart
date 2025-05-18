import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/core/cf_config.dart';
import '../core/error/cf_result.dart';
import '../core/error/error_category.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../constants/cf_constants.dart';
import '../core/logging/logger.dart';

/// HTTP client implementation mirroring Kotlin's HttpClient
class HttpClient {
  // ignore: unused_field
  final CFConfig _config;
  late final Dio _dio;
  int _connectionTimeoutMs;
  int _readTimeoutMs;

  static const String _SOURCE = 'HttpClient';

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
        CFConstants.http.headerContentType: CFConstants.http.contentTypeJson
      },
    ));

    // Add custom interceptor for full request/response/error logging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          Logger.d('==== CF API REQUEST ====');
          Logger.d('URL: ${options.uri}');
          Logger.d('Method: ${options.method}');
          Logger.d('Headers: ${options.headers}');
          Logger.d('Payload: ${options.data}');
          Logger.d('=======================');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          Logger.d('==== CF API RESPONSE ====');
          Logger.d('Status: ${response.statusCode}');
          Logger.d('Data: ${response.data}');
          Logger.d('========================');
          return handler.next(response);
        },
        onError: (DioError e, handler) {
          Logger.e('==== CF API ERROR ====');
          Logger.e('URL: ${e.requestOptions.uri}');
          Logger.e('Error: ${e.error}');
          Logger.e('Response: ${e.response}');
          Logger.e('======================');
          return handler.next(e);
        },
      ),
    );

    // Add logging interceptor
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
      logPrint: (log) => Logger.d('HTTP: $log'),
    ));

    Logger.i(
        'HttpClient initialized with connectTimeout=$_connectionTimeoutMs ms, readTimeout=$_readTimeoutMs ms');
  }

  /// Update connection timeout
  void updateConnectionTimeout(int timeoutMs) {
    if (timeoutMs <= 0) throw ArgumentError('Timeout must be > 0');
    _connectionTimeoutMs = timeoutMs;
    _dio.options.connectTimeout = Duration(milliseconds: timeoutMs);
    Logger.i('Updated connection timeout to $timeoutMs ms');
  }

  /// Update read timeout
  void updateReadTimeout(int timeoutMs) {
    if (timeoutMs <= 0) throw ArgumentError('Timeout must be > 0');
    _readTimeoutMs = timeoutMs;
    _dio.options.receiveTimeout = Duration(milliseconds: timeoutMs);
    Logger.i('Updated read timeout to $timeoutMs ms');
  }

  /// GET request for metadata (Last-Modified, ETag)
  Future<CFResult<Map<String, String>>> fetchMetadata(String url,
      {String? lastModified, String? etag}) async {
    try {
      Logger.i('GET $url for metadata');

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
        Logger.d('Using If-Modified-Since: $lastModified');
      }

      if (etag != null && etag.isNotEmpty && etag != 'unchanged') {
        headers['If-None-Match'] = etag;
        Logger.d('Using If-None-Match: $etag');
      }

      final options = Options(
        headers: headers,
        // Set validateStatus to accept 304 Not Modified responses
        validateStatus: (status) =>
            status != null && (status >= 200 && status < 300 || status == 304),
      );

      Logger.d('🔎 API HTTP: GET metadata for $url');
      final resp = await _dio.get(url, options: options);

      // Handle 304 Not Modified (return the same headers)
      if (resp.statusCode == 304) {
        Logger.i('🔎 API HTTP: Metadata unchanged (304 Not Modified)');
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
        Logger.i('🔎 API HTTP: Got metadata headers: $resultHeaders');
        return CFResult.success(resultHeaders);
      } else {
        final msg = 'Failed GET metadata $url: ${resp.statusCode}';
        Logger.w('🔎 API HTTP: $msg');
        ErrorHandler.handleError(msg,
            source: _SOURCE,
            category: ErrorCategory.network,
            severity: ErrorSeverity.medium);
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      final errorMsg = 'Error GET metadata $url: ${e.toString()}';
      Logger.e('🔎 API HTTP: $errorMsg');
      ErrorHandler.handleException(e, errorMsg,
          source: _SOURCE, severity: ErrorSeverity.high);
      return CFResult.error(errorMsg,
          exception: e, category: ErrorCategory.network);
    }
  }

  /// GET request for a JSON object
  Future<CFResult<Map<String, dynamic>>> fetchJson(String url) async {
    try {
      Logger.i('GET $url');
      final resp = await _dio.get(url);
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map<String, dynamic>) {
          Logger.i('🔎 API HTTP: Successfully fetched JSON from $url');
          return CFResult.success(data);
        } else {
          final msg = 'GET $url JSON not object';
          Logger.w('🔎 API HTTP: $msg - Response data is not a JSON object');
          ErrorHandler.handleError(msg,
              source: _SOURCE,
              category: ErrorCategory.serialization,
              severity: ErrorSeverity.medium);
          return CFResult.error(msg, category: ErrorCategory.serialization);
        }
      } else {
        final msg = 'Failed GET $url: ${resp.statusCode}';
        Logger.w('🔎 API HTTP: $msg');
        ErrorHandler.handleError(msg,
            source: _SOURCE,
            category: ErrorCategory.network,
            severity: ErrorSeverity.high);
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      Logger.e('🔎 API HTTP: Error GET $url: ${e.toString()}');
      ErrorHandler.handleException(e, 'Error GET $url',
          source: _SOURCE, severity: ErrorSeverity.high);
      return CFResult.error('Network error GET $url: ${e.toString()}',
          exception: e, category: ErrorCategory.network);
    }
  }

  /// POST raw JSON string
  Future<CFResult<bool>> postJson(String url, String payload) async {
    const sep = '===== API RESPONSE =====';
    try {
      Logger.i('POST $url');

      // Log payload size
      Logger.i('POST request payload size: ${payload.length} bytes');

      // Log based on endpoint type
      if (url.contains("summary")) {
        Logger.i('📊 SUMMARY HTTP: POST request');
      } else if (url.contains("cfe") || url.contains("events")) {
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

      Logger.d(sep);
      Logger.d('Status: ${resp.statusCode}');

      if (resp.statusCode == 200 || resp.statusCode == 202) {
        // Log based on endpoint type
        if (url.contains("summary")) {
          Logger.i('📊 SUMMARY HTTP: Response code: ${resp.statusCode}');
          Logger.i('📊 SUMMARY HTTP: Summary successfully sent to server');
        } else if (url.contains("cfe") || url.contains("events")) {
          Logger.i('🔔 TRACK HTTP: Response code: ${resp.statusCode}');
          Logger.i('🔔 TRACK HTTP: Events successfully sent to server');
        }

        Logger.d(resp.data.toString());
        return CFResult.success(true);
      } else {
        final body = resp.data?.toString() ?? 'No error body';
        final msg = 'Error POST $url: ${resp.statusCode}';

        // Log based on endpoint type
        if (url.contains("summary")) {
          Logger.w('📊 SUMMARY HTTP: Error code: ${resp.statusCode}');
          Logger.w('📊 SUMMARY HTTP: Error body: $body');
        } else if (url.contains("cfe") || url.contains("events")) {
          Logger.w('🔔 TRACK HTTP: Error code: ${resp.statusCode}');
          Logger.w('🔔 TRACK HTTP: Error body: $body');
        }

        ErrorHandler.handleError('$msg – $body',
            source: _SOURCE,
            category: ErrorCategory.network,
            severity: ErrorSeverity.high);
        Logger.e('Error: $body');
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      // Log based on endpoint type
      if (url.contains("summary")) {
        Logger.e('📊 SUMMARY HTTP: Exception: ${e.toString()}');
      } else if (url.contains("cfe") || url.contains("events")) {
        Logger.e('🔔 TRACK HTTP: Exception: ${e.toString()}');
      }

      ErrorHandler.handleException(e, 'Error POST $url',
          source: _SOURCE, severity: ErrorSeverity.high);
      return CFResult.error('Network error POST $url: ${e.toString()}',
          exception: e, category: ErrorCategory.network);
    } finally {
      Logger.d(sep);
    }
  }

  /// Generic POST with dynamic body & query
  Future<CFResult<dynamic>> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    const sep = '===== API RESPONSE =====';
    try {
      Logger.i('POST $url');

      // Determine if this is a tracking or summary request
      bool isTracking = url.contains("events") || url.contains("cfe");
      bool isSummary = url.contains("summary");

      if (isTracking) {
        Logger.i('🔔 TRACK HTTP: POST request to: $url');
        if (data != null) {
          Logger.i(
              '🔔 TRACK HTTP: Request body size: ${data.toString().length} bytes');
        }
      } else if (isSummary) {
        Logger.i('📊 SUMMARY HTTP: POST request to: $url');
      }

      final resp = await _dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      Logger.d(sep);
      Logger.d('Status: ${resp.statusCode}');

      if (resp.statusCode == 200 || resp.statusCode == 202) {
        if (isTracking) {
          Logger.i('🔔 TRACK HTTP: Response code: ${resp.statusCode}');
          Logger.i('🔔 TRACK HTTP: Events successfully sent to server');
        } else if (isSummary) {
          Logger.i('📊 SUMMARY HTTP: Response code: ${resp.statusCode}');
          Logger.i('📊 SUMMARY HTTP: Summary successfully sent to server');
        }

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
            source: _SOURCE,
            category: ErrorCategory.network,
            severity: ErrorSeverity.high);
        Logger.e('Error: $body');
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      bool isTracking = url.contains("events") || url.contains("cfe");
      bool isSummary = url.contains("summary");

      if (isTracking) {
        Logger.e('🔔 TRACK HTTP: Exception: ${e.toString()}');
      } else if (isSummary) {
        Logger.e('📊 SUMMARY HTTP: Exception: ${e.toString()}');
      }

      ErrorHandler.handleException(e, 'Error POST $url',
          source: _SOURCE, severity: ErrorSeverity.high);
      return CFResult.error('Network error POST $url: ${e.toString()}',
          exception: e, category: ErrorCategory.network);
    } finally {
      Logger.d(sep);
    }
  }

  /// HEAD wrapper returning raw Dio Response
  Future<CFResult<Response>> head(String url, {Options? options}) async {
    try {
      debugPrint('HEAD $url');
      final resp = await _dio.head(url, options: options);
      return CFResult.success(resp);
    } catch (e) {
      ErrorHandler.handleException(e, 'Error HEAD $url',
          source: _SOURCE, severity: ErrorSeverity.high);
      return CFResult.error('Network error HEAD $url: ${e.toString()}',
          exception: e, category: ErrorCategory.network);
    }
  }
}
