import { Logger } from '../logging/Logger';

/**
 * Performance timing utilities for measuring operation performance
 */
export class PerformanceTimer {
  private static timers: Map<string, number> = new Map();

  /**
   * Start timing an operation
   */
  static start(name: string): void {
    this.timers.set(name, Date.now());
    Logger.trace(`PerformanceTimer: Started timing '${name}'`);
  }

  /**
   * End timing and get duration
   */
  static end(name: string): number {
    const startTime = this.timers.get(name);
    if (!startTime) {
      Logger.warning(`PerformanceTimer: No start time found for '${name}'`);
      return 0;
    }

    const duration = Date.now() - startTime;
    this.timers.delete(name);
    
    Logger.trace(`PerformanceTimer: '${name}' completed in ${duration}ms`);
    return duration;
  }

  /**
   * End timing and log the result
   */
  static endAndLog(name: string, logLevel: 'debug' | 'info' | 'warning' = 'debug'): number {
    const duration = this.end(name);
    
    const message = `Performance: '${name}' took ${duration}ms`;
    switch (logLevel) {
      case 'info':
        Logger.info(message);
        break;
      case 'warning':
        Logger.warning(message);
        break;
      default:
        Logger.debug(message);
        break;
    }
    
    return duration;
  }

  /**
   * Get current duration without ending the timer
   */
  static getCurrentDuration(name: string): number {
    const startTime = this.timers.get(name);
    if (!startTime) {
      Logger.warning(`PerformanceTimer: No start time found for '${name}'`);
      return 0;
    }

    return Date.now() - startTime;
  }

  /**
   * Check if timer exists
   */
  static exists(name: string): boolean {
    return this.timers.has(name);
  }

  /**
   * Clear all timers
   */
  static clearAll(): void {
    const count = this.timers.size;
    this.timers.clear();
    Logger.debug(`PerformanceTimer: Cleared ${count} timers`);
  }

  /**
   * Get all active timer names
   */
  static getActiveTimers(): string[] {
    return Array.from(this.timers.keys());
  }

  /**
   * Time an async operation
   */
  static async timeAsync<T>(name: string, operation: () => Promise<T>): Promise<{ result: T; duration: number }> {
    this.start(name);
    try {
      const result = await operation();
      const duration = this.end(name);
      return { result, duration };
    } catch (error) {
      const duration = this.end(name);
      Logger.error(`PerformanceTimer: '${name}' failed after ${duration}ms: ${error}`);
      throw error;
    }
  }

  /**
   * Time a synchronous operation
   */
  static timeSync<T>(name: string, operation: () => T): { result: T; duration: number } {
    this.start(name);
    try {
      const result = operation();
      const duration = this.end(name);
      return { result, duration };
    } catch (error) {
      const duration = this.end(name);
      Logger.error(`PerformanceTimer: '${name}' failed after ${duration}ms: ${error}`);
      throw error;
    }
  }

  /**
   * Create a scoped timer that automatically ends when disposed
   */
  static createScoped(name: string): ScopedTimer {
    return new ScopedTimer(name);
  }
}

/**
 * Scoped timer that automatically ends when disposed
 */
export class ScopedTimer {
  private name: string;
  private disposed: boolean = false;

  constructor(name: string) {
    this.name = name;
    PerformanceTimer.start(name);
  }

  /**
   * End the timer and get duration
   */
  dispose(): number {
    if (this.disposed) {
      Logger.warning(`ScopedTimer: Timer '${this.name}' already disposed`);
      return 0;
    }

    this.disposed = true;
    return PerformanceTimer.end(this.name);
  }

  /**
   * End the timer and log the result
   */
  disposeAndLog(logLevel: 'debug' | 'info' | 'warning' = 'debug'): number {
    if (this.disposed) {
      Logger.warning(`ScopedTimer: Timer '${this.name}' already disposed`);
      return 0;
    }

    this.disposed = true;
    return PerformanceTimer.endAndLog(this.name, logLevel);
  }

  /**
   * Get current duration without disposing
   */
  getCurrentDuration(): number {
    if (this.disposed) {
      return 0;
    }
    return PerformanceTimer.getCurrentDuration(this.name);
  }
}

/**
 * Performance metrics collector
 */
export class PerformanceMetricsCollector {
  private static metrics: Map<string, number[]> = new Map();

  /**
   * Record a performance metric
   */
  static record(name: string, duration: number): void {
    if (!this.metrics.has(name)) {
      this.metrics.set(name, []);
    }
    
    this.metrics.get(name)!.push(duration);
    Logger.trace(`PerformanceMetrics: Recorded '${name}': ${duration}ms`);
  }

  /**
   * Get statistics for a metric
   */
  static getStats(name: string): {
    count: number;
    total: number;
    average: number;
    min: number;
    max: number;
    median: number;
    percentile95: number;
  } | null {
    const durations = this.metrics.get(name);
    if (!durations || durations.length === 0) {
      return null;
    }

    const sorted = [...durations].sort((a, b) => a - b);
    const count = durations.length;
    const total = durations.reduce((sum, d) => sum + d, 0);
    const average = total / count;
    const min = sorted[0];
    const max = sorted[count - 1];
    const median = count % 2 === 0 
      ? (sorted[count / 2 - 1] + sorted[count / 2]) / 2
      : sorted[Math.floor(count / 2)];
    const percentile95Index = Math.ceil(count * 0.95) - 1;
    const percentile95 = sorted[percentile95Index];

    return {
      count,
      total,
      average: Math.round(average * 100) / 100,
      min,
      max,
      median,
      percentile95,
    };
  }

  /**
   * Get all metrics
   */
  static getAllStats(): Record<string, ReturnType<typeof PerformanceMetricsCollector.getStats>> {
    const result: Record<string, any> = {};
    
    for (const name of this.metrics.keys()) {
      result[name] = this.getStats(name);
    }
    
    return result;
  }

  /**
   * Clear metrics for a specific name
   */
  static clear(name: string): void {
    this.metrics.delete(name);
    Logger.debug(`PerformanceMetrics: Cleared metrics for '${name}'`);
  }

  /**
   * Clear all metrics
   */
  static clearAll(): void {
    const count = this.metrics.size;
    this.metrics.clear();
    Logger.debug(`PerformanceMetrics: Cleared all ${count} metrics`);
  }

  /**
   * Get metric names
   */
  static getMetricNames(): string[] {
    return Array.from(this.metrics.keys());
  }

  /**
   * Prune old metrics (keep only recent N entries)
   */
  static pruneMetrics(maxEntries: number = 1000): void {
    for (const [name, durations] of this.metrics.entries()) {
      if (durations.length > maxEntries) {
        const pruned = durations.slice(-maxEntries);
        this.metrics.set(name, pruned);
        Logger.debug(`PerformanceMetrics: Pruned '${name}' from ${durations.length} to ${pruned.length} entries`);
      }
    }
  }
} 