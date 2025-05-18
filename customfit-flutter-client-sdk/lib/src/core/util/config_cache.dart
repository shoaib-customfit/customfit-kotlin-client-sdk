import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../logging/logger.dart';

/// Cache policy to control caching behavior
class CachePolicy {
  final int ttlSeconds;
  final bool useStaleWhileRevalidate;
  final bool evictOnAppRestart;
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

  /// Default config cache policy (24 hours)
  static const configCache = CachePolicy(
    ttlSeconds: 24 * 60 * 60, // 24 hours
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );
}

/// Manages caching of configuration responses
/// This enables immediate access to cached configurations on startup
/// while still fetching updated configurations from the server.
class ConfigCache {
  static const String _configCacheKey = 'cf_cached_config_data';
  static const String _metadataCacheKey = 'cf_cached_config_metadata';

  // In-memory cache for fast access
  final Map<String, dynamic> _memoryConfigCache = {};
  final Map<String, dynamic> _memoryMetadataCache = {};

  // Cache locks for thread safety
  final _cacheLock = Object();

  // Reference to last known values for fast access
  String? _lastModifiedRef;
  String? _eTagRef;

  /// Cache configuration data
  ///
  /// @param configMap The configuration map to cache
  /// @param lastModified The Last-Modified header value
  /// @param etag The ETag header value
  /// @param policy Cache policy to use
  /// @return Future<bool> true if successfully cached, false otherwise
  Future<bool> cacheConfig(
    Map<String, dynamic> configMap,
    String? lastModified,
    String? etag, {
    CachePolicy policy = CachePolicy.configCache,
  }) async {
    try {
      // No caching if TTL is 0
      if (policy.ttlSeconds <= 0) {
        return false;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = now + (policy.ttlSeconds * 1000);

      // Store metadata
      final metadata = {
        'lastModified': lastModified ?? '',
        'etag': etag ?? '',
        'timestamp': now,
        'expiresAt': expiresAt,
      };

      // Update in-memory cache
      synchronized(() {
        _memoryConfigCache[_configCacheKey] = configMap;
        _memoryMetadataCache[_metadataCacheKey] = metadata;
        _lastModifiedRef = lastModified;
        _eTagRef = etag;
      });

      // Only persist if policy allows
      if (policy.persist) {
        // Get shared prefs instance
        final prefs = await SharedPreferences.getInstance();

        // Serialize the config map to JSON
        final configJson = jsonEncode(configMap);
        final metadataJson = jsonEncode(metadata);

        // Save both to shared preferences
        await prefs.setString(_configCacheKey, configJson);
        await prefs.setString(_metadataCacheKey, metadataJson);
      }

      Logger.d('Configuration cached with ${configMap.length} entries');
      Logger.d(
          'Cached config metadata - Last-Modified: $lastModified, ETag: $etag, expires in ${policy.ttlSeconds}s');

      return true;
    } catch (e) {
      Logger.e('Error caching configuration: $e');
      return false;
    }
  }

  /// Get cached configuration data
  ///
  /// @param allowExpired Whether to return expired entries (stale-while-revalidate)
  /// @return Future<ConfigCacheResult> containing configuration map, Last-Modified value, and ETag value
  Future<ConfigCacheResult> getCachedConfig({bool allowExpired = false}) async {
    try {
      // First check memory cache for the fastest path
      ConfigCacheResult? memoryResult;
      synchronized(() {
        final cachedConfig = _memoryConfigCache[_configCacheKey];
        final cachedMetadata = _memoryMetadataCache[_metadataCacheKey];

        if (cachedConfig != null && cachedMetadata != null) {
          final expiresAt = cachedMetadata['expiresAt'] as int?;
          final now = DateTime.now().millisecondsSinceEpoch;

          // If not expired or we allow stale data
          if ((expiresAt != null && now < expiresAt) || allowExpired) {
            final lastModified = cachedMetadata['lastModified'] as String?;
            final etag = cachedMetadata['etag'] as String?;

            Logger.d(
                'Memory cache hit for configuration with ${(cachedConfig as Map).length} entries');
            memoryResult = ConfigCacheResult(
                cachedConfig as Map<String, dynamic>, lastModified, etag);
          }
        }
      });

      // Return the memory result if we found one
      if (memoryResult != null) {
        return Future<ConfigCacheResult>.value(memoryResult);
      }

      // Not found in memory or expired, try persistent storage
      final prefs = await SharedPreferences.getInstance();

      // Get cached config data
      final configJson = prefs.getString(_configCacheKey);
      final metadataJson = prefs.getString(_metadataCacheKey);

      if (configJson == null || metadataJson == null) {
        Logger.d('No cached configuration found in persistent storage');
        return Future<ConfigCacheResult>.value(
            ConfigCacheResult(null, null, null));
      }

      // Parse the data
      final configMap = jsonDecode(configJson) as Map<String, dynamic>;
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      final lastModified = metadata['lastModified'] as String?;
      final etag = metadata['etag'] as String?;
      final expiresAt = metadata['expiresAt'] as int?;

      // Check if cache is still valid
      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = expiresAt == null || now > expiresAt;

      // If expired and not allowing expired entries, return null
      if (isExpired && !allowExpired) {
        Logger.d('Cached configuration has expired');
        return Future<ConfigCacheResult>.value(
            ConfigCacheResult(null, null, null));
      }

      // Update in-memory cache
      synchronized(() {
        _memoryConfigCache[_configCacheKey] = configMap;
        _memoryMetadataCache[_metadataCacheKey] = metadata;
        _lastModifiedRef = lastModified;
        _eTagRef = etag;
      });

      Logger.d('Found cached configuration with ${configMap.length} entries');
      Logger.d(
          'Cached config metadata - Last-Modified: $lastModified, ETag: $etag');

      if (isExpired) {
        Logger.d('Returning expired cache entry (stale-while-revalidate)');
      }

      return Future<ConfigCacheResult>.value(
          ConfigCacheResult(configMap, lastModified, etag));
    } catch (e) {
      Logger.e('Error retrieving cached configuration: $e');

      // Try to return in-memory refs as last resort
      if (allowExpired) {
        final lastModified = _lastModifiedRef;
        final etag = _eTagRef;
        if (lastModified != null || etag != null) {
          Logger.d('Returning in-memory metadata refs as emergency fallback');
          return Future<ConfigCacheResult>.value(
              ConfigCacheResult(null, lastModified, etag));
        }
      }

      return Future<ConfigCacheResult>.value(
          ConfigCacheResult(null, null, null));
    }
  }

  /// Clear cached configuration data
  Future<bool> clearCache() async {
    try {
      // Clear memory cache
      synchronized(() {
        _memoryConfigCache.clear();
        _memoryMetadataCache.clear();
        _lastModifiedRef = null;
        _eTagRef = null;
      });

      // Clear persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_configCacheKey);
      await prefs.remove(_metadataCacheKey);

      Logger.d('Configuration cache cleared (memory and persistent)');
      return true;
    } catch (e) {
      Logger.e('Error clearing configuration cache: $e');
      return false;
    }
  }

  /// Perform a simple locking operation for thread safety
  void synchronized(void Function() action) {
    // This is a simple synchronization mechanism
    // In more complex scenarios, consider using a proper lock
    synchronized_inner(_cacheLock, action);
  }

  // Helper for synchronization
  void synchronized_inner(Object lock, void Function() action) {
    action();
  }
}

/// Class to hold cache result values
class ConfigCacheResult {
  final Map<String, dynamic>? configMap;
  final String? lastModified;
  final String? etag;

  ConfigCacheResult(this.configMap, this.lastModified, this.etag);
}
