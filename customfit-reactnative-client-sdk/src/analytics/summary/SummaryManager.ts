import { CFResult } from '../../core/error/CFResult';
import { SummaryData, CFConfig } from '../../core/types/CFTypes';
import { HttpClient } from '../../network/HttpClient';
import { Storage } from '../../utils/Storage';
import { Logger } from '../../logging/Logger';
import { CFConstants } from '../../constants/CFConstants';
import { SummaryDataUtil, SummaryAggregator } from './SummaryData';
import { ConnectionMonitor } from '../../platform/ConnectionMonitor';

/**
 * Summary manager for tracking aggregated usage data
 */
export class SummaryManager {
  private readonly config: CFConfig;
  private readonly httpClient: HttpClient;
  private readonly connectionMonitor: ConnectionMonitor;
  private readonly aggregator: SummaryAggregator = new SummaryAggregator();
  private flushTimer: NodeJS.Timeout | null = null;
  private isRunning: boolean = false;
  private lastFlushTime: number = 0;

  constructor(config: CFConfig, httpClient: HttpClient) {
    this.config = config;
    this.httpClient = httpClient;
    this.connectionMonitor = ConnectionMonitor.getInstance();
    
    Logger.info(`📊 SummaryManager initialized with flush interval: ${config.summariesFlushIntervalMs}ms`);
  }

  /**
   * Start the summary manager
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      Logger.debug('SummaryManager: Already running');
      return;
    }

    // Load stored summaries from storage
    await this.loadStoredSummaries();

    // Start periodic flush timer
    this.startFlushTimer();

    this.isRunning = true;
    Logger.info('📊 SummaryManager started');
  }

  /**
   * Stop the summary manager
   */
  async stop(): Promise<void> {
    if (!this.isRunning) {
      Logger.debug('SummaryManager: Not running');
      return;
    }

    // Stop flush timer
    this.stopFlushTimer();

    // Flush remaining summaries before stopping
    await this.flush();

    // Store remaining summaries
    await this.storeSummaries();

    this.isRunning = false;
    Logger.info('📊 SummaryManager stopped');
  }

  /**
   * Track a summary
   */
  trackSummary(summaryData: SummaryData): CFResult<void> {
    try {
      if (!SummaryDataUtil.validateSummaryData(summaryData)) {
        return CFResult.errorWithMessage('Invalid summary data');
      }

      this.aggregator.addSummary(summaryData);
      Logger.debug(`📊 SUMMARY: Tracked '${summaryData.name}' with count ${summaryData.count} (total summaries: ${this.aggregator.getCount()})`);

      return CFResult.successVoid();
    } catch (error) {
      Logger.error(`SummaryManager: Failed to track summary: ${error}`);
      return CFResult.errorFromException(error as Error);
    }
  }

  /**
   * Track a simple summary by name
   */
  trackSummaryByName(name: string, count: number = 1, properties?: Record<string, any>): CFResult<void> {
    const summaryData = SummaryDataUtil.createSummary(name, count, properties);
    return this.trackSummary(summaryData);
  }

  /**
   * Track config access summary
   */
  trackConfigAccess(configKey: string, value: any): CFResult<void> {
    const summaryData = SummaryDataUtil.createSummary(
      'config_access',
      1,
      {
        config_key: configKey,
        config_value: String(value),
      }
    );
    return this.trackSummary(summaryData);
  }

  /**
   * Track feature flag access summary
   */
  trackFeatureFlagAccess(flagKey: string, value: any): CFResult<void> {
    const summaryData = SummaryDataUtil.createSummary(
      'feature_flag_access',
      1,
      {
        flag_key: flagKey,
        flag_value: String(value),
      }
    );
    return this.trackSummary(summaryData);
  }

  /**
   * Flush all summaries to the server
   */
  async flush(): Promise<CFResult<number>> {
    if (this.aggregator.isEmpty()) {
      Logger.trace('📊 SummaryManager: No summaries to flush');
      return CFResult.success(0);
    }

    // Check if we're connected
    if (!this.connectionMonitor.isConnected()) {
      Logger.debug('📊 SummaryManager: No connection, storing summaries for later');
      await this.storeSummaries();
      return CFResult.success(0);
    }

    const summariesToFlush = this.aggregator.getSummaries();
    const flushCount = summariesToFlush.length;

    Logger.info(`📊 SUMMARY: Flushing ${flushCount} summaries to server`);

    try {
      // Prepare summaries for API
      const serializedSummaries = summariesToFlush.map(summary => SummaryDataUtil.serializeForAPI(summary));
      
      // Send to server
      const result = await this.httpClient.post(CFConstants.Api.SUMMARIES_PATH, {
        summaries: serializedSummaries,
        batch_timestamp: new Date().toISOString(),
        total_count: this.aggregator.getTotalCount(),
      });

      if (result.isSuccess) {
        // Clear flushed summaries
        this.aggregator.clear();
        this.lastFlushTime = Date.now();
        
        Logger.info(`📊 SUMMARY: Successfully flushed ${flushCount} summaries`);
        return CFResult.success(flushCount);
      } else {
        Logger.error(`📊 SUMMARY: Failed to flush summaries: ${result.error?.message}`);
        
        // Store summaries for retry if we're offline
        if (!this.connectionMonitor.isConnected()) {
          await this.storeSummaries();
        }
        
        return result.map(() => 0);
      }
    } catch (error) {
      Logger.error(`📊 SUMMARY: Exception during flush: ${error}`);
      
      // Store summaries for retry
      await this.storeSummaries();
      
      return CFResult.errorFromException(error as Error);
    }
  }

  /**
   * Get current summary count
   */
  getSummaryCount(): number {
    return this.aggregator.getCount();
  }

  /**
   * Get total count across all summaries
   */
  getTotalCount(): number {
    return this.aggregator.getTotalCount();
  }

  /**
   * Get all current summaries (for debugging)
   */
  getCurrentSummaries(): SummaryData[] {
    return this.aggregator.getSummaries();
  }

  /**
   * Get a specific summary by name
   */
  getSummary(name: string): SummaryData | undefined {
    return this.aggregator.getSummary(name);
  }

  /**
   * Clear all summaries
   */
  clearSummaries(): void {
    const clearedCount = this.aggregator.getCount();
    this.aggregator.clear();
    Logger.warning(`📊 SummaryManager: Cleared ${clearedCount} summaries`);
  }

  /**
   * Get last flush time
   */
  getLastFlushTime(): number {
    return this.lastFlushTime;
  }

  /**
   * Update flush interval (matches Kotlin SDK)
   */
  updateFlushInterval(intervalMs: number): void {
    if (intervalMs <= 0) {
      Logger.warning('📊 SummaryManager: Flush interval must be greater than 0');
      return;
    }

    // Stop current timer and start with new interval
    this.stopFlushTimer();
    this.startFlushTimer();

    Logger.info(`📊 SummaryManager: Flush interval updated to ${intervalMs}ms`);
  }

  private startFlushTimer(): void {
    this.stopFlushTimer();
    
    this.flushTimer = setInterval(async () => {
      Logger.trace('📊 SummaryManager: Periodic flush triggered');
      await this.flush();
    }, this.config.summariesFlushIntervalMs);

    Logger.debug(`📊 SummaryManager: Flush timer started with interval ${this.config.summariesFlushIntervalMs}ms`);
  }

  private stopFlushTimer(): void {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
      this.flushTimer = null;
      Logger.debug('📊 SummaryManager: Flush timer stopped');
    }
  }

  private async loadStoredSummaries(): Promise<void> {
    try {
      const result = await Storage.get<SummaryData[]>(CFConstants.Storage.SUMMARIES_KEY);
      
      if (result.isSuccess && result.data) {
        const storedSummaries = result.data.map(data => SummaryDataUtil.deserializeFromStorage(data)).filter(Boolean) as SummaryData[];
        
        if (storedSummaries.length > 0) {
          this.aggregator.addSummaries(storedSummaries);
          
          Logger.info(`📊 SummaryManager: Loaded ${storedSummaries.length} stored summaries`);
          
          // Clear storage after loading
          await Storage.remove(CFConstants.Storage.SUMMARIES_KEY);
        }
      }
    } catch (error) {
      Logger.error(`SummaryManager: Failed to load stored summaries: ${error}`);
    }
  }

  private async storeSummaries(): Promise<void> {
    if (this.aggregator.isEmpty()) {
      return;
    }

    try {
      const summariesToStore = this.aggregator.getSummaries();
      const serializedSummaries = summariesToStore.map(summary => SummaryDataUtil.serializeForAPI(summary));
      
      const result = await Storage.set(CFConstants.Storage.SUMMARIES_KEY, serializedSummaries);
      
      if (result.isSuccess) {
        Logger.debug(`📊 SummaryManager: Stored ${summariesToStore.length} summaries for later transmission`);
      } else {
        Logger.error(`SummaryManager: Failed to store summaries: ${result.error?.message}`);
      }
    } catch (error) {
      Logger.error(`SummaryManager: Exception storing summaries: ${error}`);
    }
  }
} 