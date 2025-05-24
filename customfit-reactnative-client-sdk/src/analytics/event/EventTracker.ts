import { CFResult } from '../../core/error/CFResult';
import { EventData, CFConfig } from '../../core/types/CFTypes';
import { HttpClient } from '../../network/HttpClient';
import { Storage } from '../../utils/Storage';
import { Logger } from '../../logging/Logger';
import { CFConstants } from '../../constants/CFConstants';
import { EventDataUtil, EventDataBuilder } from './EventData';
import { ConnectionMonitor } from '../../platform/ConnectionMonitor';
import { ErrorHandler, ErrorCategory, ErrorSeverity } from '../../core/error/ErrorHandler';
import { SummaryManager } from '../summary/SummaryManager';

/**
 * Event tracker for handling user events
 */
export class EventTracker {
  private static readonly SOURCE = 'EventTracker';
  
  private readonly config: CFConfig;
  private readonly httpClient: HttpClient;
  private readonly connectionMonitor: ConnectionMonitor;
  private readonly summaryManager?: SummaryManager;
  private eventQueue: EventData[] = [];
  private flushTimer: NodeJS.Timeout | null = null;
  private isRunning: boolean = false;
  private lastFlushTime: number = 0;

  constructor(config: CFConfig, httpClient: HttpClient, summaryManager?: SummaryManager) {
    this.config = config;
    this.httpClient = httpClient;
    this.connectionMonitor = ConnectionMonitor.getInstance();
    this.summaryManager = summaryManager;
    
    Logger.info(`🔔 TRACK: EventTracker initialized with queue size: ${config.eventsQueueSize}, flush interval: ${config.eventsFlushIntervalMs}ms`);
  }

  /**
   * Start the event tracker
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      Logger.debug('EventTracker: Already running');
      return;
    }

    // Load stored events from storage
    await this.loadStoredEvents();

    // Start periodic flush timer
    this.startFlushTimer();

    this.isRunning = true;
    Logger.info('🔔 EventTracker started');
  }

  /**
   * Stop the event tracker
   */
  async stop(): Promise<void> {
    if (!this.isRunning) {
      Logger.debug('EventTracker: Not running');
      return;
    }

    // Stop flush timer
    this.stopFlushTimer();

    // Flush remaining events before stopping
    await this.flush();

    // Store remaining events
    await this.storeEvents();

    this.isRunning = false;
    Logger.info('🔔 EventTracker stopped');
  }

  /**
   * Track an event
   */
  async track(eventData: EventData): Promise<CFResult<void>> {
    try {
      if (!EventDataUtil.validateEventData(eventData)) {
        const message = 'Invalid event data';
        ErrorHandler.handleError(
          message,
          EventTracker.SOURCE,
          ErrorCategory.VALIDATION,
          ErrorSeverity.MEDIUM
        );
        return CFResult.errorWithMessage(message);
      }

      // Add event to queue
      this.eventQueue.push(eventData);
      Logger.info(`🔔 TRACK: Event added to queue: ${eventData.name}, queue size=${this.eventQueue.length}`);

      // Check if we need to flush based on queue size
      if (this.eventQueue.length >= this.config.eventsQueueSize) {
        Logger.info('🔔 TRACK: Queue size limit reached, triggering flush');
        await this.flush();
      }

      return CFResult.successVoid();
    } catch (error) {
      ErrorHandler.handleException(
        error as Error,
        'Failed to track event',
        EventTracker.SOURCE,
        ErrorSeverity.MEDIUM
      );
      return CFResult.errorFromException(error as Error);
    }
  }

  /**
   * Track a simple event by name
   */
  async trackEvent(
    name: string,
    properties?: Record<string, any>,
    userId?: string,
    anonymousId?: string
  ): Promise<CFResult<void>> {
    try {
      Logger.info(`🔔 🔔 TRACK: Tracking event: ${name} with properties: ${JSON.stringify(properties || {})}`);
      
      // Flush summaries before tracking a new event (like other SDKs)
      if (this.summaryManager) {
        Logger.info(`🔔 🔔 TRACK: Flushing summaries before tracking event: ${name}`);
        const summaryResult = await this.summaryManager.flush();
        if (!summaryResult.isSuccess) {
          Logger.warning(`🔔 🔔 TRACK: Failed to flush summaries before tracking event: ${summaryResult.error?.message}`);
          ErrorHandler.handleError(
            `Failed to flush summaries before tracking event: ${summaryResult.error?.message}`,
            EventTracker.SOURCE,
            ErrorCategory.INTERNAL,
            ErrorSeverity.MEDIUM
          );
        }
      }
      
      if (!name || name.trim() === '') {
        const message = 'Event name cannot be blank';
        Logger.warning(`🔔 TRACK: Invalid event - ${message}`);
        ErrorHandler.handleError(
          message,
          EventTracker.SOURCE,
          ErrorCategory.VALIDATION,
          ErrorSeverity.MEDIUM
        );
        return CFResult.errorWithMessage(message);
      }

      const eventData = await EventDataUtil.createEvent(name, properties, userId, anonymousId);
      return await this.track(eventData);
    } catch (error) {
      ErrorHandler.handleException(
        error as Error,
        `Failed to track event '${name}'`,
        EventTracker.SOURCE,
        ErrorSeverity.MEDIUM
      );
      return CFResult.errorFromException(error as Error);
    }
  }



  /**
   * Flush all events to the server
   */
  async flush(): Promise<CFResult<number>> {
    // Always flush summaries first before flushing events (like other SDKs)
    if (this.summaryManager) {
      Logger.info('🔔 🔔 TRACK: Flushing summaries before flushing events');
      const summaryResult = await this.summaryManager.flush();
      if (!summaryResult.isSuccess) {
        Logger.warning(`🔔 🔔 TRACK: Failed to flush summaries before flushing events: ${summaryResult.error?.message}`);
        ErrorHandler.handleError(
          `Failed to flush summaries before flushing events: ${summaryResult.error?.message}`,
          EventTracker.SOURCE,
          ErrorCategory.INTERNAL,
          ErrorSeverity.MEDIUM
        );
      }
    }

    if (this.eventQueue.length === 0) {
      Logger.debug('🔔 TRACK: No events to flush');
      return CFResult.success(0);
    }

    // Check if we're connected
    if (!this.connectionMonitor.isConnected()) {
      Logger.debug('🔔 TRACK: No connection, storing events for later');
      await this.storeEvents();
      return CFResult.success(0);
    }

    const eventsToFlush = [...this.eventQueue];
    const flushCount = eventsToFlush.length;

    Logger.info(`🔔 TRACK HTTP: Preparing to send ${flushCount} events`);
    
    // Log individual events being sent
    eventsToFlush.forEach((event, index) => {
      Logger.debug(`🔔 TRACK HTTP: Event #${index + 1}: ${event.name}, properties=${Object.keys(event.properties || {}).join(',')}`);
    });

    try {
      // Prepare events for API
      const serializedEvents = eventsToFlush.map(event => EventDataUtil.serializeForAPI(event));
      const payload = {
        events: serializedEvents,
        batch_timestamp: new Date().toISOString(),
      };
      
      Logger.debug(`🔔 TRACK HTTP: Event payload size: ${JSON.stringify(payload).length} bytes`);
      Logger.debug(`🔔 TRACK HTTP: POST request to: ${CFConstants.Api.EVENTS_PATH}`);
      
      // Send to server
      const result = await this.httpClient.post(CFConstants.Api.EVENTS_PATH, payload);

      if (result.isSuccess) {
        // Remove flushed events from queue
        this.eventQueue = this.eventQueue.slice(flushCount);
        this.lastFlushTime = Date.now();
        
        Logger.info(`🔔 TRACK: Successfully flushed ${flushCount} events`);
        return CFResult.success(flushCount);
      } else {
        const errorMessage = `Failed to flush events: ${result.error?.message}`;
        Logger.error(`🔔 TRACK HTTP: ${errorMessage}`);
        
        ErrorHandler.handleError(
          errorMessage,
          EventTracker.SOURCE,
          ErrorCategory.NETWORK,
          ErrorSeverity.MEDIUM
        );
        
        // Store events for retry if we're offline
        if (!this.connectionMonitor.isConnected()) {
          await this.storeEvents();
        }
        
        return result.map(() => 0);
      }
    } catch (error) {
      const errorMessage = `Exception during flush: ${error}`;
      Logger.error(`🔔 TRACK HTTP: ${errorMessage}`);
      
      ErrorHandler.handleException(
        error as Error,
        'Failed to flush events',
        EventTracker.SOURCE,
        ErrorSeverity.MEDIUM
      );
      
      // Store events for retry
      await this.storeEvents();
      
      return CFResult.errorFromException(error as Error);
    }
  }

  /**
   * Get current queue size
   */
  getQueueSize(): number {
    return this.eventQueue.length;
  }

  /**
   * Get queue contents (for debugging)
   */
  getQueueContents(): EventData[] {
    return [...this.eventQueue];
  }

  /**
   * Clear all events from queue
   */
  clearQueue(): void {
    const clearedCount = this.eventQueue.length;
    this.eventQueue = [];
    Logger.warning(`🔔 EventTracker: Cleared ${clearedCount} events from queue`);
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
      Logger.warning('🔔 EventTracker: Flush interval must be greater than 0');
      return;
    }

    // Stop current timer and start with new interval
    this.stopFlushTimer();
    this.startFlushTimer();

    Logger.info(`🔔 EventTracker: Flush interval updated to ${intervalMs}ms`);
  }

  private startFlushTimer(): void {
    this.stopFlushTimer();
    
    this.flushTimer = setInterval(async () => {
      Logger.trace('🔔 EventTracker: Periodic flush triggered');
      await this.flush();
    }, this.config.eventsFlushIntervalMs);

    Logger.debug(`🔔 EventTracker: Flush timer started with interval ${this.config.eventsFlushIntervalMs}ms`);
  }

  private stopFlushTimer(): void {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
      this.flushTimer = null;
      Logger.debug('🔔 EventTracker: Flush timer stopped');
    }
  }

  private async loadStoredEvents(): Promise<void> {
    try {
      const result = await Storage.get<EventData[]>(CFConstants.Storage.EVENTS_KEY);
      
      if (result.isSuccess && result.data) {
        const storedEvents = result.data.map(data => EventDataUtil.deserializeFromStorage(data)).filter(Boolean) as EventData[];
        
        if (storedEvents.length > 0) {
          // Limit stored events to prevent memory issues
          const limitedEvents = storedEvents.slice(0, this.config.maxStoredEvents);
          this.eventQueue.push(...limitedEvents);
          
          Logger.info(`🔔 EventTracker: Loaded ${limitedEvents.length} stored events`);
          
          // Clear storage after loading
          await Storage.remove(CFConstants.Storage.EVENTS_KEY);
        }
      }
    } catch (error) {
      Logger.error(`EventTracker: Failed to load stored events: ${error}`);
    }
  }

  private async storeEvents(): Promise<void> {
    if (this.eventQueue.length === 0) {
      return;
    }

    try {
      // Limit stored events to prevent storage bloat
      const eventsToStore = this.eventQueue.slice(0, this.config.maxStoredEvents);
      const serializedEvents = eventsToStore.map(event => EventDataUtil.serializeForAPI(event));
      
      const result = await Storage.set(CFConstants.Storage.EVENTS_KEY, serializedEvents);
      
      if (result.isSuccess) {
        Logger.debug(`🔔 EventTracker: Stored ${eventsToStore.length} events for later transmission`);
      } else {
        Logger.error(`EventTracker: Failed to store events: ${result.error?.message}`);
      }
    } catch (error) {
      Logger.error(`EventTracker: Exception storing events: ${error}`);
    }
  }
} 