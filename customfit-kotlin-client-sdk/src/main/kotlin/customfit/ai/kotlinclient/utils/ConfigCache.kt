package customfit.ai.kotlinclient.utils

import customfit.ai.kotlinclient.logging.Timber
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import java.io.File
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * A utility class for caching configuration data in the file system.
 * 
 * This allows the SDK to initialize with cached configurations immediately,
 * even when offline, and then update when a network connection is available.
 */
class ConfigCache(
    private val cacheDir: File = File(System.getProperty("java.io.tmpdir"), "customfit-cache"),
    private val configCacheFile: File = File(cacheDir, "config-cache.json"),
    private val metadataCacheFile: File = File(cacheDir, "config-metadata.json"),
    private val cacheValidityMs: Long = 24 * 60 * 60 * 1000 // 24 hours
) {
    private val cacheLock = ReentrantLock()
    
    init {
        // Ensure cache directory exists
        if (!cacheDir.exists()) {
            cacheDir.mkdirs()
        }
    }
    
    /**
     * Cache configuration data with HTTP metadata
     * 
     * @param configMap The configuration map to cache
     * @param lastModified The Last-Modified header from the server
     * @param etag The ETag header from the server
     * @return true if caching was successful
     */
    fun cacheConfig(
        configMap: Map<String, Any>,
        lastModified: String?,
        etag: String?
    ): Boolean {
        return cacheLock.withLock {
            try {
                // Create metadata to store alongside the config
                val metadata = mapOf(
                    "lastModified" to (lastModified ?: ""),
                    "etag" to (etag ?: ""),
                    "timestamp" to System.currentTimeMillis()
                )
                
                // Convert config to JSON
                val configJson = Json.encodeToString(configMap)
                val metadataJson = Json.encodeToString(metadata)
                
                // Write to files
                configCacheFile.writeText(configJson)
                metadataCacheFile.writeText(metadataJson)
                
                Timber.d("Configuration cached with ${configMap.size} entries")
                Timber.d("Cached config metadata - Last-Modified: $lastModified, ETag: $etag")
                
                true
            } catch (e: Exception) {
                Timber.e(e, "Error caching configuration: ${e.message}")
                false
            }
        }
    }
    
    /**
     * Get cached configuration data
     * 
     * @return Triple containing the config map, Last-Modified header, and ETag
     */
    fun getCachedConfig(): Triple<Map<String, Any>?, String?, String?> {
        return cacheLock.withLock {
            try {
                if (!configCacheFile.exists() || !metadataCacheFile.exists()) {
                    Timber.d("No cached configuration found")
                    return Triple(null, null, null)
                }
                
                // Read JSON files
                val configJson = configCacheFile.readText()
                val metadataJson = metadataCacheFile.readText()
                
                // Parse JSON
                val configMap = Json.decodeFromString<Map<String, Any>>(configJson)
                val metadata = Json.decodeFromString<Map<String, Any>>(metadataJson)
                
                // Extract metadata values
                val lastModified = metadata["lastModified"] as? String
                val etag = metadata["etag"] as? String
                val timestamp = metadata["timestamp"] as? Long ?: 0L
                
                // Check if cache is still valid
                val now = System.currentTimeMillis()
                val cacheAge = now - timestamp
                
                if (cacheAge > cacheValidityMs) {
                    Timber.d("Cached configuration has expired (age: ${cacheAge / 1000 / 60 / 60} hours)")
                    return Triple(null, null, null)
                }
                
                Timber.d("Found cached configuration with ${configMap.size} entries")
                Timber.d("Cached config metadata - Last-Modified: $lastModified, ETag: $etag")
                Timber.d("Cache age: ${cacheAge / 1000 / 60} minutes")
                
                Triple(configMap, lastModified, etag)
            } catch (e: Exception) {
                Timber.e(e, "Error retrieving cached configuration: ${e.message}")
                Triple(null, null, null)
            }
        }
    }
    
    /**
     * Clear the configuration cache
     * 
     * @return true if clearing was successful
     */
    fun clearCache(): Boolean {
        return cacheLock.withLock {
            try {
                var success = true
                
                if (configCacheFile.exists()) {
                    success = configCacheFile.delete() && success
                }
                
                if (metadataCacheFile.exists()) {
                    success = metadataCacheFile.delete() && success
                }
                
                Timber.d("Configuration cache cleared")
                success
            } catch (e: Exception) {
                Timber.e(e, "Error clearing configuration cache: ${e.message}")
                false
            }
        }
    }
} 