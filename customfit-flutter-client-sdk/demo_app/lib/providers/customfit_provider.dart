import 'package:flutter/foundation.dart';
import 'package:customfit_flutter_client_sdk/customfit_flutter_client_sdk.dart';

class CustomFitProvider with ChangeNotifier {
  late final CFClient _client;
  bool _isInitialized = false;
  Map<String, dynamic> _featureFlags = {};
  bool _isOffline = false;
  String _heroText = 'CF DEMO';
  bool _enhancedToast = false;

  bool get isInitialized => _isInitialized;
  Map<String, dynamic> get featureFlags => _featureFlags;
  bool get isOffline => _isOffline;
  String get heroText => _heroText;
  bool get enhancedToast => _enhancedToast;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final config = CFConfig.builder(
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek',
    )
        .setDebugLoggingEnabled(true)
        .setOfflineMode(false)
        .setSdkSettingsCheckIntervalMs(2000)
        .setSummariesFlushTimeSeconds(30)
        .setSummariesFlushIntervalMs(30000)
        .setEventsFlushTimeSeconds(30)
        .setEventsFlushIntervalMs(30000)
        .build();

    final user = CFUser(
      userCustomerId: 'flutter_user_${DateTime.now().millisecondsSinceEpoch}',
      properties: {
        'name': 'Demo User',
        'platform': 'Flutter',
      },
      anonymous: true,
    );

    _client = CFClient.create(config, user);
    await _loadConfigValues();
    _isInitialized = true;

    // Start listening to feature flag changes
    _client.listenerManager.registerAllFlagsListener(
      _CustomAllFlagsListener(
        onFlagsChanged: (oldFlags, newFlags) {
          _featureFlags = newFlags;
          notifyListeners();
        },
      ),
    );

    notifyListeners();
  }

  Future<void> _loadConfigValues() async {
    _heroText = await _client.configManager.getString('hero_text', 'CF DEMO');
    _enhancedToast =
        await _client.configManager.getBoolean('enhanced_toast', false);
  }

  Future<void> toggleOfflineMode() async {
    if (!_isInitialized) return;

    if (_isOffline) {
      _client.connectionManager.setOfflineMode(false);
    } else {
      _client.connectionManager.setOfflineMode(true);
    }
    _isOffline = !_isOffline;
    notifyListeners();
  }

  Future<void> trackEvent(String eventName,
      {Map<String, dynamic>? properties}) async {
    if (!_isInitialized) return;
    await _client.eventTracker.trackEvent(eventName, properties ?? {});
  }

  Future<void> addUserProperty(String key, dynamic value) async {
    if (!_isInitialized) return;
    _client.userManager.addUserProperty(key, value);
    notifyListeners();
  }

  void dispose() {
    if (_isInitialized) {
      _client.shutdown();
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

// Factory method to create CFClient (since it has a private constructor)
CFClient createCFClient(CFConfig config, CFUser user) {
  // This is a workaround for the private constructor
  // In a real implementation, CFClient would have a public factory method
  // We're using dynamic to bypass the private constructor restriction
  // In a real implementation, you would use the public factory method
  final dynamic client = CFClient;
  return client._(config, user);
}
