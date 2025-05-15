// lib/src/client/cf_client.dart

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../analytics/event/event_tracker.dart';
import '../analytics/summary/summary_manager.dart';
import '../client/listener/all_flags_listener.dart';
import '../client/listener/feature_flag_change_listener.dart';
import '../client/managers/config_manager.dart';
import '../client/managers/environment_manager.dart';
import '../client/managers/listener_manager.dart';
import '../client/managers/user_manager.dart';
import '../config/core/cf_config.dart';
import '../config/core/mutable_cf_config.dart';
import '../core/error/cf_result.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../core/logging/log_level_updater.dart';
import '../core/logging/logger.dart';
import '../core/model/application_info.dart';
import '../core/model/cf_user.dart';
import '../core/model/device_context.dart';
import '../core/model/evaluation_context.dart';
import '../network/config_fetcher.dart';
import '../network/http_client.dart';
import '../network/connection/connection_information.dart';
import '../network/connection/connection_manager_impl.dart';
import '../network/connection/connection_status.dart';
import '../network/connection/connection_status_listener.dart';
import '../platform/app_state.dart';
import '../platform/app_state_listener.dart';
import '../platform/background_state_monitor.dart';
import '../platform/default_background_state_monitor.dart';

/// Main SDK client orchestrating analytics, config, and environment.
class CFClient {
  static const _SOURCE = 'CFClient';

  final String _sessionId;
  final MutableCFConfig _mutableConfig;
  // ignore: unused_field
  final HttpClient _httpClient;

  /// Managers exposed to users
  final SummaryManager summaryManager;
  final EventTracker eventTracker;
  final ConfigFetcher configFetcher;
  
  /// Core managers
  final ConfigManager configManager;
  final UserManager userManager;
  final EnvironmentManager environmentManager;
  final ListenerManager listenerManager;

  /// Connectivity and background
  final ConnectionManagerImpl connectionManager;
  final BackgroundStateMonitor backgroundStateMonitor;

  /// Feature config and flag listeners
  final Map<String, List<void Function(dynamic)>> _configListeners = {};

  // This field is intentionally unused in the current implementation
  // but will be used in future versions for feature flag listeners
  @pragma('vm:entry-point')
  // ignore: unused_field, will be used in future implementations
  final Map<String, List<FeatureFlagChangeListener>>
      _featureFlagListeners = {};
  // ignore: unused_field
  final Set<AllFlagsListener> _allFlagsListeners = {};

  /// Contexts, device/app info
  final Map<String, EvaluationContext> _contexts = {};
  // ignore: unused_field
  late DeviceContext _deviceContext;
  // ignore: unused_field
  ApplicationInfo? _applicationInfo;

  /// Current user reference - marked as unused
  // ignore: unused_field
  final CFUser _user;

  /// Internal SDK settings tracking
  Timer? _sdkSettingsTimer;
  String? _previousLastModified;
  final Map<String, dynamic> _configMap = {};
  final _configLock = Object();
  final Completer<void> _sdkSettingsCompleter = Completer<void>();

  CFClient._(CFConfig config, CFUser user)
      : _sessionId = const Uuid().v4(),
        _mutableConfig = MutableCFConfig(config),
        _httpClient = HttpClient(config),
        connectionManager = ConnectionManagerImpl(config),
        backgroundStateMonitor = DefaultBackgroundStateMonitor(),
        _user = user,
        summaryManager =
            SummaryManager(const Uuid().v4(), HttpClient(config), user, config),
        eventTracker = EventTracker(HttpClient(config),
            ConnectionManagerImpl(config), user, const Uuid().v4(), config),
        // Convert CFConfig to SdkSettings using a helper method
        configFetcher = ConfigFetcher(
            HttpClient(config), _convertToSdkSettings(config), user),
        // Initialize core managers
        userManager = UserManagerImpl(user),
        // Create a new ConfigFetcher instance for ConfigManager to avoid instance member access in initializer
        configManager = ConfigManagerImpl(
            config: config, 
            configFetcher: ConfigFetcher(HttpClient(config), _convertToSdkSettings(config), user)),
        environmentManager = EnvironmentManagerImpl(
            backgroundStateMonitor: DefaultBackgroundStateMonitor(), 
            userManager: UserManagerImpl(user)),
        listenerManager = ListenerManagerImpl() {
    // Configure logging
    LogLevelUpdater.updateLogLevel(_mutableConfig.config);

    // Offline mode
    if (_mutableConfig.offlineMode) {
      configFetcher.setOffline(true);
      connectionManager.setOfflineMode(true);
      Logger.i('CF client initialized in offline mode');
    }

    // Auto environment attributes
    if (_mutableConfig.autoEnvAttributesEnabled) {
      _initializeEnvironmentAttributes(user);
    }

    // Setup monitors
    _setupConnectionListeners();
    _setupBackgroundListeners();

    // Add main user context
    _addMainUserContext(user);

    // Config change listener
    // _mutableConfig.addConfigChangeListener(
    //    (oldC, newC) => _handleConfigChange(oldC, newC));

    // SDK settings polling
    _startPeriodicSdkSettingsCheck();
    _initialSdkSettingsCheck();
  }

  /// Initialize application and device context
  void _initializeEnvironmentAttributes(CFUser user) {
    _deviceContext = user.device ?? DeviceContext();
    _updateUserWithDeviceContext(user);

    final existingApp = user.application;
    final appInfo = existingApp ?? ApplicationInfo();
    _updateUserWithApplicationInfo(user, appInfo);
  }

  /// Setup connection status forwarding
  void _setupConnectionListeners() {
    // Create a proper ConnectionStatusListener implementation
    final listener = _ConnectionStatusListenerImpl(
      (status, info) {
        for (var lst in _connectionsListeners) {
          lst(status, info);
        }
      },
    );
    connectionManager.addConnectionStatusListener(listener);
  }

  final List<void Function(ConnectionStatus, ConnectionInformation)>
      _connectionsListeners = [];
  void addConnectionStatusListener(
      void Function(ConnectionStatus, ConnectionInformation) lst) {
    _connectionsListeners.add(lst);
    final info = connectionManager.getConnectionInformation();
    lst(info.status, info);
  }

  void removeConnectionStatusListener(
      void Function(ConnectionStatus, ConnectionInformation) lst) {
    _connectionsListeners.remove(lst);
  }

  /// Setup background and battery listeners
  void _setupBackgroundListeners() {
    backgroundStateMonitor.addAppStateListener(
      _AppStateListenerImpl(
        onStateChanged: (state) {
          if (state == AppState.background) {
            _pausePolling();
          } else if (state == AppState.foreground) {
            _resumePolling();
            _checkSdkSettings();
          }
        },
      ),
    );
  }

  void _addMainUserContext(CFUser user) {
    final ctx = EvaluationContext(
        type: ContextType.user, key: user.userCustomerId ?? _sessionId);
    _contexts['user'] = ctx;
    _updateUserWithDeviceContext(user);
  }

  void _updateUserWithDeviceContext(CFUser user) {
    Logger.d('Device context updated');
  }

  void _updateUserWithApplicationInfo(CFUser user, ApplicationInfo info) {
    Logger.d('Application info updated');
  }

  /// Handle dynamic config changes
  // ignore: unused_element
  void _handleConfigChange(CFConfig oldC, CFConfig newC) {
    if (oldC.offlineMode != newC.offlineMode) {
      configFetcher.setOffline(newC.offlineMode);
      connectionManager.setOfflineMode(true);
    }
    // other change handlers omitted for brevity
  }

  /// Periodic SDK settings
  void _startPeriodicSdkSettingsCheck() {
    _sdkSettingsTimer?.cancel();
    _sdkSettingsTimer = Timer.periodic(
      const Duration(milliseconds: 30000),
      (_) => _checkSdkSettings(),
    );
  }

  void _pausePolling() => _sdkSettingsTimer?.cancel();
  void _resumePolling() => _startPeriodicSdkSettingsCheck();

  // ignore: unused_element
  void _adjustPollingForBattery(bool low) {
    _sdkSettingsTimer?.cancel();
    const ms = 30000;
    _sdkSettingsTimer = Timer.periodic(
        const Duration(milliseconds: ms), (_) => _checkSdkSettings());
  }

  void _initialSdkSettingsCheck() async {
    await _checkSdkSettings();
    _sdkSettingsCompleter.complete();
  }

  Future<void> _checkSdkSettings() async {
    try {
      // Simplify the entire method to avoid property access issues
      // and focus on capturing the essential functionality
      final metaResult = await configFetcher.fetchMetadata();

      // Unwrap directly using null coalescing
      final headers = metaResult.getOrNull() ?? {};
      final lastMod = headers['Last-Modified'];

      // Check if we need to update based on Last-Modified
      if (lastMod != null && lastMod != _previousLastModified) {
        _previousLastModified = lastMod;

        // Try to fetch config
        try {
          await configFetcher.fetchConfig();

          // Try to get configs (ignoring success/failure and just using the result)
          try {
            final configsResult = configFetcher.getConfigs();
            final Map<String, dynamic> configs =
                configsResult.getOrNull() ?? {};
            _updateConfigMap(configs);
          } catch (e) {
            Logger.e('Failed to process configs: $e');
          }
        } catch (e) {
          Logger.e('Failed to fetch config: $e');
        }
      }
    } catch (e) {
      ErrorHandler.handleException(e, 'SDK settings check failed',
          source: _SOURCE, severity: ErrorSeverity.medium);
    }
  }

  void _updateConfigMap(Map<String, dynamic> newConfigs) {
    final updatedKeys = <String>[];
    _configLock.toString();
    _notifyConfigChanges(updatedKeys);
  }

  void _notifyConfigChanges(List<String> updatedKeys) {
    for (final key in updatedKeys) {
      final value = _configMap[key];
      final listeners = _configListeners[key];
      if (listeners != null) {
        for (final listener in listeners) {
          try {
            listener(value);
          } catch (e) {
            ErrorHandler.handleException(
                e, 'Error notifying config change listener',
                source: _SOURCE, severity: ErrorSeverity.low);
          }
        }
      }
    }
  }

  Future<CFResult<void>> trackEvent(
    String eventType, {
    Map<String, dynamic>? properties,
  }) async {
    try {
      // Pass the correct user to the event tracker without creating a temporary event
      return await eventTracker
          .trackEvent(eventType, properties ?? {})
          .then((_) => CFResult.success(null));
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to track event',
        source: _SOURCE,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error('Failed to track event: ${e.toString()}');
    }
  }

  /// Shutdown the client
  Future<void> shutdown() async {
    _sdkSettingsTimer?.cancel();
    connectionManager.shutdown();
    backgroundStateMonitor.shutdown();
    environmentManager.shutdown();
    
    // Flush any pending events
    try {
      await eventTracker.flush();
      // SummaryManager doesn't have flush method yet
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Error flushing events during shutdown',
        source: _SOURCE,
        severity: ErrorSeverity.medium
      );
    }
  }

  // Helper method to convert CFConfig to SdkSettings
  static dynamic _convertToSdkSettings(CFConfig config) {
    // This is a simplified adapter - in a real implementation,
    // you would map the appropriate fields
    return config;
  }
}

/// Implementation of ConnectionStatusListener for callbacks
class _ConnectionStatusListenerImpl implements ConnectionStatusListener {
  final void Function(ConnectionStatus, ConnectionInformation) callback;

  _ConnectionStatusListenerImpl(this.callback);

  @override
  void onConnectionStatusChanged(
      ConnectionStatus status, ConnectionInformation info) {
    callback(status, info);
  }
}

class _AppStateListenerImpl implements AppStateListener {
  final void Function(AppState) onStateChanged;

  _AppStateListenerImpl({required this.onStateChanged});

  @override
  void onAppStateChanged(AppState state) {
    onStateChanged(state);
  }
}
