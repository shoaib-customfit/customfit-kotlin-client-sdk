package customfit.ai.kotlinclient.client.managers

import customfit.ai.kotlinclient.logging.Timber
import customfit.ai.kotlinclient.utils.CacheManager
import customfit.ai.kotlinclient.utils.CachePolicy
import java.util.concurrent.atomic.AtomicReference

/**
 * Manages caching of configuration responses 
 * This enables immediate access to cached configurations on startup
 * while still fetching updated configurations from the server.
 */
class ConfigCache {
    companion object {
        private const val CONFIG_CACHE_KEY = "cf_config_data"
        private const val METADATA_CACHE_KEY = "cf_config_metadata"
        
        // Cache policy with 24 hour TTL but persisted across app restarts
        private val CONFIG_CACHE_POLICY = CachePolicy(
            ttlSeconds = 24 * 60 * 60, // 24 hours
            useStaleWhileRevalidate = true,
            evictOnAppRestart = false,
            persist = true
        )
    }
    
    private val cacheManager = CacheManager.getInstance()
    private val lastModifiedRef = AtomicReference<String?>(null)
    private val eTagRef = AtomicReference<String?>(null)
    
    /**
     * Store configuration data in cache
     * 
     * @param configMap The configuration map to cache
     * @param lastModified The Last-Modified header value
     * @param etag The ETag header value
     * @return True if successfully cached, false otherwise
     */
    fun cacheConfig(
        configMap: Map<String, Any>,
        lastModified: String?,
        etag: String?
    ): Boolean {
        // Store the config data
        val configResult = cacheManager.put(
            CONFIG_CACHE_KEY,
            configMap,
            CONFIG_CACHE_POLICY
        )
        
        // Store metadata separately
        val metadata = mapOf(
            "lastModified" to (lastModified ?: ""),
            "etag" to (etag ?: "")
        )
        
        val metadataResult = cacheManager.put(
            METADATA_CACHE_KEY,
            metadata,
            CONFIG_CACHE_POLICY
        )
        
        // Update in-memory refs
        lastModifiedRef.set(lastModified)
        eTagRef.set(etag)
        
        Timber.d("Configuration cached with Last-Modified: $lastModified, ETag: $etag")
        
        return configResult && metadataResult
    }
    
    /**
     * Get cached configuration data
     * 
     * @return Triple containing configuration map, Last-Modified value, and ETag value
     */
    fun getCachedConfig(): Triple<Map<String, Any>?, String?, String?> {
        // Retrieve config data
        @Suppress("UNCHECKED_CAST")
        val configMap = cacheManager.get<Map<String, Any>>(CONFIG_CACHE_KEY)
        
        // Get metadata if available
        @Suppress("UNCHECKED_CAST")
        val metadata = cacheManager.get<Map<String, String>>(METADATA_CACHE_KEY)
        
        val lastModified = metadata?.get("lastModified") ?: lastModifiedRef.get()
        val etag = metadata?.get("etag") ?: eTagRef.get()
        
        if (configMap != null) {
            Timber.d("Found cached configuration with ${configMap.size} entries")
            Timber.d("Cached config metadata - Last-Modified: $lastModified, ETag: $etag")
        } else {
            Timber.d("No cached configuration found")
        }
        
        return Triple(configMap, lastModified, etag)
    }
    
    /**
     * Clear cached configuration data
     */
    fun clearCache() {
        cacheManager.remove(CONFIG_CACHE_KEY)
        cacheManager.remove(METADATA_CACHE_KEY)
        lastModifiedRef.set(null)
        eTagRef.set(null)
        Timber.d("Configuration cache cleared")
    }
} 