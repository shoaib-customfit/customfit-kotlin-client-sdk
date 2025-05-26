import { CFResult } from '../../core/error/CFResult';
import { CFConfig } from '../../core/types/CFTypes';
import { HttpClient } from '../../network/HttpClient';
import { Storage } from '../../utils/Storage';
import { Logger } from '../../logging/Logger';
import { CFConstants } from '../../constants/CFConstants';
import { CFConfigRequestSummary, CFConfigRequestSummaryUtil } from './CFConfigRequestSummary';
import { ConnectionMonitor } from '../../platform/ConnectionMonitor';

/**
 * Summary manager for tracking config request summaries
 * Matches the functionality of Flutter and Kotlin SDKs
 */
export class SummaryManager {
  private readonly sessionId: string;
  private readonly httpClient: HttpClient;
  private currentUser: any;
  private readonly config: CFConfig;
  private readonly connectionMonitor: ConnectionMonitor;

  private readonly queueSize: number;
  private flushIntervalMs: number;
  private readonly flushTimeSeconds: number;

  private readonly summaries: CFConfigRequestSummary[] = [];
  private readonly trackMap: Map<string, boolean> = new Map();
  private flushTimer: NodeJS.Timeout | null = null;

  constructor(
    sessionId: string,
    httpClient: HttpClient,
    user: any,
    config: CFConfig
  ) {
    this.sessionId = sessionId;
    this.httpClient = httpClient;
    this.currentUser = user;
    this.config = config;
    this.connectionMonitor = ConnectionMonitor.getInstance();
    
    this.queueSize = config.summariesQueueSize || CFConstants.SummaryDefaults.QUEUE_SIZE;
    this.flushIntervalMs = config.summariesFlushIntervalMs || CFConstants.SummaryDefaults.FLUSH_INTERVAL_MS;
    this.flushTimeSeconds = config.summariesFlushTimeSeconds || CFConstants.SummaryDefaults.FLUSH_TIME_SECONDS;

    Logger.info(`📊 SummaryManager initialized with queueSize=${this.queueSize}, flushIntervalMs=${this.flushIntervalMs}, flushTimeSeconds=${this.flushTimeSeconds}`);
    this.startPeriodicFlush();
  }

  /**
   * Update the flush interval - matches Kotlin SDK
   */
  updateFlushInterval(intervalMs: number): CFResult<number> {
    try {
      if (intervalMs <= 0) {
        throw new Error('Interval must be greater than 0');
      }

      this.flushIntervalMs = intervalMs;
      this.restartPeriodicFlush();
      Logger.info(`📊 SUMMARY: Updated summaries flush interval to ${intervalMs} ms`);
      return CFResult.success(intervalMs);
    } catch (error) {
      Logger.error(`Failed to update flush interval to ${intervalMs}: ${error}`);
      return CFResult.errorFromException(error as Error);
    }
  }

  /**
   * Adds a configuration summary to the queue - matches Flutter SDK
   */
  async pushSummary(config: Record<string, any>): Promise<CFResult<boolean>> {
    // Log the config being processed
    Logger.info(`📊 SUMMARY: Processing summary for config: ${config.key || 'unknown'}`);

    // Validate input is a map
    if (typeof config !== 'object' || config === null) {
      const message = `Config is not an object: ${config}`;
      Logger.warning(`📊 SUMMARY: ${message}`);
      return CFResult.errorWithMessage(message);
  }

    // Validate required fields
    const experienceId = config.experience_id as string;
    if (!experienceId) {
      const message = 'Missing mandatory experience_id in config';
      Logger.warning(`📊 SUMMARY: ${message}, summary not tracked`);
      return CFResult.errorWithMessage(message);
    }

    const configId = config.config_id as string;
    const variationId = config.variation_id as string;
    const version = config.version?.toString();

    const missingFields: string[] = [];
    if (!configId) missingFields.push('config_id');
    if (!variationId) missingFields.push('variation_id');
    if (!version) missingFields.push('version');

    if (missingFields.length > 0) {
      const message = `Missing mandatory fields for summary: ${missingFields.join(', ')}`;
      Logger.warning(`📊 SUMMARY: ${message}, summary not tracked`);
      return CFResult.errorWithMessage(message);
    }

    // Prevent duplicates
    if (this.trackMap.has(experienceId)) {
      Logger.debug(`📊 SUMMARY: Experience already processed: ${experienceId}`);
      return CFResult.success(true);
    }

    this.trackMap.set(experienceId, true);

    const summary = CFConfigRequestSummaryUtil.fromConfig(
      config,
      this.currentUser?.userCustomerId || '',
      this.sessionId
    );

    Logger.info(`📊 SUMMARY: Created summary for experience: ${experienceId}, config: ${configId}`);

    // Check if queue is full
    if (this.summaries.length >= this.queueSize) {
      Logger.warning('📊 SUMMARY: Queue full, forcing flush for new entry');
      await this.flushSummaries();

      if (this.summaries.length >= this.queueSize) {
        Logger.error('📊 SUMMARY: Failed to queue summary after flush');
        return CFResult.errorWithMessage('Queue still full after flush');
      }
    }

    this.summaries.push(summary);
    Logger.info(`📊 SUMMARY: Added to queue: experience=${experienceId}, queue size=${this.summaries.length}`);

    // Check if queue size threshold is reached
    if (this.summaries.length >= this.queueSize) {
      Logger.info(`📊 SUMMARY: Queue size threshold reached (${this.summaries.length}/${this.queueSize}), triggering flush`);
      this.flushSummaries();
    }

    return CFResult.success(true);
  }

  /**
   * Flushes collected summaries to the server - matches Flutter/Kotlin SDK
   */
  async flushSummaries(): Promise<CFResult<number>> {
    if (this.summaries.length === 0) {
      Logger.debug('📊 SUMMARY: No summaries to flush');
      return CFResult.success(0);
    }

    const summariesToFlush = this.summaries.splice(0); // Drain the queue
    
    if (summariesToFlush.length === 0) {
      Logger.debug('📊 SUMMARY: No summaries to flush after drain');
      return CFResult.success(0);
    }

    Logger.info(`📊 SUMMARY: Flushing ${summariesToFlush.length} summaries to server`);

    try {
      const result = await this.sendSummaryToServer(summariesToFlush);
      if (result.isSuccess) {
        Logger.info(`📊 SUMMARY: Successfully flushed ${summariesToFlush.length} summaries to server`);
        return CFResult.success(summariesToFlush.length);
      } else {
        Logger.warning(`📊 SUMMARY: Failed to flush summaries: ${result.error?.message}`);
        return CFResult.errorWithMessage(`Failed to flush summaries: ${result.error?.message}`);
      }
    } catch (error) {
      Logger.error(`📊 SUMMARY: Unexpected error during summary flush: ${error}`);
      return CFResult.errorFromException(error as Error);
    }
  }

  /**
   * Create user payload matching the backend's CreateUserRequest DTO.
   */
  private createUserPayloadAlignedWithDTO(): Record<string, any> {
    const currentUser = this.currentUser as any; // Cast for type flexibility
    
    const properties: Record<string, any> = { ...(currentUser?.properties || {}) };

    // Add device to properties, attempting to match cURL/simplified structure first
    // If currentUser.device is richer and has toMap(), that could be used if backend expects it.
    if (currentUser?.device && typeof currentUser.device.toMap === 'function') {
        properties.device = currentUser.device.toMap(); 
    } else if (currentUser?.device) { // Simple object case
        properties.device = currentUser.device;
    } else {
        // Default device properties if nothing specific on currentUser
        // This matches the simplified structure from cURL, good for basic info
        properties.device = {
            os_name: "React Native", // Or Platform.OS
            sdk_type: "react-native",
            sdk_version: CFConstants.General.DEFAULT_SDK_VERSION
        };
  }
    // Ensure platform is in properties, as per cURL and common practice
    if (!properties.platform) {
        properties.platform = "React Native";
    }

    const userPayload: Record<string, any> = {
      anonymous: currentUser?.anonymous ?? false, // DTO default is false
      user_customer_id: currentUser?.userCustomerId || null,
      properties: properties,
      // hs_fields, private_fields, session_fields are omitted as per DTO defaults (empty/null)
      // and not typically part of basic summary user context.
    };

    // Clean null/undefined values from the top level of userPayload
    Object.keys(userPayload).forEach(key => {
      if (userPayload[key] === null || userPayload[key] === undefined) {
        delete userPayload[key];
  }
    });
    // Also clean properties specifically, as it's a map that DTO initializes to empty if not given
    if (userPayload.properties) {
        Object.keys(userPayload.properties).forEach(key => {
            if (userPayload.properties[key] === null || userPayload.properties[key] === undefined) {
                delete userPayload.properties[key];
            }
        });
        // If properties becomes empty after cleaning, remove it only if backend prefers absence
        // Given DTO defaults to new HashMap<>(), an empty {} should be fine.
    }

    return userPayload;
  }

  /**
   * Sends summary data to the server
   */
  private async sendSummaryToServer(summaries: CFConfigRequestSummary[]): Promise<CFResult<boolean>> {
    Logger.info(`📊 SUMMARY HTTP: Preparing to send ${summaries.length} summaries`);

    summaries.forEach((summary, index) => {
      Logger.debug(`📊 SUMMARY HTTP: Summary #${index + 1}: experience_id=${summary.experience_id}, config_id=${summary.config_id}, version=${summary.version}`);
    });

    const userMap = this.createUserPayloadAlignedWithDTO();
    const summariesMap = summaries.map(summary => CFConfigRequestSummaryUtil.toMap(summary));
    
    const payload = {
      user: userMap,
      summaries: summariesMap,
      cf_client_sdk_version: CFConstants.General.DEFAULT_SDK_VERSION,
    };

    // Log payload details for debugging
    Logger.debug(`📊 SUMMARY HTTP: User payload: ${JSON.stringify(userMap)}`);
    Logger.debug(`📊 SUMMARY HTTP: Summaries payload: ${JSON.stringify(summariesMap)}`);
    Logger.debug(`📊 SUMMARY HTTP: Full payload: ${JSON.stringify(payload)}`);

    // Use relative path since HttpClient already has the base URL
    const url = `/v1/config/request/summary?cfenc=${this.config.clientKey}`;

    Logger.info(`📊 SUMMARY: Sending ${summaries.length} summaries to server`);

    try {
      const result = await this.httpClient.post(url, payload);

      if (result.isSuccess && (result.data?.status === 200 || result.data?.status === 202)) {
        Logger.info(`📊 SUMMARY HTTP: Response code: ${result.data.status}`);
        Logger.info('📊 SUMMARY HTTP: Summary successfully sent to server');
        return CFResult.success(true);
      } else {
        const errorBody = result.data?.data || result.error?.message || 'No error body';
        Logger.warning(`📊 SUMMARY HTTP: Error code: ${result.data?.status || 'unknown'}`);
        Logger.warning(`📊 SUMMARY HTTP: Error body: ${errorBody}`);
        
        // Re-queue summaries on failure if we're offline
        if (!this.connectionMonitor.isConnected()) {
          this.handleSendFailure(summaries);
        }
        
        return CFResult.errorWithMessage(`API error response: ${result.data?.status || 'unknown'}`);
      }
    } catch (error) {
      Logger.error(`📊 SUMMARY HTTP: Exception: ${error}`);
      this.handleSendFailure(summaries);
      return CFResult.errorFromException(error as Error);
    }
  }

  /**
   * Helper method to handle send failures by re-queueing items
   */
  private handleSendFailure(summaries: CFConfigRequestSummary[]): void {
    Logger.warning(`📊 SUMMARY: Failed to send ${summaries.length} summaries after retries, re-queuing`);
    let requeueFailCount = 0;

    summaries.forEach(summary => {
      if (this.summaries.length >= this.queueSize) {
        requeueFailCount++;
      } else {
        this.summaries.push(summary);
      }
    });

    if (requeueFailCount > 0) {
      Logger.error(`📊 SUMMARY: Failed to re-queue ${requeueFailCount} summaries after send failure`);
  }
  }

  /**
   * Starts the periodic flush timer
   */
  private startPeriodicFlush(): void {
    try {
      // Cancel existing timer
    this.stopFlushTimer();
    
      // Create new timer
    this.flushTimer = setInterval(async () => {
        try {
          Logger.debug('📊 SUMMARY: Periodic flush triggered for summaries');
          await this.flushSummaries();
        } catch (error) {
          Logger.error(`📊 SUMMARY: Error during periodic summary flush: ${error}`);
        }
      }, this.flushIntervalMs);

      Logger.debug(`📊 SUMMARY: Started periodic summary flush with interval ${this.flushIntervalMs} ms`);
    } catch (error) {
      Logger.error(`📊 SUMMARY: Failed to start periodic summary flush: ${error}`);
    }
  }

  /**
   * Restarts the periodic flush timer with the current interval
   */
  private restartPeriodicFlush(): void {
    try {
      this.startPeriodicFlush();
      Logger.debug(`📊 SUMMARY: Restarted periodic flush with interval ${this.flushIntervalMs} ms`);
    } catch (error) {
      Logger.error(`📊 SUMMARY: Failed to restart periodic summary flush: ${error}`);
    }
  }

  /**
   * Stop the flush timer
   */
  private stopFlushTimer(): void {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
      this.flushTimer = null;
      Logger.debug('📊 SUMMARY: Flush timer stopped');
    }
  }

  /**
   * Returns all tracked summaries for debugging
   */
  getSummaries(): Map<string, boolean> {
    return new Map(this.trackMap);
        }

  /**
   * Get the current queue size
   */
  getQueueSize(): number {
    return this.summaries.length;
  }

  /**
   * Shutdown method to clean up timers
   */
  shutdown(): void {
    this.stopFlushTimer();
    Logger.info('📊 SummaryManager shutdown complete');
  }
} 