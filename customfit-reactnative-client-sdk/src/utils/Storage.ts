import AsyncStorage from '@react-native-async-storage/async-storage';
import { CFResult } from '../core/error/CFResult';
import { ErrorCategory, CacheEntry } from '../core/types/CFTypes';
import { Logger } from '../logging/Logger';

/**
 * Storage utility wrapper around AsyncStorage with caching and TTL support
 */
export class Storage {
  private static memoryCache = new Map<string, any>();
  private static readonly CACHE_TTL_KEY_SUFFIX = '_ttl';

  /**
   * Store a value in AsyncStorage
   */
  static async set(key: string, value: any): Promise<CFResult<void>> {
    try {
      const jsonValue = JSON.stringify(value);
      await AsyncStorage.setItem(key, jsonValue);
      
      // Update memory cache
      Storage.memoryCache.set(key, value);
      
      Logger.trace(`Storage: Set key '${key}' with value length ${jsonValue.length}`);
      return CFResult.successVoid();
    } catch (error) {
      Logger.error(`Storage: Failed to set key '${key}': ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Get a value from AsyncStorage
   */
  static async get<T>(key: string): Promise<CFResult<T | null>> {
    try {
      // Check memory cache first
      if (Storage.memoryCache.has(key)) {
        const value = Storage.memoryCache.get(key);
        Logger.trace(`Storage: Cache hit for key '${key}'`);
        return CFResult.success(value);
      }

      const jsonValue = await AsyncStorage.getItem(key);
      if (jsonValue === null) {
        Logger.trace(`Storage: Key '${key}' not found`);
        return CFResult.success(null);
      }

      const value = JSON.parse(jsonValue);
      
      // Update memory cache
      Storage.memoryCache.set(key, value);
      
      Logger.trace(`Storage: Retrieved key '${key}' with value length ${jsonValue.length}`);
      return CFResult.success(value);
    } catch (error) {
      Logger.error(`Storage: Failed to get key '${key}': ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Remove a value from AsyncStorage
   */
  static async remove(key: string): Promise<CFResult<void>> {
    try {
      await AsyncStorage.removeItem(key);
      Storage.memoryCache.delete(key);
      
      // Also remove TTL key if it exists
      await AsyncStorage.removeItem(key + Storage.CACHE_TTL_KEY_SUFFIX);
      
      Logger.trace(`Storage: Removed key '${key}'`);
      return CFResult.successVoid();
    } catch (error) {
      Logger.error(`Storage: Failed to remove key '${key}': ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Store a value with TTL (time to live)
   */
  static async setWithTTL<T>(key: string, value: T, ttlMs: number): Promise<CFResult<void>> {
    try {
      const cacheEntry: CacheEntry<T> = {
        data: value,
        timestamp: Date.now(),
        ttl: ttlMs,
      };

      const result = await Storage.set(key, cacheEntry);
      if (result.isSuccess) {
        Logger.trace(`Storage: Set key '${key}' with TTL ${ttlMs}ms`);
      }
      return result;
    } catch (error) {
      Logger.error(`Storage: Failed to set key '${key}' with TTL: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Get a value with TTL check
   */
  static async getWithTTL<T>(key: string): Promise<CFResult<T | null>> {
    try {
      const result = await Storage.get<CacheEntry<T>>(key);
      if (result.isError || !result.data) {
        return CFResult.success(null);
      }

      const cacheEntry = result.data;
      const now = Date.now();
      const age = now - cacheEntry.timestamp;

      if (age > cacheEntry.ttl) {
        Logger.trace(`Storage: Key '${key}' expired (age: ${age}ms, ttl: ${cacheEntry.ttl}ms)`);
        // Remove expired entry
        await Storage.remove(key);
        return CFResult.success(null);
      }

      Logger.trace(`Storage: Retrieved valid cached key '${key}' (age: ${age}ms, ttl: ${cacheEntry.ttl}ms)`);
      return CFResult.success(cacheEntry.data);
    } catch (error) {
      Logger.error(`Storage: Failed to get key '${key}' with TTL: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Check if a key exists
   */
  static async exists(key: string): Promise<CFResult<boolean>> {
    try {
      const keys = await AsyncStorage.getAllKeys();
      const exists = keys.includes(key);
      Logger.trace(`Storage: Key '${key}' exists: ${exists}`);
      return CFResult.success(exists);
    } catch (error) {
      Logger.error(`Storage: Failed to check if key '${key}' exists: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Get all keys matching a prefix
   */
  static async getKeysWithPrefix(prefix: string): Promise<CFResult<string[]>> {
    try {
      const allKeys = await AsyncStorage.getAllKeys();
      const matchingKeys = allKeys.filter(key => key.startsWith(prefix));
      Logger.trace(`Storage: Found ${matchingKeys.length} keys with prefix '${prefix}'`);
      return CFResult.success(matchingKeys);
    } catch (error) {
      Logger.error(`Storage: Failed to get keys with prefix '${prefix}': ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Clear all storage
   */
  static async clear(): Promise<CFResult<void>> {
    try {
      await AsyncStorage.clear();
      Storage.memoryCache.clear();
      Logger.info('Storage: Cleared all data');
      return CFResult.successVoid();
    } catch (error) {
      Logger.error(`Storage: Failed to clear: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Get storage usage information
   */
  static async getStorageInfo(): Promise<CFResult<{ keyCount: number; keys: string[] }>> {
    try {
      const keys = await AsyncStorage.getAllKeys();
      Logger.trace(`Storage: Total keys: ${keys.length}`);
      return CFResult.success({
        keyCount: keys.length,
        keys: keys,
      });
    } catch (error) {
      Logger.error(`Storage: Failed to get storage info: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Clear memory cache
   */
  static clearMemoryCache(): void {
    Storage.memoryCache.clear();
    Logger.debug('Storage: Memory cache cleared');
  }

  /**
   * Get memory cache stats
   */
  static getMemoryCacheStats(): { size: number; keys: string[] } {
    return {
      size: Storage.memoryCache.size,
      keys: Array.from(Storage.memoryCache.keys()),
    };
  }
} 