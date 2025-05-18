import 'package:flutter/foundation.dart';
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';
import 'dart:async';

class CustomFitProvider with ChangeNotifier {
  CFClient? _client;
  bool _isInitialized = false;
  Map<String, dynamic> _featureFlags = {};
  String _heroText = 'CF Kotlin Flag Demo-18';
  bool _enhancedToast = false;
  bool _isOffline = false;
  String? _lastConfigChangeMessage;
  DateTime? _lastMessageTime;

  bool get hasNewConfigMessage =>
      _lastMessageTime != null &&
      DateTime.now().difference(_lastMessageTime!) < const Duration(minutes: 5);

  String? get lastConfigChangeMessage => _lastConfigChangeMessage;

  bool get isOffline => _isOffline;

  bool get isInitialized => _isInitialized;
  Map<String, dynamic> get featureFlags => _featureFlags;
  String get heroText => _heroText;
  bool get enhancedToast => _enhancedToast;

  CustomFitProvider() {
    _initialize();
  }

  Future<void> initialize() async {
    await _initialize();
  }

  Future<void> _initialize() async {
    try {
      debugPrint('Initializing CustomFit provider...');

      // Ensure the properties map is modifiable
      final userProperties = <String, dynamic>{
        'name': 'Demo User',
        'platform': 'Flutter',
      };
      final user = CFUser(
        userCustomerId: 'flutter_user_${DateTime.now().millisecondsSinceEpoch}',
        properties: userProperties,
        anonymous: true,
      );
      debugPrint('CFUser created with ID: ${user.userCustomerId}');

      // Create the CFConfig for the client
      final config = CFConfig.builder(
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek',
      )
          .setDebugLoggingEnabled(true)
          .setOfflineMode(false)
          .setSdkSettingsCheckIntervalMs(2000)
          .setBackgroundPollingIntervalMs(2000)
          .setReducedPollingIntervalMs(2000)
          .setSummariesFlushTimeSeconds(5)
          .setSummariesFlushIntervalMs(5000)
          .setEventsFlushTimeSeconds(30)
          .setEventsFlushIntervalMs(30000)
          .setNetworkConnectionTimeoutMs(10000)
          .setNetworkReadTimeoutMs(10000)
          .build();
      debugPrint('CFConfig created successfully');

      _client = CFClient.create(config, user);
      debugPrint('CFClient created successfully');

      _isInitialized = true;

      // Set up individual config listeners - similar to Kotlin implementation
      _setupConfigListeners();

      // Update initial values
      _updateInitialValues();

      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to create CFClient or register listener: $e');
      debugPrint('Stack trace: $stackTrace');
      // Make sure UI still shows something even if client fails
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _updateInitialValues() {
    if (_client == null) return;

    // Get initial values from config
    _heroText = _client!.getString('hero_text', 'CF DEMO');
    _enhancedToast = _client!.getBoolean('enhanced_toast', false);

    debugPrint(
        'Initial values: heroText=$_heroText, enhancedToast=$_enhancedToast');

    _featureFlags = {
      'hero_text': {'variation': _heroText},
      'enhanced_toast': {'variation': _enhancedToast},
    };

    notifyListeners();
  }

  void _setupConfigListeners() {
    if (_client == null) return;

    // Add listener for hero_text - similar to heroTextListener in Kotlin
    _client!.addConfigListener<String>('hero_text', (newValue) {
      debugPrint(
          '🚩 hero_text config listener triggered with value: $newValue');
      if (_heroText != newValue) {
        _heroText = newValue;
        _lastConfigChangeMessage = "FLAG UPDATE: hero_text = $_heroText";
        _lastMessageTime = DateTime.now();
        notifyListeners();
      }
    });

    // Add listener for enhanced_toast - similar to enhancedToastListener in Kotlin
    _client!.addConfigListener<bool>('enhanced_toast', (isEnabled) {
      debugPrint(
          '🚩 enhanced_toast config listener triggered with value: $isEnabled');
      if (_enhancedToast != isEnabled) {
        _enhancedToast = isEnabled;
        notifyListeners();
      }
    });

    debugPrint('✅ Config listeners set up successfully');
  }

  Future<void> toggleOfflineMode() async {
    if (!_isInitialized || _client == null) return;

    if (_isOffline) {
      _client!.connectionManager.setOfflineMode(false);
    } else {
      _client!.connectionManager.setOfflineMode(true);
    }
    _isOffline = !_isOffline;
    notifyListeners();
  }

  Future<void> trackEvent(String eventName,
      {Map<String, dynamic>? properties}) async {
    if (!_isInitialized || _client == null) {
      debugPrint('⚠️ Event tracking skipped: CFClient is null');
      return;
    }
    await _client!.eventTracker.trackEvent(eventName, properties ?? {});
  }

  Future<void> addUserProperty(String key, dynamic value) async {
    if (!_isInitialized || _client == null) return;
    _client!.userManager.addUserProperty(key, value);
    notifyListeners();
  }

  /// Force a refresh of feature flags
  Future<bool> refreshFeatureFlags([String? eventName]) async {
    if (!_isInitialized || _client == null) return false;

    debugPrint('Manually refreshing feature flags...');

    // Track the refresh event if an event name is provided
    if (eventName != null) {
      await trackEvent(eventName, properties: {
        'config_key': 'all',
        'refresh_source': 'user_action',
        'screen': 'home',
        'platform': 'flutter'
      });
    }

    // Fetch latest flags from server
    final success = await _client!.fetchConfigs();
    if (success) {
      // Values will be updated through listeners
      debugPrint('✅ Flags refreshed successfully');
    } else {
      debugPrint('⚠️ Failed to refresh flags');
    }

    // Update the last message
    _lastConfigChangeMessage = "Configuration manually refreshed";
    _lastMessageTime = DateTime.now();
    notifyListeners();

    return success;
  }

  @override
  void dispose() {
    if (_isInitialized && _client != null) {
      // Remove listeners when provider is disposed
      _client!.removeConfigListener('hero_text');
      _client!.removeConfigListener('enhanced_toast');
      _client!.shutdown();
    }
    super.dispose();
  }
}
