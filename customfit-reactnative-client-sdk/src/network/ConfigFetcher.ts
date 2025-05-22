import { CFResult } from '../core/error/CFResult';
import { ErrorCategory, CFConfig, SdkSettings } from '../core/types/CFTypes';
import { HttpClient } from './HttpClient';
import { Storage } from '../utils/Storage';
import { Logger } from '../logging/Logger';
import { CFConstants } from '../constants/CFConstants';

/**
 * Configuration fetcher for getting user configs and SDK settings
 */
export class ConfigFetcher {
  private readonly config: CFConfig;
  private readonly httpClient: HttpClient;
  private readonly sdkSettingsHttpClient: HttpClient;

  constructor(config: CFConfig) {
    this.config = config;
    
    // HTTP client for main API
    this.httpClient = new HttpClient(
      CFConstants.Api.BASE_API_URL,
      config.networkConnectionTimeoutMs
    );

    // HTTP client for SDK settings
    this.sdkSettingsHttpClient = new HttpClient(
      CFConstants.Api.SDK_SETTINGS_BASE_URL,
      CFConstants.Network.SDK_SETTINGS_TIMEOUT_MS
    );

    Logger.debug('📡 ConfigFetcher initialized');
  }

  /**
   * Fetch user configurations
   */
  async fetchUserConfigs(userToken: string, lastModified?: string, etag?: string): Promise<CFResult<{
    configs: Record<string, any>;
    metadata: {
      lastModified?: string;
      etag?: string;
      timestamp: number;
    };
  }>> {
    try {
      Logger.info('📡 API POLL: Fetching user configurations...');
      
      const headers: Record<string, string> = {
        'Authorization': `Bearer ${userToken}`,
      };

      // Add conditional headers for caching
      if (lastModified) {
        headers[CFConstants.Http.HEADER_IF_MODIFIED_SINCE] = lastModified;
      }
      if (etag) {
        headers[CFConstants.Http.HEADER_IF_NONE_MATCH] = etag;
      }

      const result = await this.httpClient.get(CFConstants.Api.USER_CONFIGS_PATH, headers);

      if (result.isError) {
        Logger.error(`📡 API POLL: Failed to fetch user configs: ${result.error?.message}`);
        return result;
      }

      const response = result.data!;
      
      // Handle 304 Not Modified
      if (response.status === 304) {
        Logger.info('📡 API POLL: User configs not modified (304)');
        return CFResult.errorWithMessage('Not modified', ErrorCategory.NETWORK);
      }

      if (response.status !== 200) {
        Logger.error(`📡 API POLL: Unexpected status code: ${response.status}`);
        return CFResult.errorWithMessage(`HTTP ${response.status}: ${response.statusText}`, ErrorCategory.NETWORK);
      }

      // Parse response
      const configs = response.data || {};
      const responseHeaders = response.headers;

      const metadata = {
        lastModified: responseHeaders[CFConstants.Http.HEADER_LAST_MODIFIED.toLowerCase()],
        etag: responseHeaders[CFConstants.Http.HEADER_ETAG.toLowerCase()],
        timestamp: Date.now(),
      };

      Logger.info(`📡 API POLL: Retrieved ${Object.keys(configs).length} configuration entries`);
      Logger.debug(`📡 API POLL: Config keys: ${Object.keys(configs).join(', ')}`);

      return CFResult.success({
        configs,
        metadata,
      });
    } catch (error) {
      Logger.error(`📡 API POLL: Exception during config fetch: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.NETWORK);
    }
  }

  /**
   * Check SDK settings (HEAD request followed by GET if needed)
   */
  async checkSdkSettings(dimensionId: string): Promise<CFResult<SdkSettings | null>> {
    if (!dimensionId) {
      return CFResult.errorWithMessage('Dimension ID is required', ErrorCategory.VALIDATION);
    }

    try {
      const settingsPath = CFConstants.Api.SDK_SETTINGS_PATH_PATTERN.replace('%s', dimensionId);
      
      Logger.debug(`📡 API POLL: Checking SDK settings with HEAD request for ${dimensionId}`);
      
      // First try HEAD request to check if settings exist
      const headResult = await this.sdkSettingsHttpClient.head(settingsPath);
      
      if (headResult.isError) {
        Logger.debug(`📡 API POLL: HEAD request failed: ${headResult.error?.message}`);
        // If HEAD fails, try GET request directly
        return await this.fetchSdkSettings(dimensionId);
      }

      const headResponse = headResult.data!;
      
      if (headResponse.status === 404) {
        Logger.info('📡 API POLL: SDK settings not found (404)');
        return CFResult.success(null);
      }

      if (headResponse.status === 200) {
        Logger.debug('📡 API POLL: SDK settings found, fetching with GET request');
        return await this.fetchSdkSettings(dimensionId);
      }

      Logger.warning(`📡 API POLL: Unexpected HEAD response status: ${headResponse.status}`);
      return await this.fetchSdkSettings(dimensionId);
    } catch (error) {
      Logger.error(`📡 API POLL: Exception during SDK settings check: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.NETWORK);
    }
  }

  /**
   * Fetch SDK settings (GET request)
   */
  async fetchSdkSettings(dimensionId: string): Promise<CFResult<SdkSettings | null>> {
    try {
      const settingsPath = CFConstants.Api.SDK_SETTINGS_PATH_PATTERN.replace('%s', dimensionId);
      
      Logger.debug(`📡 API POLL: Fetching SDK settings with GET request for ${dimensionId}`);
      
      const result = await this.sdkSettingsHttpClient.get(settingsPath);
      
      if (result.isError) {
        Logger.error(`📡 API POLL: Failed to fetch SDK settings: ${result.error?.message}`);
        return result;
      }

      const response = result.data!;
      
      if (response.status === 404) {
        Logger.info('📡 API POLL: SDK settings not found (404)');
        return CFResult.success(null);
      }

      if (response.status !== 200) {
        Logger.error(`📡 API POLL: Unexpected GET response status: ${response.status}`);
        return CFResult.errorWithMessage(`HTTP ${response.status}: ${response.statusText}`, ErrorCategory.NETWORK);
      }

      // Parse SDK settings
      const settingsData = response.data;
      const sdkSettings: SdkSettings = {
        cf_account_enabled: settingsData?.cf_account_enabled ?? true,
        cf_skip_sdk: settingsData?.cf_skip_sdk ?? false,
      };

      Logger.info(`📡 API POLL: SDK settings retrieved - account_enabled: ${sdkSettings.cf_account_enabled}, skip_sdk: ${sdkSettings.cf_skip_sdk}`);
      
      return CFResult.success(sdkSettings);
    } catch (error) {
      Logger.error(`📡 API POLL: Exception during SDK settings fetch: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.NETWORK);
    }
  }

  /**
   * Get cached user configurations
   */
  async getCachedUserConfigs(): Promise<CFResult<{
    configs: Record<string, any>;
    metadata: {
      lastModified?: string;
      etag?: string;
      timestamp: number;
    };
  } | null>> {
    try {
      const configResult = await Storage.getWithTTL<Record<string, any>>(CFConstants.Storage.CONFIG_KEY);
      const metadataResult = await Storage.get<any>(CFConstants.Storage.METADATA_KEY);

      if (configResult.isError || metadataResult.isError) {
        return CFResult.success(null);
      }

      if (!configResult.data || !metadataResult.data) {
        return CFResult.success(null);
      }

      Logger.debug('📡 ConfigFetcher: Retrieved cached user configs');
      
      return CFResult.success({
        configs: configResult.data,
        metadata: metadataResult.data,
      });
    } catch (error) {
      Logger.error(`ConfigFetcher: Failed to get cached configs: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Cache user configurations
   */
  async cacheUserConfigs(
    configs: Record<string, any>,
    metadata: {
      lastModified?: string;
      etag?: string;
      timestamp: number;
    }
  ): Promise<CFResult<void>> {
    try {
      // Cache configs with TTL
      const configResult = await Storage.setWithTTL(
        CFConstants.Storage.CONFIG_KEY,
        configs,
        CFConstants.Cache.DEFAULT_TTL_MS
      );

      // Cache metadata separately (no TTL)
      const metadataResult = await Storage.set(CFConstants.Storage.METADATA_KEY, metadata);

      if (configResult.isError) {
        return configResult;
      }

      if (metadataResult.isError) {
        return metadataResult;
      }

      Logger.debug('📡 ConfigFetcher: Cached user configs and metadata');
      return CFResult.successVoid();
    } catch (error) {
      Logger.error(`ConfigFetcher: Failed to cache configs: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Clear cached configurations
   */
  async clearCache(): Promise<CFResult<void>> {
    try {
      await Storage.remove(CFConstants.Storage.CONFIG_KEY);
      await Storage.remove(CFConstants.Storage.METADATA_KEY);
      
      Logger.info('📡 ConfigFetcher: Cleared configuration cache');
      return CFResult.successVoid();
    } catch (error) {
      Logger.error(`ConfigFetcher: Failed to clear cache: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.INTERNAL);
    }
  }

  /**
   * Get HTTP client health status
   */
  isHealthy(): boolean {
    return this.httpClient.isHealthy() && this.sdkSettingsHttpClient.isHealthy();
  }
} 