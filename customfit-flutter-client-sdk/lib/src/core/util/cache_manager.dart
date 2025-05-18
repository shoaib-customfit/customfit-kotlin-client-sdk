import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../logging/logger.dart';
import '../util/synchronization.dart';

/// CacheEntry represents a cached value with metadata
class CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String key;
  final Map<String, String>? metadata;

  CacheEntry({
    required this.value,
    required this.expiresAt,
    required this.createdAt,
    required this.key,
    this.metadata,
  });

  /// Check if this entry has expired
  bool isExpired() {
    return DateTime.now().isAfter(expiresAt);
  }

  /// Calculate how many seconds until this entry expires
  int secondsUntilExpiration() {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return 0;
    return expiresAt.difference(now).inSeconds;
  }

  /// Convert to a JSON representation for storage
  Map<String, dynamic> toJson() {
    return {
      'value': value is Map || value is List ? value : value.toString(),
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'key': key,
      'metadata': metadata,
    };
  }

  /// Create a CacheEntry from JSON (for primitive types)
  static CacheEntry fromJson(Map<String, dynamic> json) {
    dynamic value = json['value'];

    // For primitive types, we'll return as string and let the caller handle conversion
    // Complex objects remain as their original types
    if (value is! Map && value is! List) {
      value = value.toString();
    }

    return CacheEntry(
      value: value,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      key: json['key'],
      metadata: json['metadata'] != null
          ? Map<String, String>.from(json['metadata'])
          : null,
    );
  }
}

/// Cache policy to control caching behavior
class CachePolicy {
  /// Cache TTL in seconds
  final int ttlSeconds;

  /// Whether to use stale data while refreshing
  final bool useStaleWhileRevalidate;

  /// Whether to evict on app restart
  final bool evictOnAppRestart;

  /// Whether to persist to disk (vs memory only)
  final bool persist;

  const CachePolicy({
    this.ttlSeconds = 3600, // 1 hour default
    this.useStaleWhileRevalidate = true,
    this.evictOnAppRestart = false,
    this.persist = true,
  });

  /// No caching policy - always fetch fresh
  static const noCaching = CachePolicy(
    ttlSeconds: 0,
    useStaleWhileRevalidate: false,
    evictOnAppRestart: true,
    persist: false,
  );

  /// Short-lived cache (1 minute)
  static const shortLived = CachePolicy(
    ttlSeconds: 60,
    useStaleWhileRevalidate: true,
    evictOnAppRestart: true,
    persist: true,
  );

  /// Standard cache (1 hour)
  static const standard = CachePolicy(
    ttlSeconds: 3600,
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );

  /// Long-lived cache (24 hours)
  static const longLived = CachePolicy(
    ttlSeconds: 86400,
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );
}

/// CacheManager provides persistent caching for configurations with TTL
class CacheManager {
  static const String _keyPrefix = "cf_cache_";
  static const String _cacheMetaKey = "${_keyPrefix}meta";
  static const String _cacheDir = "cf_cache";

  // In-memory cache for faster access
  final Map<String, CacheEntry<dynamic>> _memoryCache = {};

  // Lock for cache operations
  final _cacheLock = Object();

  // Singleton instance
  static CacheManager? _instance;

  // Private constructor
  CacheManager._();

  /// Get the singleton instance
  static CacheManager get instance {
    _instance ??= CacheManager._();
    return _instance!;
  }

  /// Initialize the cache system
  Future<void> initialize() async {
    try {
      Logger.d('Initializing cache manager');
      await _loadCacheMetadata();
      await _performCacheCleanup();
    } catch (e) {
      Logger.e('Error initializing cache: $e');
    }
  }

  /// Put a value in the cache with the given policy
  Future<bool> put<T>(
    String key,
    T value, {
    CachePolicy policy = CachePolicy.standard,
    Map<String, String>? metadata,
  }) async {
    try {
      // No caching if TTL is 0
      if (policy.ttlSeconds <= 0) {
        return false;
      }

      key = _normalizeKey(key);

      final now = DateTime.now();
      final expiresAt = now.add(Duration(seconds: policy.ttlSeconds));

      final entry = CacheEntry<T>(
        value: value,
        expiresAt: expiresAt,
        createdAt: now,
        key: key,
        metadata: metadata,
      );

      // Update memory cache
      synchronized(_cacheLock, () {
        _memoryCache[key] = entry;
      });

      // Persist if needed
      if (policy.persist) {
        await _persistEntry(key, entry);
      }

      Logger.d('Cached value for key $key, expires in ${policy.ttlSeconds}s');
      return true;
    } catch (e) {
      Logger.e('Error caching value: $e');
      return false;
    }
  }

  /// Get a value from cache
  /// Returns null if not found or expired (unless allowExpired is true)
  Future<T?> get<T>(String key, {bool allowExpired = false}) async {
    key = _normalizeKey(key);

    // First check memory cache
    final memoryEntry = synchronized<CacheEntry?>(
      _cacheLock,
      () => _memoryCache[key],
    );

    if (memoryEntry != null) {
      // If not expired or explicitly allowing expired entries
      if (!memoryEntry.isExpired() || allowExpired) {
        Logger.d('Cache hit for key $key (memory)');
        return _convertValue<T>(memoryEntry.value);
      } else {
        Logger.d('Cache hit for key $key but entry expired');
      }
    }

    // If not in memory, try persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_keyPrefix$key');

      if (jsonString != null) {
        // Parse JSON and create a cache entry
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

        // Create a new CacheEntry
        final entry = CacheEntry(
          value: jsonMap['value'],
          expiresAt: DateTime.fromMillisecondsSinceEpoch(jsonMap['expiresAt']),
          createdAt: DateTime.fromMillisecondsSinceEpoch(jsonMap['createdAt']),
          key: jsonMap['key'],
          metadata: jsonMap['metadata'] != null
              ? Map<String, String>.from(jsonMap['metadata'])
              : null,
        );

        // Update memory cache
        synchronized(_cacheLock, () {
          _memoryCache[key] = entry;
        });

        // If not expired or explicitly allowing expired entries
        if (!entry.isExpired() || allowExpired) {
          Logger.d('Cache hit for key $key (persistent)');
          return _convertValue<T>(entry.value);
        } else {
          Logger.d('Cache hit for key $key but entry expired');
        }
      }
    } catch (e) {
      Logger.e('Error reading from cache: $e');
    }

    Logger.d('Cache miss for key $key');
    return null;
  }

  /// Convert a value to the expected type
  T? _convertValue<T>(dynamic value) {
    try {
      if (value is T) {
        return value;
      }

      // Handle basic type conversions
      if (T == String) {
        return value.toString() as T;
      } else if (T == int && value is String) {
        return int.parse(value) as T;
      } else if (T == double && value is String) {
        return double.parse(value) as T;
      } else if (T == bool && value is String) {
        return (value.toLowerCase() == 'true') as T;
      } else if (value is Map && T.toString().contains('Map')) {
        return value as T;
      } else if (value is List && T.toString().contains('List')) {
        return value as T;
      }

      Logger.w('Could not convert value to type $T: $value');
      return null;
    } catch (e) {
      Logger.e('Error converting value: $e');
      return null;
    }
  }

  /// Check if a key exists in cache and is not expired
  Future<bool> contains(String key) async {
    key = _normalizeKey(key);

    // First check memory cache
    final memoryEntry = synchronized<CacheEntry?>(
      _cacheLock,
      () => _memoryCache[key],
    );

    if (memoryEntry != null && !memoryEntry.isExpired()) {
      return true;
    }

    // If not in memory, try persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_keyPrefix$key');

      if (json != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(json);
        final expiresAt =
            DateTime.fromMillisecondsSinceEpoch(jsonMap['expiresAt']);
        return DateTime.now().isBefore(expiresAt);
      }
    } catch (e) {
      Logger.e('Error checking cache: $e');
    }

    return false;
  }

  /// Remove a value from cache
  Future<bool> remove(String key) async {
    key = _normalizeKey(key);

    synchronized(_cacheLock, () {
      _memoryCache.remove(key);
    });

    try {
      // Remove from persistent storage
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.remove('$_keyPrefix$key');

      // Also try to remove any large cache file
      await _removeCacheFile(key);

      Logger.d('Removed key $key from cache: $result');
      return result;
    } catch (e) {
      Logger.e('Error removing from cache: $e');
      return false;
    }
  }

  /// Clear all cached values
  Future<bool> clear() async {
    synchronized(_cacheLock, () {
      _memoryCache.clear();
    });

    try {
      // Clear persistent storage
      final prefs = await SharedPreferences.getInstance();

      // Find all cache keys
      final keys =
          prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();

      // Remove each key
      for (final key in keys) {
        await prefs.remove(key);
      }

      // Clear cache directory
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }

      Logger.d('Cache cleared (${keys.length} entries)');
      return true;
    } catch (e) {
      Logger.e('Error clearing cache: $e');
      return false;
    }
  }

  /// Refresh a cached value using a provider function
  /// Returns the fresh value or null if refresh failed
  Future<T?> refresh<T>(
    String key,
    Future<T> Function() provider, {
    CachePolicy policy = CachePolicy.standard,
    Map<String, String>? metadata,
  }) async {
    try {
      Logger.d('Refreshing cached value for key $key');
      final freshValue = await provider();

      // Cache the fresh value
      await put<T>(
        key,
        freshValue,
        policy: policy,
        metadata: metadata,
      );

      return freshValue;
    } catch (e) {
      Logger.e('Error refreshing cached value: $e');
      return null;
    }
  }

  /// Get a value, using the provider to fetch if missing or expired
  Future<T?> getOrFetch<T>(
    String key,
    Future<T> Function() provider, {
    CachePolicy policy = CachePolicy.standard,
    Map<String, String>? metadata,
  }) async {
    key = _normalizeKey(key);

    // First try to get from cache
    final cachedValue = await get<T>(key);

    // If we have a valid cached value, return it
    if (cachedValue != null) {
      // Check if we need to refresh in background
      final entry = synchronized<CacheEntry?>(
        _cacheLock,
        () => _memoryCache[key],
      );

      // If the entry is close to expiring (less than 10% of TTL left)
      // refresh it in the background
      if (entry != null) {
        final expirationSeconds = entry.secondsUntilExpiration();
        final refreshThreshold = policy.ttlSeconds ~/ 10;

        if (expirationSeconds <= refreshThreshold) {
          Logger.d('Background refreshing cache for key $key');
          // Don't await to avoid blocking
          refresh(key, provider, policy: policy, metadata: metadata);
        }
      }

      return cachedValue;
    }

    // Try to fetch fresh value
    return await refresh(key, provider, policy: policy, metadata: metadata);
  }

  /// Normalizes a cache key to avoid special characters
  String _normalizeKey(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  /// Persist a cache entry
  Future<void> _persistEntry<T>(String key, CacheEntry<T> entry) async {
    final prefs = await SharedPreferences.getInstance();

    // For small values, use SharedPreferences
    final jsonEntry = jsonEncode(entry.toJson());

    // If the JSON is too large for SharedPreferences (>100KB),
    // store it in a file instead
    if (jsonEntry.length > 100000) {
      await _persistLargeEntry(key, jsonEntry);
      // Store a reference to the file in SharedPreferences
      await prefs.setString(
          '$_keyPrefix$key',
          jsonEncode({
            'isFile': true,
            'key': key,
            'expiresAt': entry.expiresAt.millisecondsSinceEpoch,
            'createdAt': entry.createdAt.millisecondsSinceEpoch,
            'metadata': entry.metadata,
          }));
    } else {
      // Store directly in SharedPreferences
      await prefs.setString('$_keyPrefix$key', jsonEntry);
    }
  }

  /// Store large entries in a file
  Future<void> _persistLargeEntry(String key, String jsonEntry) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$key.json');
      await file.writeAsString(jsonEntry);
      Logger.d('Stored large cache entry in file: ${file.path}');
    } catch (e) {
      Logger.e('Error storing large cache entry: $e');
    }
  }

  /// Remove a cache file for large entries
  Future<void> _removeCacheFile(String key) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$key.json');
      if (await file.exists()) {
        await file.delete();
        Logger.d('Removed cache file: ${file.path}');
      }
    } catch (e) {
      Logger.e('Error removing cache file: $e');
    }
  }

  /// Get the cache directory
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDir');

    // Create the directory if it doesn't exist
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// Load cache metadata
  Future<void> _loadCacheMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString(_cacheMetaKey);

      if (metaJson != null) {
        final meta = jsonDecode(metaJson);

        // Handle any metadata needed (e.g., last cleanup time)
        final lastCleanup = meta['lastCleanup'] ?? 0;
        Logger.d(
            'Cache last cleaned: ${DateTime.fromMillisecondsSinceEpoch(lastCleanup)}');
      }
    } catch (e) {
      Logger.e('Error loading cache metadata: $e');
    }
  }

  /// Clean up expired entries
  Future<void> _performCacheCleanup() async {
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();

      // Find all cache keys
      final keys = prefs
          .getKeys()
          .where((k) => k.startsWith(_keyPrefix) && k != _cacheMetaKey)
          .toList();

      var removedCount = 0;

      // Check each key
      for (final fullKey in keys) {
        final jsonStr = prefs.getString(fullKey);
        if (jsonStr != null) {
          final json = jsonDecode(jsonStr);
          final expiresAt =
              DateTime.fromMillisecondsSinceEpoch(json['expiresAt']);

          // If expired, remove it
          if (now.isAfter(expiresAt)) {
            // Extract the key (remove prefix)
            final key = fullKey.substring(_keyPrefix.length);

            // Handle file-based caches
            if (json['isFile'] == true) {
              await _removeCacheFile(key);
            }

            await prefs.remove(fullKey);
            removedCount++;
          }
        }
      }

      // Update metadata with last cleanup time
      await prefs.setString(
          _cacheMetaKey,
          jsonEncode({
            'lastCleanup': now.millisecondsSinceEpoch,
          }));

      Logger.d('Cache cleanup complete: removed $removedCount expired entries');
    } catch (e) {
      Logger.e('Error during cache cleanup: $e');
    }
  }
}
