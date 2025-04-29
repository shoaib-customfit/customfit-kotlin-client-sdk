# CustomFit Flutter SDK: Low-Level Design (LLD) - Part 3

## 3. Networking Components

### 3.1 lib/src/network/http_client.dart

**Purpose**: HTTP client implementation for API requests.

**Implementation Details**:
```dart
class HttpClient {
  // Dio HTTP client
  late final Dio _dio;
  
  // Configuration
  final CFConfig _config;
  
  // Network timeouts with atomic updates
  int _connectionTimeoutMs;
  int _readTimeoutMs;
  
  // Constants
  static const String _source = "HttpClient";
  
  HttpClient(this._config) :
    _connectionTimeoutMs = _config.networkConnectionTimeoutMs,
    _readTimeoutMs = _config.networkReadTimeoutMs {
    _initializeDio();
  }
  
  // Initialize Dio with configuration
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: _connectionTimeoutMs),
      receiveTimeout: Duration(milliseconds: _readTimeoutMs),
      headers: {'Content-Type': 'application/json'},
    ));
    
    // Add logging interceptor
    if (_config.debugLoggingEnabled) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (log) => Logger.d("HTTP: $log"),
      ));
    }
    
    Logger.d("HttpClient initialized with connectionTimeoutMs=$_connectionTimeoutMs, readTimeoutMs=$_readTimeoutMs");
  }
  
  // Update connection timeout
  void updateConnectionTimeout(int timeoutMs) {
    if (timeoutMs <= 0) {
      throw ArgumentError("Timeout must be greater than 0");
    }
    _connectionTimeoutMs = timeoutMs;
    _dio.options.connectTimeout = Duration(milliseconds: timeoutMs);
    Logger.d("Updated connection timeout to $timeoutMs ms");
  }
  
  // Update read timeout
  void updateReadTimeout(int timeoutMs) {
    if (timeoutMs <= 0) {
      throw ArgumentError("Timeout must be greater than 0");
    }
    _readTimeoutMs = timeoutMs;
    _dio.options.receiveTimeout = Duration(milliseconds: timeoutMs);
    Logger.d("Updated read timeout to $timeoutMs ms");
  }
  
  // GET request with error handling
  Future<CFResult<T>> get<T>(String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.get<T>(
        url,
        queryParameters: queryParameters,
        options: headers != null ? Options(headers: headers) : null,
      );
      
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e, "GET", url);
    }
  }
  
  // POST request with error handling
  Future<CFResult<T>> post<T>(String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.post<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: headers != null ? Options(headers: headers) : null,
      );
      
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e, "POST", url);
    }
  }
  
  // Handle successful response
  CFResult<T> _handleResponse<T>(Response<T> response) {
    if (response.statusCode == null) {
      return CFResult.error(
        "Null status code in response",
        category: ErrorCategory.network
      );
    }
    
    if (response.statusCode! >= 200 && response.statusCode! < 300) {
      return CFResult.success(response.data as T);
    } else {
      final message = "Request failed with status code ${response.statusCode}";
      ErrorHandler.handleError(
        message,
        _source,
        ErrorCategory.network,
        ErrorSeverity.medium
      );
      return CFResult.error(
        message,
        category: ErrorCategory.network
      );
    }
  }
  
  // Handle error
  CFResult<T> _handleError<T>(dynamic error, String method, String url) {
    if (error is DioError) {
      // Handle Dio specific errors
      final dioError = error;
      final errorMessage = "Failed to $method $url: ${dioError.message}";
      final errorType = _getDioErrorCategory(dioError);
      final errorSeverity = _getDioErrorSeverity(dioError);
      
      ErrorHandler.handleError(
        errorMessage,
        _source,
        errorType,
        errorSeverity
      );
      
      return CFResult.error(
        errorMessage,
        exception: dioError,
        category: errorType
      );
    } else {
      // Handle generic errors
      final errorMessage = "Unexpected error during $method $url: $error";
      ErrorHandler.handleException(
        error,
        errorMessage,
        _source,
        ErrorSeverity.high
      );
      
      return CFResult.error(
        errorMessage,
        exception: error,
        category: ErrorCategory.unknown
      );
    }
  }
  
  // Map Dio error to CF error category
  ErrorCategory _getDioErrorCategory(DioError error) {
    switch (error.type) {
      case DioErrorType.connectionTimeout:
      case DioErrorType.sendTimeout:
      case DioErrorType.receiveTimeout:
        return ErrorCategory.timeout;
      case DioErrorType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return ErrorCategory.permission;
        } else if (statusCode == 400 || statusCode == 422) {
          return ErrorCategory.validation;
        } else {
          return ErrorCategory.network;
        }
      case DioErrorType.cancel:
        return ErrorCategory.internal;
      case DioErrorType.connectionError:
        return ErrorCategory.network;
      default:
        return ErrorCategory.unknown;
    }
  }
  
  // Map Dio error to CF error severity
  ErrorSeverity _getDioErrorSeverity(DioError error) {
    switch (error.type) {
      case DioErrorType.connectionTimeout:
      case DioErrorType.sendTimeout:
      case DioErrorType.receiveTimeout:
        return ErrorSeverity.medium;
      case DioErrorType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 500 || statusCode == 503) {
          return ErrorSeverity.high;
        } else {
          return ErrorSeverity.medium;
        }
      case DioErrorType.cancel:
        return ErrorSeverity.low;
      case DioErrorType.connectionError:
        return ErrorSeverity.high;
      default:
        return ErrorSeverity.medium;
    }
  }
  
  // Fetch JSON from URL
  Future<Map<String, dynamic>?> fetchJson(String url) async {
    try {
      final result = await get<Map<String, dynamic>>(url);
      return result.fold(
        onSuccess: (data) => data,
        onError: (error) {
          Logger.w("Failed to fetch JSON from $url: ${error.message}");
          return null;
        }
      );
    } catch (e) {
      Logger.e("Unexpected error fetching JSON from $url: $e");
      return null;
    }
  }
  
  // Fetch metadata (headers)
  Future<CFResult<Map<String, String>>> fetchMetadata(String url) async {
    try {
      final response = await _dio.head(url);
      final headers = response.headers.map;
      final metadata = <String, String>{};
      headers.forEach((key, values) {
        if (values.isNotEmpty) {
          metadata[key] = values.first;
        }
      });
      return CFResult.success(metadata);
    } catch (e) {
      return _handleError(e, "HEAD", url);
    }
  }
}
```

**Key Functions**:
- HTTP request handling with Dio
- Error handling and categorization
- Configurable timeouts
- JSON fetching utilities
- Metadata (headers) retrieval

### 3.2 lib/src/network/config_fetcher.dart

**Purpose**: Fetches feature flags and configuration from the server.

**Implementation Details**:
```dart
class ConfigFetcher {
  final HttpClient _httpClient;
  final CFConfig _config;
  final CFUser _user;
  
  // Track offline mode
  bool _offlineMode = false;
  
  // Constants
  static const String _source = "ConfigFetcher";
  
  ConfigFetcher(this._httpClient, this._config, this._user) {
    _offlineMode = _config.offlineMode;
  }
  
  // Set offline mode
  void setOffline(bool offline) {
    _offlineMode = offline;
    Logger.d("ConfigFetcher offline mode set to: $offline");
  }
  
  // Fetch user configurations
  Future<CFResult<Map<String, dynamic>>> fetchUserConfigs() async {
    // Respect offline mode
    if (_offlineMode) {
      return CFResult.error(
        "Cannot fetch user configs in offline mode",
        category: ErrorCategory.network
      );
    }
    
    try {
      // Build request URL
      final url = "${CFConstants.api.baseApiUrl}${CFConstants.api.userConfigsPath}";
      
      // Build query parameters
      final params = <String, dynamic>{
        'user_id': _user.userId,
        'dimension_id': _config.dimensionId,
      };
      
      // Add device context if available
      if (_user.deviceContext != null) {
        params['device_context'] = jsonEncode(_user.deviceContext!.toJson());
      }
      
      // Add application info if available
      if (_user.applicationInfo != null) {
        params['app_info'] = jsonEncode(_user.applicationInfo!.toJson());
      }
      
      // Make request
      final result = await _httpClient.get<Map<String, dynamic>>(
        url,
        queryParameters: params
      );
      
      return result.fold(
        onSuccess: (data) {
          Logger.i("Successfully fetched user configs");
          return CFResult.success(data);
        },
        onError: (error) {
          return CFResult.error(
            "Failed to fetch user configs: ${error.message}",
            exception: error.exception,
            category: error.category
          );
        }
      );
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Unexpected error fetching user configs",
        _source,
        ErrorSeverity.high
      );
      return CFResult.error(
        "Failed to fetch user configs",
        exception: e,
        category: ErrorCategory.internal
      );
    }
  }
  
  // Fetch SDK settings
  Future<CFResult<SdkSettings>> fetchSdkSettings() async {
    // Respect offline mode
    if (_offlineMode) {
      return CFResult.error(
        "Cannot fetch SDK settings in offline mode",
        category: ErrorCategory.network
      );
    }
    
    try {
      // Build request URL with dimension ID
      final dimensionId = _config.dimensionId;
      if (dimensionId == null) {
        return CFResult.error(
          "Failed to extract dimension ID from client key",
          category: ErrorCategory.validation
        );
      }
      
      final url = "${CFConstants.api.sdkSettingsBaseUrl}${String.format(CFConstants.api.sdkSettingsPathPattern, dimensionId)}";
      
      // Make request
      final result = await _httpClient.get<Map<String, dynamic>>(url);
      
      return result.fold(
        onSuccess: (data) {
          try {
            final settings = SdkSettings.fromJson(data);
            return CFResult.success(settings);
          } catch (e) {
            ErrorHandler.handleException(
              e,
              "Failed to parse SDK settings",
              _source,
              ErrorSeverity.high
            );
            return CFResult.error(
              "Failed to parse SDK settings",
              exception: e,
              category: ErrorCategory.serialization
            );
          }
        },
        onError: (error) {
          return CFResult.error(
            "Failed to fetch SDK settings: ${error.message}",
            exception: error.exception,
            category: error.category
          );
        }
      );
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Unexpected error fetching SDK settings",
        _source,
        ErrorSeverity.high
      );
      return CFResult.error(
        "Failed to fetch SDK settings",
        exception: e,
        category: ErrorCategory.internal
      );
    }
  }
}
```

**Key Functions**:
- Fetch user-specific configurations
- Fetch SDK settings
- Handle offline mode
- Serialize user context for requests

### 3.3 lib/src/network/connection/connection_manager.dart

**Purpose**: Manages and monitors network connectivity.

**Implementation Details**:
```dart
class ConnectionManager {
  // Current connection status
  ConnectionStatus _status = ConnectionStatus.connecting;
  
  // Connection information
  ConnectionInformation _connectionInfo;
  
  // Connectivity plugin
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Listeners
  final List<ConnectionStatusListener> _listeners = [];
  
  // Configuration
  final CFConfig _config;
  
  // Callback when connectivity changes
  final Function? _onConnectivityChanged;
  
  // Monitor state
  bool _initialized = false;
  bool _offlineMode = false;
  int _failureCount = 0;
  int _lastConnectionAttemptMs = 0;
  int _lastSuccessfulConnectionMs = 0;
  String? _lastError;
  
  // Constants
  static const String _source = "ConnectionManager";
  
  ConnectionManager(this._config, [this._onConnectivityChanged]) :
    _connectionInfo = ConnectionInformation(
      status: ConnectionStatus.connecting,
      isOfflineMode: _config.offlineMode,
    ) {
    _offlineMode = _config.offlineMode;
    _initializeConnectivity();
  }
  
  // Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    if (_initialized) return;
    
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _handleConnectivityResult(result);
      
      // Listen for changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityResult);
      
      _initialized = true;
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to initialize connectivity monitoring",
        _source,
        ErrorSeverity.medium
      );
      
      // Default to connected if we can't determine
      _updateConnectionStatus(ConnectionStatus.connected);
    }
  }
  
  // Handle connectivity result
  void _handleConnectivityResult(ConnectivityResult result) {
    if (_offlineMode) {
      _updateConnectionStatus(ConnectionStatus.offline);
      return;
    }
    
    switch (result) {
      case ConnectivityResult.none:
        _updateConnectionStatus(ConnectionStatus.disconnected);
        break;
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
        _updateConnectionStatus(ConnectionStatus.connected);
        break;
      default:
        // For other types (bluetooth, vpn, etc.), assume connected
        _updateConnectionStatus(ConnectionStatus.connected);
        break;
    }
  }
  
  // Update connection status
  void _updateConnectionStatus(ConnectionStatus newStatus) {
    if (_status == newStatus) return;
    
    _status = newStatus;
    
    // Update connection information
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (newStatus == ConnectionStatus.connected) {
      // Reset failure count on successful connection
      _failureCount = 0;
      _lastSuccessfulConnectionMs = now;
    } else if (newStatus == ConnectionStatus.disconnected) {
      // Increment failure count on disconnection
      _failureCount++;
    }
    
    _lastConnectionAttemptMs = now;
    
    _connectionInfo = ConnectionInformation(
      status: newStatus,
      isOfflineMode: _offlineMode,
      lastError: _lastError,
      lastSuccessfulConnectionTimeMs: _lastSuccessfulConnectionMs,
      failureCount: _failureCount,
      nextReconnectTimeMs: _calculateNextReconnectTime(),
    );
    
    // Notify listeners
    _notifyListeners();
    
    // Execute callback if provided
    if (_onConnectivityChanged != null && newStatus == ConnectionStatus.connected) {
      _onConnectivityChanged!();
    }
  }
  
  // Calculate next reconnect time based on backoff
  int _calculateNextReconnectTime() {
    if (_status == ConnectionStatus.connected || _status == ConnectionStatus.offline) {
      return 0;
    }
    
    // Use backoff strategy for reconnection attempts
    final backoffMs = min(
      _config.retryInitialDelayMs * pow(_config.retryBackoffMultiplier, _failureCount),
      _config.retryMaxDelayMs
    ).toInt();
    
    return _lastConnectionAttemptMs + backoffMs;
  }
  
  // Notify all listeners of connection status change
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener.onConnectionStatusChanged(_status, _connectionInfo);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying connection status listener",
          _source,
          ErrorSeverity.low
        );
      }
    }
  }
  
  // Add listener
  void addConnectionStatusListener(ConnectionStatusListener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      
      // Immediately notify with current status
      try {
        listener.onConnectionStatusChanged(_status, _connectionInfo);
      } catch (e) {
        ErrorHandler.handleException(
          e,
          "Error notifying new connection status listener",
          _source,
          ErrorSeverity.low
        );
      }
    }
  }
  
  // Remove listener
  void removeConnectionStatusListener(ConnectionStatusListener listener) {
    _listeners.remove(listener);
  }
  
  // Set offline mode
  void setOfflineMode(bool offline) {
    if (_offlineMode == offline) return;
    
    _offlineMode = offline;
    
    if (offline) {
      _updateConnectionStatus(ConnectionStatus.offline);
    } else {
      // When coming back online, check connectivity
      _connectivity.checkConnectivity().then(_handleConnectivityResult);
    }
  }
  
  // Get current connection status
  ConnectionStatus getConnectionStatus() => _status;
  
  // Get current connection information
  ConnectionInformation getConnectionInformation() => _connectionInfo;
  
  // Record connection failure
  void recordConnectionFailure(String error) {
    _lastError = error;
    _failureCount++;
    
    // Update connection info
    _connectionInfo = ConnectionInformation(
      status: _status,
      isOfflineMode: _offlineMode,
      lastError: _lastError,
      lastSuccessfulConnectionTimeMs: _lastSuccessfulConnectionMs,
      failureCount: _failureCount,
      nextReconnectTimeMs: _calculateNextReconnectTime(),
    );
    
    // Notify listeners
    _notifyListeners();
  }
  
  // Record connection success
  void recordConnectionSuccess() {
    if (_failureCount > 0) {
      _failureCount = 0;
      _lastError = null;
      _lastSuccessfulConnectionMs = DateTime.now().millisecondsSinceEpoch;
      
      // Update connection info
      _connectionInfo = ConnectionInformation(
        status: _status,
        isOfflineMode: _offlineMode,
        lastError: _lastError,
        lastSuccessfulConnectionTimeMs: _lastSuccessfulConnectionMs,
        failureCount: _failureCount,
        nextReconnectTimeMs: _calculateNextReconnectTime(),
      );
      
      // Notify listeners
      _notifyListeners();
    }
  }
  
  // Clean up resources
  void shutdown() {
    _connectivitySubscription?.cancel();
    _listeners.clear();
  }
}

// Connection status listener interface
abstract class ConnectionStatusListener {
  void onConnectionStatusChanged(ConnectionStatus newStatus, ConnectionInformation info);
}
```

**Key Functions**:
- Monitor network connectivity changes
- Manage offline mode
- Notify listeners of connection state changes
- Track connection failures and successes
- Implement backoff strategy for reconnection

### 3.4 lib/src/network/connection/connection_status.dart

**Purpose**: Enumerate possible connection states.

**Implementation Details**:
```dart
enum ConnectionStatus {
  /// SDK is connected and can communicate with the server
  connected,

  /// SDK is currently in the process of connecting or reconnecting
  connecting,

  /// SDK is disconnected from the server due to network issues
  disconnected,

  /// SDK is intentionally in offline mode
  offline
}
```

**Key Functions**:
- Define connection state enum

### 3.5 lib/src/network/connection/connection_information.dart

**Purpose**: Store detailed information about the connection state.

**Implementation Details**:
```dart
class ConnectionInformation {
  /// The current connection status
  final ConnectionStatus status;

  /// When true, indicates the SDK was put in offline mode intentionally
  final bool isOfflineMode;

  /// Last connection error message, if any
  final String? lastError;

  /// Timestamp of the last successful connection in milliseconds
  final int lastSuccessfulConnectionTimeMs;

  /// Number of consecutive connection failures
  final int failureCount;

  /// Time of the next reconnection attempt in milliseconds
  final int nextReconnectTimeMs;

  ConnectionInformation({
    required this.status,
    required this.isOfflineMode,
    this.lastError,
    this.lastSuccessfulConnectionTimeMs = 0,
    this.failureCount = 0,
    this.nextReconnectTimeMs = 0,
  });

  @override
  String toString() => 'ConnectionInformation(status: $status, '
      'isOfflineMode: $isOfflineMode, lastError: $lastError, '
      'lastSuccessfulConnectionTimeMs: $lastSuccessfulConnectionTimeMs, '
      'failureCount: $failureCount, nextReconnectTimeMs: $nextReconnectTimeMs)';
}
```

**Key Functions**:
- Store connection status details
- Track connection history 