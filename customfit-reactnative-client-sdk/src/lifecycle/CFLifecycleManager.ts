import { CFClient } from '../client/CFClient';
import { CFConfig } from '../core/types/CFTypes';
import { CFUserImpl } from '../core/model/CFUser';
import { AppStateManager } from '../platform/AppStateManager';
import { Logger } from '../logging/Logger';

type CFUser = CFUserImpl;

/**
 * Lifecycle manager for the CustomFit React Native SDK
 * Manages initialization, app state transitions, and cleanup
 */
export class CFLifecycleManager {
  private static instance: CFLifecycleManager | null = null;
  private client: CFClient | null = null;
  private config: CFConfig;
  private user: CFUser;
  private appStateManager: AppStateManager;
  private isInitialized: boolean = false;

  private constructor(config: CFConfig, user: CFUser) {
    this.config = config;
    this.user = user;
    this.appStateManager = AppStateManager.getInstance();
  }

  /**
   * Initialize the CFClient with lifecycle management
   */
  static async initialize(config: CFConfig, user: CFUser): Promise<CFLifecycleManager> {
    if (CFLifecycleManager.instance) {
      Logger.warning('CFLifecycleManager already initialized, returning existing instance');
      return CFLifecycleManager.instance;
    }

    const manager = new CFLifecycleManager(config, user);
    await manager.init();
    
    CFLifecycleManager.instance = manager;
    return manager;
  }

  /**
   * Get the singleton instance
   */
  static getInstance(): CFLifecycleManager | null {
    return CFLifecycleManager.instance;
  }

  /**
   * Get the current CFClient instance
   */
  getClient(): CFClient | null {
    return this.client;
  }

  /**
   * Update the user for the SDK
   */
  setUser(user: CFUser): void {
    this.user = user;
    if (this.client) {
      this.client.setUser(user);
      Logger.info('CFLifecycleManager: User updated');
    }
  }

  /**
   * Update user attributes
   */
  setUserAttribute(key: string, value: any): void {
    this.user = this.user.withProperty(key, value);
    if (this.client) {
      this.client.addUserProperty(key, value);
      Logger.debug(`CFLifecycleManager: User attribute set: ${key} = ${value}`);
    }
  }

  /**
   * Update multiple user attributes
   */
  setUserAttributes(attributes: Record<string, any>): void {
    this.user = this.user.withProperties(attributes);
    if (this.client) {
      this.client.addUserProperties(attributes);
      Logger.debug(`CFLifecycleManager: User attributes set: ${Object.keys(attributes).join(', ')}`);
    }
  }

  /**
   * Put the client in offline mode
   */
  setOffline(): void {
    if (this.client) {
      this.client.setOfflineMode(true);
      Logger.info('CFLifecycleManager: Client set to offline mode');
    }
  }

  /**
   * Put the client in online mode
   */
  setOnline(): void {
    if (this.client) {
      this.client.setOfflineMode(false);
      Logger.info('CFLifecycleManager: Client set to online mode');
    }
  }

  /**
   * Force refresh configurations
   */
  async forceRefresh(): Promise<void> {
    if (this.client) {
      const result = await this.client.forceRefresh();
      if (result.isSuccess) {
        Logger.info('CFLifecycleManager: Force refresh completed successfully');
      } else {
        Logger.error(`CFLifecycleManager: Force refresh failed: ${result.error?.message}`);
      }
    }
  }

  /**
   * Flush all pending events
   */
  async flushEvents(): Promise<void> {
    if (this.client) {
      const result = await this.client.flushEvents();
      if (result.isSuccess) {
        Logger.info(`CFLifecycleManager: Flushed ${result.data} events`);
      } else {
        Logger.error(`CFLifecycleManager: Failed to flush events: ${result.error?.message}`);
      }
    }
  }

  /**
   * Flush all pending summaries
   */
  async flushSummaries(): Promise<void> {
    if (this.client) {
      const result = await this.client.flushSummaries();
      if (result.isSuccess) {
        Logger.info(`CFLifecycleManager: Flushed ${result.data} summaries`);
      } else {
        Logger.error(`CFLifecycleManager: Failed to flush summaries: ${result.error?.message}`);
      }
    }
  }

  /**
   * Pause SDK operations (typically called when app goes to background)
   */
  async pause(): Promise<void> {
    if (!this.isInitialized || !this.client) {
      return;
    }

    try {
      // Flush pending data before pausing
      await this.flushEvents();
      await this.flushSummaries();

      // Pause the client
      this.client.pause();

      Logger.info('CFLifecycleManager: SDK paused');
    } catch (error) {
      Logger.error(`CFLifecycleManager: Error during pause: ${error}`);
    }
  }

  /**
   * Resume SDK operations (typically called when app comes to foreground)
   */
  async resume(): Promise<void> {
    if (!this.isInitialized || !this.client) {
      return;
    }

    try {
      // Set online mode
      this.setOnline();

      // Resume the client (which includes force refresh and increment launch count)
      this.client.resume();

      Logger.info('CFLifecycleManager: SDK resumed');
    } catch (error) {
      Logger.error(`CFLifecycleManager: Error during resume: ${error}`);
    }
  }

  /**
   * Cleanup and shutdown the SDK
   */
  async cleanup(): Promise<void> {
    if (!this.isInitialized) {
      return;
    }

    try {
      Logger.info('CFLifecycleManager: Starting cleanup...');

      // Flush all pending data
      if (this.client) {
        await this.flushEvents();
        await this.flushSummaries();
        await this.client.shutdown();
      }

      // Stop app state monitoring
      this.appStateManager.stopMonitoring();

      this.client = null;
      this.isInitialized = false;
      CFLifecycleManager.instance = null;

      Logger.info('CFLifecycleManager: Cleanup completed');
    } catch (error) {
      Logger.error(`CFLifecycleManager: Error during cleanup: ${error}`);
    }
  }

  /**
   * Check if the SDK is initialized
   */
  isSDKInitialized(): boolean {
    return this.isInitialized && this.client !== null;
  }

  /**
   * Get SDK metrics
   */
  getMetrics() {
    return this.client?.getMetrics() || null;
  }

  private async init(): Promise<void> {
    try {
      Logger.info('CFLifecycleManager: Initializing...');

      // Start app state monitoring
      this.appStateManager.startMonitoring();

      // Initialize the CFClient
      this.client = await CFClient.init(this.config, this.user);

      this.isInitialized = true;
      Logger.info('CFLifecycleManager: Initialization completed successfully');
    } catch (error) {
      Logger.error(`CFLifecycleManager: Initialization failed: ${error}`);
      throw error;
    }
  }
} 