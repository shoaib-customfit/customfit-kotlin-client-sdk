import NetInfo, { NetInfoState } from '@react-native-community/netinfo';
import { ConnectionStatus, ConnectionStatusListener } from '../core/types/CFTypes';
import { Logger } from '../logging/Logger';

/**
 * Network connection monitor
 */
export class ConnectionMonitor {
  private static instance: ConnectionMonitor | null = null;
  private listeners: Set<ConnectionStatusListener> = new Set();
  private currentStatus: ConnectionStatus = ConnectionStatus.UNKNOWN;
  private isMonitoring: boolean = false;
  private unsubscribe: (() => void) | null = null;

  private constructor() {}

  /**
   * Get singleton instance
   */
  static getInstance(): ConnectionMonitor {
    if (!ConnectionMonitor.instance) {
      ConnectionMonitor.instance = new ConnectionMonitor();
    }
    return ConnectionMonitor.instance;
  }

  /**
   * Start monitoring network connectivity
   */
  async startMonitoring(): Promise<void> {
    if (this.isMonitoring) {
      Logger.debug('ConnectionMonitor: Already monitoring');
      return;
    }

    try {
      // Get initial connection state
      const initialState = await NetInfo.fetch();
      this.currentStatus = this.mapNetInfoToStatus(initialState);
      
      Logger.info(`ConnectionMonitor: Initial connection status: ${this.currentStatus}`);

      // Subscribe to connection changes
      this.unsubscribe = NetInfo.addEventListener((state: NetInfoState) => {
        const newStatus = this.mapNetInfoToStatus(state);
        
        if (newStatus !== this.currentStatus) {
          const oldStatus = this.currentStatus;
          this.currentStatus = newStatus;
          
          Logger.info(`ConnectionMonitor: Status changed from ${oldStatus} to ${newStatus}`);
          this.notifyListeners(newStatus);
        }
      });

      this.isMonitoring = true;
      Logger.info('ConnectionMonitor: Started monitoring network connectivity');
    } catch (error) {
      Logger.error(`ConnectionMonitor: Failed to start monitoring: ${error}`);
      this.currentStatus = ConnectionStatus.UNKNOWN;
    }
  }

  /**
   * Stop monitoring network connectivity
   */
  stopMonitoring(): void {
    if (!this.isMonitoring) {
      Logger.debug('ConnectionMonitor: Not currently monitoring');
      return;
    }

    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }

    this.isMonitoring = false;
    Logger.info('ConnectionMonitor: Stopped monitoring network connectivity');
  }

  /**
   * Get current connection status
   */
  getCurrentStatus(): ConnectionStatus {
    return this.currentStatus;
  }

  /**
   * Check if device is currently connected
   */
  isConnected(): boolean {
    return this.currentStatus === ConnectionStatus.CONNECTED;
  }

  /**
   * Check if device is currently disconnected
   */
  isDisconnected(): boolean {
    return this.currentStatus === ConnectionStatus.DISCONNECTED;
  }

  /**
   * Add a connection status listener
   */
  addListener(listener: ConnectionStatusListener): void {
    this.listeners.add(listener);
    Logger.debug(`ConnectionMonitor: Added listener (total: ${this.listeners.size})`);
  }

  /**
   * Remove a connection status listener
   */
  removeListener(listener: ConnectionStatusListener): void {
    const removed = this.listeners.delete(listener);
    if (removed) {
      Logger.debug(`ConnectionMonitor: Removed listener (total: ${this.listeners.size})`);
    }
  }

  /**
   * Remove all listeners
   */
  removeAllListeners(): void {
    const count = this.listeners.size;
    this.listeners.clear();
    Logger.debug(`ConnectionMonitor: Removed all ${count} listeners`);
  }

  /**
   * Force refresh connection status
   */
  async refresh(): Promise<ConnectionStatus> {
    try {
      const state = await NetInfo.fetch();
      const newStatus = this.mapNetInfoToStatus(state);
      
      if (newStatus !== this.currentStatus) {
        const oldStatus = this.currentStatus;
        this.currentStatus = newStatus;
        
        Logger.info(`ConnectionMonitor: Status refreshed from ${oldStatus} to ${newStatus}`);
        this.notifyListeners(newStatus);
      }
      
      return this.currentStatus;
    } catch (error) {
      Logger.error(`ConnectionMonitor: Failed to refresh status: ${error}`);
      return this.currentStatus;
    }
  }

  /**
   * Get detailed connection information
   */
  async getConnectionInfo(): Promise<{
    status: ConnectionStatus;
    type: string;
    isInternetReachable: boolean | null;
    isWifiEnabled: boolean;
  }> {
    try {
      const state = await NetInfo.fetch();
      
      return {
        status: this.mapNetInfoToStatus(state),
        type: state.type,
        isInternetReachable: state.isInternetReachable,
        isWifiEnabled: state.isWifiEnabled || false,
      };
    } catch (error) {
      Logger.error(`ConnectionMonitor: Failed to get connection info: ${error}`);
      
      return {
        status: ConnectionStatus.UNKNOWN,
        type: 'unknown',
        isInternetReachable: null,
        isWifiEnabled: false,
      };
    }
  }

  /**
   * Check if monitoring is active
   */
  isMonitoringActive(): boolean {
    return this.isMonitoring;
  }

  private mapNetInfoToStatus(state: NetInfoState): ConnectionStatus {
    if (!state.isConnected) {
      return ConnectionStatus.DISCONNECTED;
    }

    // Check internet reachability
    if (state.isInternetReachable === false) {
      return ConnectionStatus.DISCONNECTED;
    }

    if (state.isInternetReachable === null) {
      return ConnectionStatus.UNKNOWN;
    }

    return ConnectionStatus.CONNECTED;
  }

  private notifyListeners(status: ConnectionStatus): void {
    this.listeners.forEach(listener => {
      try {
        listener.onConnectionStatusChanged(status);
      } catch (error) {
        Logger.error(`ConnectionMonitor: Error notifying listener: ${error}`);
      }
    });
  }
} 