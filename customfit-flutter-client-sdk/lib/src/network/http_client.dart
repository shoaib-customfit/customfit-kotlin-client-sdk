import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/core/cf_config.dart';
import '../core/error/cf_result.dart';
import '../core/error/error_category.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../constants/cf_constants.dart';

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
    debugPrint(
        'HttpClient initialized with connectTimeout=$_connectionTimeoutMs, readTimeout=$_readTimeoutMs');
  }

  /// Update connection timeout
  void updateConnectionTimeout(int timeoutMs) {
    if (timeoutMs <= 0) throw ArgumentError('Timeout must be > 0');
    _connectionTimeoutMs = timeoutMs;
    _dio.options.connectTimeout = Duration(milliseconds: timeoutMs);
    debugPrint('Updated connection timeout to $timeoutMs ms');
  }

  /// Update read timeout
  void updateReadTimeout(int timeoutMs) {
    if (timeoutMs <= 0) throw ArgumentError('Timeout must be > 0');
    _readTimeoutMs = timeoutMs;
    _dio.options.receiveTimeout = Duration(milliseconds: timeoutMs);
    debugPrint('Updated read timeout to $timeoutMs ms');
  }

  /// HEAD request for metadata (Last-Modified, ETag)
  Future<CFResult<Map<String, String>>> fetchMetadata(String url) async {
    try {
      debugPrint('HEAD $url');
      final resp = await _dio.head(url);
      if (resp.statusCode == 200) {
        final headers = resp.headers;
        return CFResult.success({
          CFConstants.http.headerLastModified:
              headers.value('Last-Modified') ?? '',
          CFConstants.http.headerEtag: headers.value('ETag') ?? '',
        });
      } else {
        final msg = 'Failed HEAD $url: ${resp.statusCode}';
        ErrorHandler.handleError(msg,
            source: _SOURCE,
            category: ErrorCategory.network,
            severity: ErrorSeverity.medium);
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      ErrorHandler.handleException(e, 'Error HEAD $url',
          source: _SOURCE, severity: ErrorSeverity.high);
      return CFResult.error('Network error HEAD $url: ${e.toString()}',
          exception: e, category: ErrorCategory.network);
    }
  }

  /// GET request for a JSON object
  Future<CFResult<Map<String, dynamic>>> fetchJson(String url) async {
    try {
      debugPrint('GET $url');
      final resp = await _dio.get(url);
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map<String, dynamic>) {
          return CFResult.success(data);
        } else {
          final msg = 'GET $url JSON not object';
          ErrorHandler.handleError(msg,
              source: _SOURCE,
              category: ErrorCategory.serialization,
              severity: ErrorSeverity.medium);
          return CFResult.error(msg, category: ErrorCategory.serialization);
        }
      } else {
        final msg = 'Failed GET $url: ${resp.statusCode}';
        ErrorHandler.handleError(msg,
            source: _SOURCE,
            category: ErrorCategory.network,
            severity: ErrorSeverity.high);
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
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
      debugPrint('POST $url');
      final resp = await _dio.post(
        url,
        data: payload,
        options: Options(headers: {
          CFConstants.http.headerContentType: CFConstants.http.contentTypeJson
        }),
      );
      debugPrint(sep);
      debugPrint('Status: ${resp.statusCode}');
      if (resp.statusCode == 200 || resp.statusCode == 202) {
        debugPrint(resp.data.toString());
        return CFResult.success(true);
      } else {
        final body = resp.data?.toString() ?? 'No error body';
        final msg = 'Error POST $url: ${resp.statusCode}';
        ErrorHandler.handleError('$msg – $body',
            source: _SOURCE,
            category: ErrorCategory.network,
            severity: ErrorSeverity.high);
        debugPrint('Error: $body');
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      ErrorHandler.handleException(e, 'Error POST $url',
          source: _SOURCE, severity: ErrorSeverity.high);
      return CFResult.error('Network error POST $url: ${e.toString()}',
          exception: e, category: ErrorCategory.network);
    } finally {
      debugPrint(sep);
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
      debugPrint('POST $url');
      final resp = await _dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options ??
            Options(headers: {
              CFConstants.http.headerContentType:
                  CFConstants.http.contentTypeJson
            }),
      );
      debugPrint(sep);
      debugPrint('Status: ${resp.statusCode}');
      if (resp.statusCode == 200 || resp.statusCode == 202) {
        debugPrint(resp.data.toString());
        return CFResult.success(resp.data);
      } else {
        final body = resp.data?.toString() ?? 'No error body';
        final msg = 'Error POST $url: ${resp.statusCode}';
        ErrorHandler.handleError('$msg – $body',
            source: _SOURCE,
            category: ErrorCategory.network,
            severity: ErrorSeverity.high);
        return CFResult.error(msg,
            code: resp.statusCode ?? 0, category: ErrorCategory.network);
      }
    } catch (e) {
      ErrorHandler.handleException(e, 'Error POST $url',
          source: _SOURCE, severity: ErrorSeverity.high);
      return CFResult.error('Network error POST $url: ${e.toString()}',
          exception: e, category: ErrorCategory.network);
    } finally {
      debugPrint(sep);
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
