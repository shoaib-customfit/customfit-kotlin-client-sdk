package customfit.ai.kotlinclient.utils

import customfit.ai.kotlinclient.logging.Timber
import kotlinx.coroutines.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.Contextual
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.descriptors.element
import kotlinx.serialization.encodeToString
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.modules.SerializersModule
import kotlinx.serialization.modules.contextual
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write
import java.util.Date
import kotlin.time.Duration.Companion.seconds

/**
 * Manages cache operations with TTL, disk persistence, and background reloading.
 */
class CacheManager private constructor() {
    companion object {
        private const val TAG = "CacheManager"
        private const val KEY_PREFIX = "cf_cache_"
        private const val CACHE_META_KEY = "${KEY_PREFIX}meta"

        // The singleton instance
        @Volatile
        private var instance: CacheManager? = null

        /**
         * Get the singleton instance
         */
        fun getInstance(): CacheManager {
            return instance ?: synchronized(this) {
                instance ?: CacheManager().also { instance = it }
            }
        }
    }

    // Directory for storing cache files
    private val cacheDir by lazy {
        val dir = File(System.getProperty("java.io.tmpdir"), "cf_cache")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        dir
    }

    // In-memory cache
    private val memoryCache = ConcurrentHashMap<String, CacheEntry<Any>>()

    // Lock for cache operations
    private val cacheLock = ReentrantReadWriteLock()

    // JSON serializer
    private val json = Json { 
        ignoreUnknownKeys = true 
        isLenient = true
        prettyPrint = false
        serializersModule = SerializersModule {
            contextual(AnySerializer)
        }
    }

    // Coroutine scope for background operations
    private val cacheScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    init {
        // Load cache metadata and perform cleanup
        cacheScope.launch {
            loadCacheMetadata()
            performCacheCleanup()
        }
    }

    /**
     * Store a value in the cache
     *
     * @param key Cache key
     * @param value Value to cache
     * @param policy Cache policy to apply
     * @param metadata Optional metadata to store with the entry
     * @return True if successful, false otherwise
     */
    fun <T : Any> put(
        key: String,
        value: T,
        policy: CachePolicy = CachePolicy.standard,
        metadata: Map<String, String>? = null
    ): Boolean {
        try {
            // No caching if TTL is 0
            if (policy.ttlSeconds <= 0) {
                return false
            }

            val normalizedKey = normalizeKey(key)
            
            val now = System.currentTimeMillis()
            val expiresAt = now + (policy.ttlSeconds * 1000L)
            
            val entry = CacheEntry(
                value = value,
                expiresAt = expiresAt,
                createdAt = now,
                key = normalizedKey,
                metadata = metadata
            )
            
            // Update memory cache
            cacheLock.write {
                @Suppress("UNCHECKED_CAST")
                memoryCache[normalizedKey] = entry as CacheEntry<Any>
            }
            
            // Persist if needed
            if (policy.persist) {
                persistEntry(normalizedKey, entry)
            }
            
            Timber.d("Cached value for key $normalizedKey, expires in ${policy.ttlSeconds}s")
            return true
        } catch (e: Exception) {
            Timber.e(e, "Error caching value: ${e.message}")
            return false
        }
    }

    /**
     * Get a value from cache
     *
     * @param key Cache key
     * @param allowExpired Whether to return expired entries
     * @return The cached value or null if not found or expired
     */
    @Suppress("UNCHECKED_CAST")
    fun <T : Any> get(key: String, allowExpired: Boolean = false): T? {
        val normalizedKey = normalizeKey(key)
        
        // First check memory cache
        cacheLock.read {
            memoryCache[normalizedKey]?.let { entry ->
                // If not expired or explicitly allowing expired entries
                if (!entry.isExpired() || allowExpired) {
                    Timber.d("Cache hit for key $normalizedKey (memory)")
                    return entry.value as? T
                } else {
                    Timber.d("Cache hit for key $normalizedKey but entry expired")
                }
            }
        }
        
        // If not in memory, try persistent storage
        try {
            val file = File(cacheDir, "$normalizedKey.json")
            if (file.exists()) {
                val json = file.readText()
                val entry = deserializeEntry<T>(json)
                
                // Update memory cache
                cacheLock.write {
                    @Suppress("UNCHECKED_CAST")
                    memoryCache[normalizedKey] = entry as CacheEntry<Any>
                }
                
                // If not expired or explicitly allowing expired entries
                if (!entry.isExpired() || allowExpired) {
                    Timber.d("Cache hit for key $normalizedKey (persistent)")
                    return entry.value
                } else {
                    Timber.d("Cache hit for key $normalizedKey but entry expired")
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "Error reading from cache: ${e.message}")
        }
        
        Timber.d("Cache miss for key $normalizedKey")
        return null
    }

    /**
     * Check if a key exists in cache and is not expired
     */
    fun contains(key: String): Boolean {
        val normalizedKey = normalizeKey(key)
        
        // First check memory cache
        cacheLock.read {
            memoryCache[normalizedKey]?.let { entry ->
                if (!entry.isExpired()) {
                    return true
                }
            }
        }
        
        // If not in memory, try persistent storage
        try {
            val file = File(cacheDir, "$normalizedKey.json")
            if (file.exists()) {
                val json = file.readText()
                val serializedEntry = json.decodeToSerializable()
                val expiresAt = serializedEntry.expiresAt
                return System.currentTimeMillis() < expiresAt
            }
        } catch (e: Exception) {
            Timber.e(e, "Error checking cache: ${e.message}")
        }
        
        return false
    }

    /**
     * Remove a value from cache
     */
    fun remove(key: String): Boolean {
        val normalizedKey = normalizeKey(key)
        
        cacheLock.write {
            memoryCache.remove(normalizedKey)
        }
        
        try {
            // Remove from persistent storage
            val file = File(cacheDir, "$normalizedKey.json")
            val result = if (file.exists()) file.delete() else false
            
            Timber.d("Removed key $normalizedKey from cache: $result")
            return result
        } catch (e: Exception) {
            Timber.e(e, "Error removing from cache: ${e.message}")
            return false
        }
    }

    /**
     * Clear all cached values
     */
    fun clear(): Boolean {
        cacheLock.write {
            memoryCache.clear()
        }
        
        try {
            // Clear persistent storage
            val files = cacheDir.listFiles { file -> 
                file.name.startsWith(KEY_PREFIX) || 
                file.extension == "json" 
            } ?: emptyArray()
            
            var success = true
            for (file in files) {
                if (!file.delete()) {
                    success = false
                    Timber.w("Failed to delete cache file: ${file.absolutePath}")
                }
            }
            
            Timber.d("Cache cleared (${files.size} entries)")
            return success
        } catch (e: Exception) {
            Timber.e(e, "Error clearing cache: ${e.message}")
            return false
        }
    }

    /**
     * Refresh a cached value using a provider function
     */
    suspend fun <T : Any> refresh(
        key: String,
        provider: suspend () -> T,
        policy: CachePolicy = CachePolicy.standard,
        metadata: Map<String, String>? = null
    ): T? {
        try {
            Timber.d("Refreshing cached value for key $key")
            val freshValue = provider()
            
            // Cache the fresh value
            put(
                key = key,
                value = freshValue,
                policy = policy,
                metadata = metadata
            )
            
            return freshValue
        } catch (e: Exception) {
            Timber.e(e, "Error refreshing cached value: ${e.message}")
            return null
        }
    }

    /**
     * Get a value, using the provider to fetch if missing or expired
     */
    suspend fun <T : Any> getOrFetch(
        key: String,
        provider: suspend () -> T,
        policy: CachePolicy = CachePolicy.standard,
        metadata: Map<String, String>? = null
    ): T? {
        val normalizedKey = normalizeKey(key)
        
        // First try to get from cache
        val cachedValue = get<T>(normalizedKey)
        
        // If we have a valid cached value, return it
        if (cachedValue != null) {
            // Check if we need to refresh in background
            cacheLock.read {
                memoryCache[normalizedKey]?.let { entry ->
                    // If the entry is close to expiring (less than 10% of TTL left)
                    // refresh it in the background
                    val expirationMs = entry.expiresAt - System.currentTimeMillis()
                    val refreshThresholdMs = policy.ttlSeconds * 100L
                    
                    if (expirationMs <= refreshThresholdMs) {
                        Timber.d("Background refreshing cache for key $normalizedKey")
                        // Launch background refresh
                        cacheScope.launch {
                            refresh(key, provider, policy, metadata)
                        }
                    }
                }
            }
            
            return cachedValue
        }
        
        // Try to fetch fresh value
        return refresh(key, provider, policy, metadata)
    }

    /**
     * Normalize a cache key to avoid special characters
     */
    private fun normalizeKey(key: String): String {
        return "$KEY_PREFIX${key.replace(Regex("[^a-zA-Z0-9_]"), "_")}"
    }

    /**
     * Persist a cache entry to disk
     */
    private fun <T : Any> persistEntry(key: String, entry: CacheEntry<T>) {
        try {
            val file = File(cacheDir, "$key.json")
            val serialized = serializeEntry(entry)
            file.writeText(serialized)
            Timber.d("Persisted cache entry to file: ${file.absolutePath}")
        } catch (e: Exception) {
            Timber.e(e, "Error persisting cache entry: ${e.message}")
        }
    }

    /**
     * Load cache metadata
     */
    private fun loadCacheMetadata() {
        try {
            val metaFile = File(cacheDir, "$CACHE_META_KEY.json")
            if (metaFile.exists()) {
                val metaJson = metaFile.readText()
                val meta = json.decodeFromString<Map<String, Long>>(metaJson)
                
                // Handle any metadata needed (e.g., last cleanup time)
                val lastCleanup = meta["lastCleanup"] ?: 0L
                Timber.d("Cache last cleaned: ${Date(lastCleanup)}")
            }
        } catch (e: Exception) {
            Timber.e(e, "Error loading cache metadata: ${e.message}")
        }
    }

    /**
     * Save cache metadata
     */
    private fun saveCacheMetadata() {
        try {
            val metaFile = File(cacheDir, "$CACHE_META_KEY.json")
            val meta = mapOf(
                "lastCleanup" to System.currentTimeMillis()
            )
            val metaJson = json.encodeToString(meta)
            metaFile.writeText(metaJson)
        } catch (e: Exception) {
            Timber.e(e, "Error saving cache metadata: ${e.message}")
        }
    }

    /**
     * Clean up expired entries
     */
    private fun performCacheCleanup() {
        try {
            val now = System.currentTimeMillis()
            
            // Find all cache files
            val files = cacheDir.listFiles { file ->
                file.name.endsWith(".json") && 
                file.name != "$CACHE_META_KEY.json"
            } ?: emptyArray()
            
            var removedCount = 0
            
            // Check each file
            for (file in files) {
                try {
                    val json = file.readText()
                    val serializedEntry = json.decodeToSerializable()
                    val expiresAt = serializedEntry.expiresAt
                    
                    // If expired, remove it
                    if (now > expiresAt) {
                        if (file.delete()) {
                            removedCount++
                        }
                    }
                } catch (e: Exception) {
                    // Skip invalid files
                    Timber.w("Skipping invalid cache file: ${file.name}")
                }
            }
            
            // Update cache metadata
            saveCacheMetadata()
            
            Timber.d("Cache cleanup complete: removed $removedCount expired entries")
        } catch (e: Exception) {
            Timber.e(e, "Error during cache cleanup: ${e.message}")
        }
    }

    /**
     * Serialize an entry to JSON
     */
    private fun <T : Any> serializeEntry(entry: CacheEntry<T>): String {
        val serializable = entry.toSerializable()
        return json.encodeToString(serializable)
    }

    /**
     * Deserialize an entry from JSON
     */
    @Suppress("UNCHECKED_CAST")
    private fun <T : Any> deserializeEntry(jsonString: String): CacheEntry<T> {
        val serialized = jsonString.decodeToSerializable()
        return CacheEntry(
            value = serialized.value as T,
            expiresAt = serialized.expiresAt,
            createdAt = serialized.createdAt,
            key = serialized.key,
            metadata = serialized.metadata
        )
    }

    /**
     * Extension function to decode JSON to SerializableCacheEntry
     */
    private fun String.decodeToSerializable(): SerializableCacheEntry {
        return json.decodeFromString(this)
    }

    /**
     * Shutdown the cache manager
     */
    fun shutdown() {
        cacheScope.cancel()
    }
}

/**
 * Represents a cached value with metadata
 */
data class CacheEntry<T : Any>(
    val value: T,
    val expiresAt: Long,
    val createdAt: Long,
    val key: String,
    val metadata: Map<String, String>? = null
) {
    /**
     * Check if this entry has expired
     */
    fun isExpired(): Boolean {
        return System.currentTimeMillis() > expiresAt
    }

    /**
     * Calculate how many seconds until this entry expires
     */
    fun secondsUntilExpiration(): Long {
        val now = System.currentTimeMillis()
        if (now > expiresAt) return 0
        return (expiresAt - now) / 1000
    }

    /**
     * Convert to serializable form
     */
    fun toSerializable(): SerializableCacheEntry {
        return SerializableCacheEntry(
            value = value.toJsonValue(),
            expiresAt = expiresAt,
            createdAt = createdAt,
            key = key,
            metadata = metadata
        )
    }

    /**
     * Convert value to serializable form
     */
    private fun Any.toJsonValue(): Any {
        return when (this) {
            is Map<*, *> -> this.mapValues { (_, value) -> value?.toJsonValue() ?: "null" }
            is List<*> -> this.map { it?.toJsonValue() ?: "null" }
            is Set<*> -> this.map { it?.toJsonValue() ?: "null" }
            is Boolean, is Number, is String -> this
            else -> this.toString()
        }
    }
}

/**
 * Serializable version of CacheEntry
 */
@Serializable
data class SerializableCacheEntry(
    @Contextual val value: Any,
    val expiresAt: Long,
    val createdAt: Long,
    val key: String,
    val metadata: Map<String, String>? = null
)

/**
 * Serializer for Any type
 */
object AnySerializer : KSerializer<Any> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("Any") {
        element<String>("type")
        element<JsonElement>("value")
    }

    override fun serialize(encoder: Encoder, value: Any) {
        val jsonEncoder = encoder as? kotlinx.serialization.json.JsonEncoder 
            ?: throw SerializationException("This serializer can only be used with JSON")
        
        val jsonElement = when (value) {
            is String -> JsonPrimitive(value)
            is Number -> JsonPrimitive(value)
            is Boolean -> JsonPrimitive(value)
            is Map<*, *> -> {
                val map = value.entries.associate { 
                    it.key.toString() to (it.value?.let { v -> 
                        when (v) {
                            is String, is Number, is Boolean -> Json.encodeToJsonElement(v)
                            else -> JsonPrimitive(v.toString())
                        }
                    } ?: JsonPrimitive("null"))
                }
                JsonObject(map)
            }
            else -> JsonPrimitive(value.toString())
        }
        
        encoder.encodeSerializableValue(JsonElement.serializer(), jsonElement)
    }

    override fun deserialize(decoder: Decoder): Any {
        val jsonDecoder = decoder as? kotlinx.serialization.json.JsonDecoder 
            ?: throw SerializationException("This serializer can only be used with JSON")
        
        val jsonElement = jsonDecoder.decodeSerializableValue(JsonElement.serializer())
        
        return when (jsonElement) {
            is JsonPrimitive -> {
                when {
                    jsonElement.isString -> jsonElement.content
                    jsonElement.content == "true" -> true
                    jsonElement.content == "false" -> false
                    jsonElement.content.toDoubleOrNull() != null -> {
                        val content = jsonElement.content
                        when {
                            content.contains('.') -> content.toDouble()
                            content.toLongOrNull() != null -> content.toLong()
                            else -> content.toInt()
                        }
                    }
                    else -> jsonElement.content
                }
            }
            is JsonObject -> jsonElement.toMap()
            else -> jsonElement.toString()
        }
    }
}

/**
 * Extension function to convert JsonObject to Map
 */
private fun JsonObject.toMap(): Map<String, Any> {
    val result = mutableMapOf<String, Any>()
    for ((key, value) in this.entries) {
        result[key] = when (value) {
            is JsonPrimitive -> {
                when {
                    value.isString -> value.content
                    value.content == "true" -> true
                    value.content == "false" -> false
                    value.content.toDoubleOrNull() != null -> {
                        val content = value.content
                        when {
                            content.contains('.') -> content.toDouble()
                            content.toLongOrNull() != null -> content.toLong()
                            else -> content.toInt()
                        }
                    }
                    else -> value.content
                }
            }
            is JsonObject -> value.toMap()
            else -> value.toString()
        }
    }
    return result
}

/**
 * Cache policy to control caching behavior
 */
data class CachePolicy(
    val ttlSeconds: Int = 3600,             // 1 hour default
    val useStaleWhileRevalidate: Boolean = true,
    val evictOnAppRestart: Boolean = false,
    val persist: Boolean = true
) {
    companion object {
        /**
         * No caching policy - always fetch fresh
         */
        val noCaching = CachePolicy(
            ttlSeconds = 0,
            useStaleWhileRevalidate = false,
            evictOnAppRestart = true,
            persist = false
        )

        /**
         * Short-lived cache (1 minute)
         */
        val shortLived = CachePolicy(
            ttlSeconds = 60,
            useStaleWhileRevalidate = true,
            evictOnAppRestart = true,
            persist = true
        )

        /**
         * Standard cache (1 hour)
         */
        val standard = CachePolicy(
            ttlSeconds = 3600,
            useStaleWhileRevalidate = true,
            evictOnAppRestart = false,
            persist = true
        )

        /**
         * Long-lived cache (24 hours)
         */
        val longLived = CachePolicy(
            ttlSeconds = 86400,
            useStaleWhileRevalidate = true,
            evictOnAppRestart = false,
            persist = true
        )
    }
} 