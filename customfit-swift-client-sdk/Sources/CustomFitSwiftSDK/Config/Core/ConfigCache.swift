import Foundation

/// Cache for configuration data with metadata support for conditional requests
public class ConfigCache {
    
    // MARK: - Constants
    
    private enum CacheKeys {
        static let configs = "com.customfit.config.configs"
        static let lastModified = "com.customfit.config.lastModified"
        static let etag = "com.customfit.config.etag"
        static let timestamp = "com.customfit.config.timestamp"
        static let flags = "com.customfit.config.flags" // Legacy key for backward compatibility
    }
    
    // Max age of cache in milliseconds (30 days)
    private let maxCacheAgeMs: Int64 = 30 * 24 * 60 * 60 * 1000
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let cachePath: URL?
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.fileManager = FileManager.default
        
        // Set up file storage path for larger configs
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let cacheDirectory = documentsDirectory.appendingPathComponent("CustomFitCache", isDirectory: true)
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                do {
                    try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                    self.cachePath = cacheDirectory
                } catch {
                    Logger.error("Failed to create cache directory: \(error)")
                    self.cachePath = nil
                }
            } else {
                self.cachePath = cacheDirectory
            }
        } else {
            self.cachePath = nil
        }
    }
    
    // MARK: - Public Methods
    
    /// Save configuration and associated metadata
    /// - Parameters:
    ///   - configs: Configuration map to cache
    ///   - lastModified: Last-Modified header value
    ///   - etag: ETag header value
    public func saveConfigs(configs: [String: Any], lastModified: String?, etag: String?) {
        do {
            // Save configs to file for larger payloads
            if let cachePath = cachePath {
                let configsPath = cachePath.appendingPathComponent("configs.json")
                let configsData = try JSONSerialization.data(withJSONObject: configs)
                try configsData.write(to: configsPath)
                
                // Save metadata to UserDefaults
                userDefaults.set(true, forKey: CacheKeys.configs) // Flag indicating we have cached configs
                userDefaults.set(lastModified, forKey: CacheKeys.lastModified)
                userDefaults.set(etag, forKey: CacheKeys.etag)
                userDefaults.set(Date().timeIntervalSince1970 * 1000, forKey: CacheKeys.timestamp)
                
                Logger.debug("Saved configs to file cache with metadata - Last-Modified: \(lastModified ?? "none"), ETag: \(etag ?? "none")")
                return
            }
            
            // Fallback to UserDefaults for smaller payloads
            let data = try JSONSerialization.data(withJSONObject: configs)
            userDefaults.set(data, forKey: CacheKeys.configs)
            userDefaults.set(lastModified, forKey: CacheKeys.lastModified)
            userDefaults.set(etag, forKey: CacheKeys.etag)
            userDefaults.set(Date().timeIntervalSince1970 * 1000, forKey: CacheKeys.timestamp)
            
            Logger.debug("Saved configs to UserDefaults with metadata - Last-Modified: \(lastModified ?? "none"), ETag: \(etag ?? "none")")
        } catch {
            Logger.error("Error saving configs to cache: \(error)")
        }
    }
    
    /// Load cached configuration and metadata
    /// - Returns: Tuple with (configs, lastModified, etag)
    public func loadCachedConfig() -> ([String: Any]?, String?, String?) {
        // Check cache age
        if let timestamp = userDefaults.object(forKey: CacheKeys.timestamp) as? Double {
            let age = Int64(Date().timeIntervalSince1970 * 1000) - Int64(timestamp)
            if age > maxCacheAgeMs {
                Logger.debug("Cache is too old (\(age) ms), ignoring")
                clearCache()
                return (nil, nil, nil)
            }
        }
        
        // Try to load from file first
        if userDefaults.bool(forKey: CacheKeys.configs), let cachePath = cachePath {
            let configsPath = cachePath.appendingPathComponent("configs.json")
            
            if fileManager.fileExists(atPath: configsPath.path) {
                do {
                    let data = try Data(contentsOf: configsPath)
                    if let configs = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let lastModified = userDefaults.string(forKey: CacheKeys.lastModified)
                        let etag = userDefaults.string(forKey: CacheKeys.etag)
                        
                        Logger.debug("Loaded configs from file cache with metadata - Last-Modified: \(lastModified ?? "none"), ETag: \(etag ?? "none")")
                        return (configs, lastModified, etag)
                    }
                } catch {
                    Logger.error("Error loading configs from file: \(error)")
                }
            }
        }
        
        // Try UserDefaults if file cache failed
        if let data = userDefaults.data(forKey: CacheKeys.configs) {
            do {
                guard let configs = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return (nil, nil, nil)
                }
                
                let lastModified = userDefaults.string(forKey: CacheKeys.lastModified)
                let etag = userDefaults.string(forKey: CacheKeys.etag)
                
                Logger.debug("Loaded configs from UserDefaults with metadata - Last-Modified: \(lastModified ?? "none"), ETag: \(etag ?? "none")")
                return (configs, lastModified, etag)
            } catch {
                Logger.error("Error loading configs from UserDefaults: \(error)")
            }
        }
        
        // Try legacy format as fallback
        return (loadFlags(), nil, nil)
    }
    
    /// Legacy method for flag-only caching
    /// - Parameters:
    ///   - flags: Feature flags to cache
    public func saveFlags(_ flags: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: flags)
            userDefaults.set(data, forKey: CacheKeys.flags)
            Logger.debug("Saved flags to cache (legacy format)")
        } catch {
            Logger.error("Error saving flags to cache: \(error)")
        }
    }
    
    /// Legacy method to load flags-only cache
    /// - Returns: Cached flags or nil
    public func loadFlags() -> [String: Any]? {
        guard let data = userDefaults.data(forKey: CacheKeys.flags) else {
            return nil
        }
        
        do {
            guard let flags = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            Logger.debug("Loaded flags from cache (legacy format)")
            return flags
        } catch {
            Logger.error("Error loading flags from cache: \(error)")
            return nil
        }
    }
    
    /// Clear all cached data
    public func clearCache() {
        // Clear UserDefaults
        userDefaults.removeObject(forKey: CacheKeys.configs)
        userDefaults.removeObject(forKey: CacheKeys.lastModified)
        userDefaults.removeObject(forKey: CacheKeys.etag)
        userDefaults.removeObject(forKey: CacheKeys.timestamp)
        userDefaults.removeObject(forKey: CacheKeys.flags)
        
        // Clear file cache
        if let cachePath = cachePath {
            let configsPath = cachePath.appendingPathComponent("configs.json")
            if fileManager.fileExists(atPath: configsPath.path) {
                do {
                    try fileManager.removeItem(at: configsPath)
                } catch {
                    Logger.error("Error clearing file cache: \(error)")
                }
            }
        }
        
        Logger.debug("Cleared config cache")
    }
} 