import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../logging/logger.dart';

/// Manages caching of configuration responses
/// This enables immediate access to cached configurations on startup
/// while still fetching updated configurations from the server.
class ConfigCache {
  static const String _configCacheKey = 'cf_cached_config_data';
  static const String _metadataCacheKey = 'cf_cached_config_metadata';

  /// Cache configuration data
  ///
  /// @param configMap The configuration map to cache
  /// @param lastModified The Last-Modified header value
  /// @param etag The ETag header value
  /// @return Future<bool> true if successfully cached, false otherwise
  Future<bool> cacheConfig(
    Map<String, dynamic> configMap,
    String? lastModified,
    String? etag,
  ) async {
    try {
      // Get shared prefs instance
      final prefs = await SharedPreferences.getInstance();

      // Serialize the config map to JSON
      final configJson = jsonEncode(configMap);

      // Store metadata separately
      final metadata = {
        'lastModified': lastModified ?? '',
        'etag': etag ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final metadataJson = jsonEncode(metadata);

      // Save both to shared preferences
      await prefs.setString(_configCacheKey, configJson);
      await prefs.setString(_metadataCacheKey, metadataJson);

      Logger.d('Configuration cached with ${configMap.length} entries');
      Logger.d(
          'Cached config metadata - Last-Modified: $lastModified, ETag: $etag');

      return true;
    } catch (e) {
      Logger.e('Error caching configuration: $e');
      return false;
    }
  }

  /// Get cached configuration data
  ///
  /// @return Future<Triple<Map<String, dynamic>?, String?, String?>> containing
  /// configuration map, Last-Modified value, and ETag value
  Future<ConfigCacheResult> getCachedConfig() async {
    try {
      // Get shared prefs instance
      final prefs = await SharedPreferences.getInstance();

      // Get cached config data
      final configJson = prefs.getString(_configCacheKey);
      final metadataJson = prefs.getString(_metadataCacheKey);

      if (configJson == null || metadataJson == null) {
        Logger.d('No cached configuration found');
        return ConfigCacheResult(null, null, null);
      }

      // Parse the data
      final configMap = jsonDecode(configJson) as Map<String, dynamic>;
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      final lastModified = metadata['lastModified'] as String?;
      final etag = metadata['etag'] as String?;
      final timestamp = metadata['timestamp'] as int?;

      // Check if cache is still valid (24 hours)
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = now - (timestamp ?? 0);
      const cacheTTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

      if (cacheAge > cacheTTL) {
        Logger.d(
            'Cached configuration has expired (age: ${cacheAge / 1000 / 60 / 60} hours)');
        return ConfigCacheResult(null, null, null);
      }

      Logger.d('Found cached configuration with ${configMap.length} entries');
      Logger.d(
          'Cached config metadata - Last-Modified: $lastModified, ETag: $etag');
      Logger.d('Cache age: ${cacheAge / 1000 / 60} minutes');

      return ConfigCacheResult(configMap, lastModified, etag);
    } catch (e) {
      Logger.e('Error retrieving cached configuration: $e');
      return ConfigCacheResult(null, null, null);
    }
  }

  /// Clear cached configuration data
  Future<bool> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_configCacheKey);
      await prefs.remove(_metadataCacheKey);

      Logger.d('Configuration cache cleared');
      return true;
    } catch (e) {
      Logger.e('Error clearing configuration cache: $e');
      return false;
    }
  }
}

/// Class to hold cache result values
class ConfigCacheResult {
  final Map<String, dynamic>? configMap;
  final String? lastModified;
  final String? etag;

  ConfigCacheResult(this.configMap, this.lastModified, this.etag);
}
