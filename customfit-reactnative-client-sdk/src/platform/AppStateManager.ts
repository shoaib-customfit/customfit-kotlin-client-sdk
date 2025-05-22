import { AppState as RNAppState, AppStateStatus } from 'react-native';
import { AppState, AppStateListener, BatteryState, BatteryStateListener } from '../core/types/CFTypes';
import { Logger } from '../logging/Logger';

/**
 * App state manager for monitoring application lifecycle in React Native
 */
export class AppStateManager {
  private static instance: AppStateManager | null = null;
  private appStateListeners: Set<AppStateListener> = new Set();
  private batteryStateListeners: Set<BatteryStateListener> = new Set();
  private currentAppState: AppState = AppState.ACTIVE;
  private currentBatteryState: BatteryState = {
    level: 1.0,
    isLow: false,
    isCharging: true,
  };
  private isMonitoring: boolean = false;
  private appStateSubscription: any = null;
  private batteryCheckTimer: NodeJS.Timeout | null = null;

  private constructor() {}

  /**
   * Get singleton instance
   */
  static getInstance(): AppStateManager {
    if (!AppStateManager.instance) {
      AppStateManager.instance = new AppStateManager();
    }
    return AppStateManager.instance;
  }

  /**
   * Start monitoring app state and battery changes
   */
  startMonitoring(): void {
    if (this.isMonitoring) {
      Logger.debug('AppStateManager: Already monitoring');
      return;
    }

    try {
      // Get initial app state
      this.currentAppState = this.mapRNAppStateToAppState(RNAppState.currentState);
      Logger.info(`AppStateManager: Initial app state: ${this.currentAppState}`);

      // Subscribe to app state changes
      this.appStateSubscription = RNAppState.addEventListener('change', this.handleAppStateChange.bind(this));

      // Start battery monitoring (simulated for React Native)
      this.startBatteryMonitoring();

      this.isMonitoring = true;
      Logger.info('AppStateManager: Started monitoring app state and battery');
    } catch (error) {
      Logger.error(`AppStateManager: Failed to start monitoring: ${error}`);
    }
  }

  /**
   * Stop monitoring app state and battery changes
   */
  stopMonitoring(): void {
    if (!this.isMonitoring) {
      Logger.debug('AppStateManager: Not currently monitoring');
      return;
    }

    try {
      // Remove app state subscription
      if (this.appStateSubscription) {
        this.appStateSubscription.remove();
        this.appStateSubscription = null;
      }

      // Stop battery monitoring
      this.stopBatteryMonitoring();

      this.isMonitoring = false;
      Logger.info('AppStateManager: Stopped monitoring app state and battery');
    } catch (error) {
      Logger.error(`AppStateManager: Failed to stop monitoring: ${error}`);
    }
  }

  /**
   * Get current app state
   */
  getCurrentAppState(): AppState {
    return this.currentAppState;
  }

  /**
   * Get current battery state
   */
  getCurrentBatteryState(): BatteryState {
    return { ...this.currentBatteryState };
  }

  /**
   * Add app state listener
   */
  addAppStateListener(listener: AppStateListener): void {
    this.appStateListeners.add(listener);
    Logger.debug(`AppStateManager: Added app state listener (total: ${this.appStateListeners.size})`);

    // Immediately notify with current state
    try {
      listener.onAppStateChanged(this.currentAppState, this.currentAppState);
    } catch (error) {
      Logger.error(`AppStateManager: Error notifying initial app state: ${error}`);
    }
  }

  /**
   * Remove app state listener
   */
  removeAppStateListener(listener: AppStateListener): void {
    const removed = this.appStateListeners.delete(listener);
    if (removed) {
      Logger.debug(`AppStateManager: Removed app state listener (total: ${this.appStateListeners.size})`);
    }
  }

  /**
   * Add battery state listener
   */
  addBatteryStateListener(listener: BatteryStateListener): void {
    this.batteryStateListeners.add(listener);
    Logger.debug(`AppStateManager: Added battery state listener (total: ${this.batteryStateListeners.size})`);

    // Immediately notify with current state
    try {
      listener.onBatteryStateChanged(this.currentBatteryState);
    } catch (error) {
      Logger.error(`AppStateManager: Error notifying initial battery state: ${error}`);
    }
  }

  /**
   * Remove battery state listener
   */
  removeBatteryStateListener(listener: BatteryStateListener): void {
    const removed = this.batteryStateListeners.delete(listener);
    if (removed) {
      Logger.debug(`AppStateManager: Removed battery state listener (total: ${this.batteryStateListeners.size})`);
    }
  }

  /**
   * Remove all listeners
   */
  removeAllListeners(): void {
    const appStateCount = this.appStateListeners.size;
    const batteryStateCount = this.batteryStateListeners.size;
    
    this.appStateListeners.clear();
    this.batteryStateListeners.clear();
    
    Logger.debug(`AppStateManager: Removed all listeners (${appStateCount} app state, ${batteryStateCount} battery state)`);
  }

  /**
   * Get battery-aware polling interval
   */
  getPollingInterval(
    normalInterval: number,
    reducedInterval: number,
    useReducedWhenLow: boolean
  ): number {
    if (useReducedWhenLow && this.currentBatteryState.isLow) {
      Logger.debug(`Using reduced polling interval (${reducedInterval}ms) due to low battery`);
      return reducedInterval;
    }
    return normalInterval;
  }

  /**
   * Check if monitoring is active
   */
  isMonitoringActive(): boolean {
    return this.isMonitoring;
  }

  private handleAppStateChange(nextAppState: AppStateStatus): void {
    const previousState = this.currentAppState;
    const newState = this.mapRNAppStateToAppState(nextAppState);

    if (newState !== previousState) {
      this.currentAppState = newState;
      Logger.info(`AppStateManager: App state changed from ${previousState} to ${newState}`);

      // Notify all listeners
      this.notifyAppStateListeners(newState, previousState);
    }
  }

  private mapRNAppStateToAppState(rnAppState: AppStateStatus): AppState {
    switch (rnAppState) {
      case 'active':
        return AppState.ACTIVE;
      case 'background':
        return AppState.BACKGROUND;
      case 'inactive':
        return AppState.INACTIVE;
      default:
        return AppState.UNKNOWN;
    }
  }

  private startBatteryMonitoring(): void {
    // Simulated battery monitoring for React Native
    // In a real implementation, you'd use react-native-device-info or similar
    this.updateBatteryState();

    // Check battery state every 60 seconds
    this.batteryCheckTimer = setInterval(() => {
      this.updateBatteryState();
    }, 60000);

    Logger.debug('AppStateManager: Started battery monitoring');
  }

  private stopBatteryMonitoring(): void {
    if (this.batteryCheckTimer) {
      clearInterval(this.batteryCheckTimer);
      this.batteryCheckTimer = null;
      Logger.debug('AppStateManager: Stopped battery monitoring');
    }
  }

  private updateBatteryState(): void {
    try {
      // Simulate battery state changes
      // In a real implementation, you'd get actual battery info from the device
      const level = 0.2 + Math.random() * 0.8; // Random level between 20% and 100%
      const isCharging = Math.random() > 0.3; // 70% chance of being charged
      const isLow = level < 0.2 && !isCharging;

      const newBatteryState: BatteryState = {
        level,
        isLow,
        isCharging,
      };

      // Check if battery state changed significantly
      const previousState = this.currentBatteryState;
      const stateChanged = 
        Math.abs(newBatteryState.level - previousState.level) > 0.05 ||
        newBatteryState.isLow !== previousState.isLow ||
        newBatteryState.isCharging !== previousState.isCharging;

      if (stateChanged) {
        this.currentBatteryState = newBatteryState;
        Logger.debug(
          `AppStateManager: Battery state changed - Level: ${(newBatteryState.level * 100).toFixed(1)}%, ` +
          `Low: ${newBatteryState.isLow}, Charging: ${newBatteryState.isCharging}`
        );

        // Notify all listeners
        this.notifyBatteryStateListeners(newBatteryState);
      }
    } catch (error) {
      Logger.error(`AppStateManager: Failed to update battery state: ${error}`);
    }
  }

  private notifyAppStateListeners(newState: AppState, previousState: AppState): void {
    this.appStateListeners.forEach(listener => {
      try {
        listener.onAppStateChanged(newState, previousState);
      } catch (error) {
        Logger.error(`AppStateManager: Error notifying app state listener: ${error}`);
      }
    });
  }

  private notifyBatteryStateListeners(batteryState: BatteryState): void {
    this.batteryStateListeners.forEach(listener => {
      try {
        listener.onBatteryStateChanged(batteryState);
      } catch (error) {
        Logger.error(`AppStateManager: Error notifying battery state listener: ${error}`);
      }
    });
  }
} 