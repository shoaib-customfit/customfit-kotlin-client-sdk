import 'package:flutter/foundation.dart';
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';
import 'dart:async';

class CustomFitProvider with ChangeNotifier {
  CFClient? _client;
  bool _isInitialized = false;
  Map<String, dynamic> _featureFlags = {};
  String? _heroText;
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
  String get heroText => _heroText ?? '';
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

      final user = CFUser(
        userCustomerId: 'flutter_user_${DateTime.now().millisecondsSinceEpoch}',
        properties: {
          'name': 'Demo User',
          'platform': 'Flutter',
        },
        anonymous: true,
      );

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

      _client = CFClient.create(config, user);
      debugPrint('CFClient created successfully');

      // Add a listener for all flag changes
      _client!.listenerManager.registerAllFlagsListener(
        _CustomAllFlagsListener(
          onFlagsChanged: (oldFlags, newFlags) {
            debugPrint('🚩 Received flag update with ${newFlags.length} flags');
            _processNewFlags(newFlags);
          },
        ),
      );
      debugPrint('✅ All flags listener registered successfully');

      // Fetch initial flags
      await _fetchAndProcessLatestFlags();

      _isInitialized = true;
      notifyListeners();

      // Set up periodic refresh of feature flags
      Timer.periodic(const Duration(seconds: 5), (_) {
        debugPrint('📋 Periodic UI refresh - current heroText = $_heroText');
        _fetchAndProcessLatestFlags();
      });
    } catch (e) {
      debugPrint('❌ Failed to create CFClient or register listener: $e');
    }
  }

  void _processNewFlags(Map<String, dynamic> newFlags) {
    _featureFlags = Map.from(newFlags);

    // Process hero text flag
    if (newFlags.containsKey('hero_text')) {
      final value = newFlags['hero_text'];
      if (value is Map<String, dynamic> && value.containsKey('variation')) {
        final variation = value['variation'];
        if (variation != null &&
            variation is String &&
            variation != _heroText) {
          _heroText = variation;
          // Update message when hero text changes
          _lastConfigChangeMessage = "FLAG UPDATE: hero_text = $_heroText";
          _lastMessageTime = DateTime.now();
          notifyListeners(); // Notify UI of hero text change
        }
      } else if (value is String && value != _heroText) {
        _heroText = value;
        // Update message when hero text changes
        _lastConfigChangeMessage = "FLAG UPDATE: hero_text = $_heroText";
        _lastMessageTime = DateTime.now();
        notifyListeners(); // Notify UI of hero text change
      }
    }

    // Process enhanced toast flag
    if (newFlags.containsKey('enhanced_toast')) {
      final value = newFlags['enhanced_toast'];
      if (value is Map<String, dynamic> && value.containsKey('variation')) {
        final variation = value['variation'];
        if (variation != null &&
            variation is bool &&
            variation != _enhancedToast) {
          _enhancedToast = variation;
        }
      } else if (value is bool && value != _enhancedToast) {
        _enhancedToast = value;
      }
    }

    notifyListeners();
  }

  Future<void> _fetchAndProcessLatestFlags() async {
    try {
      debugPrint('🔄 Fetching latest configuration...');
      // First try to fetch new config from server
      try {
        await _client!.configFetcher.fetchConfig();
        debugPrint('✅ Fetched latest flags from server');
      } catch (e) {
        debugPrint('⚠️ Error fetching flags from server: $e');
      }

      // Then get the latest flags from the client
      final newFlags = await _client!.configManager.getAllFlags();
      debugPrint('📊 Got flags: $newFlags');
      _processNewFlags(newFlags);
    } catch (e) {
      debugPrint('⚠️ Error processing flags update: $e');
    }
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
    if (!_isInitialized) return false;

    debugPrint('Manually refreshing feature flags...');

    // Track the refresh event if an event name is provided
    if (eventName != null && _client != null) {
      await trackEvent(eventName, properties: {
        'config_key': 'all',
        'refresh_source': 'user_action',
        'screen': 'home',
        'platform': 'flutter'
      });
    }

    // If client exists, fetch and process latest flags
    if (_client != null) {
      await _fetchAndProcessLatestFlags();
    } else {
      // If no client, update values manually to latest known version from server
      _heroText = 'CF Kotlin Flag Demo-18';
      _featureFlags = {
        'hero_text': {'variation': _heroText},
        'enhanced_toast': {'variation': _enhancedToast},
      };
      notifyListeners();
    }

    // Update the last message
    _lastConfigChangeMessage = "Configuration manually refreshed";
    _lastMessageTime = DateTime.now();
    notifyListeners();

    return true;
  }

  @override
  void dispose() {
    if (_isInitialized && _client != null) {
      _client!.shutdown();
    }
    super.dispose();
  }
}

class _CustomAllFlagsListener implements AllFlagsListener {
  final void Function(Map<String, dynamic>, Map<String, dynamic>)
      onFlagsChanged;

  _CustomAllFlagsListener({required this.onFlagsChanged});

  @override
  void onAllFlagsChanged(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags) {
    onFlagsChanged(oldFlags, newFlags);
  }
}
