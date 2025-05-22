import { LogLevel } from '../core/types/CFTypes';

/**
 * Logger configuration and management
 */
class LogConfig {
  private static instance: LogConfig = new LogConfig();
  
  private currentLogLevel: LogLevel = LogLevel.DEBUG;
  private loggingEnabled: boolean = true;
  private debugLoggingEnabled: boolean = false;

  private constructor() {}

  static getInstance(): LogConfig {
    return LogConfig.instance;
  }

  configure(
    loggingEnabled: boolean,
    debugLoggingEnabled: boolean,
    logLevelStr: string
  ): void {
    this.loggingEnabled = loggingEnabled;
    this.debugLoggingEnabled = debugLoggingEnabled;

    const levelFromString = this.logLevelFromString(logLevelStr);

    // If debug logging is disabled, cap the maximum log level at INFO
    this.currentLogLevel = !debugLoggingEnabled && levelFromString > LogLevel.INFO 
      ? LogLevel.INFO 
      : levelFromString;

    if (loggingEnabled) {
      Logger.systemLog(`LogConfig configured: logLevel=${LogLevel[this.currentLogLevel]}, debugEnabled=${this.debugLoggingEnabled}`);
    } else {
      Logger.systemLog('LogConfig: logging disabled');
    }
  }

  setLoggingEnabled(enabled: boolean): void {
    if (this.loggingEnabled !== enabled) {
      this.loggingEnabled = enabled;
      Logger.systemLog(`LogConfig: logging ${enabled ? 'enabled' : 'disabled'}`);
    }
  }

  setDebugLoggingEnabled(enabled: boolean): void {
    if (this.debugLoggingEnabled !== enabled) {
      this.debugLoggingEnabled = enabled;
      // If debug logging is being disabled, cap the log level at INFO
      if (!enabled && this.currentLogLevel > LogLevel.INFO) {
        this.currentLogLevel = LogLevel.INFO;
      }
      Logger.systemLog(`LogConfig: debug logging ${enabled ? 'enabled' : 'disabled'}`);
    }
  }

  setLogLevel(level: LogLevel): void {
    // If debug logging is disabled, cap the level at INFO
    const newLevel = !this.debugLoggingEnabled && level > LogLevel.INFO 
      ? LogLevel.INFO 
      : level;

    if (this.currentLogLevel !== newLevel) {
      this.currentLogLevel = newLevel;
      Logger.systemLog(`LogConfig: log level set to ${LogLevel[newLevel]}`);
    }
  }

  getCurrentLogLevel(): LogLevel {
    return this.currentLogLevel;
  }

  isLoggingEnabled(): boolean {
    return this.loggingEnabled;
  }

  isDebugLoggingEnabled(): boolean {
    return this.debugLoggingEnabled;
  }

  private logLevelFromString(levelStr: string): LogLevel {
    switch (levelStr.toUpperCase()) {
      case 'ERROR': return LogLevel.ERROR;
      case 'WARN':
      case 'WARNING': return LogLevel.WARN;
      case 'INFO': return LogLevel.INFO;
      case 'DEBUG': return LogLevel.DEBUG;
      case 'TRACE':
      case 'VERBOSE': return LogLevel.TRACE;
      default: return LogLevel.DEBUG;
    }
  }
}

/**
 * Logger for the CustomFit React Native SDK
 * Matches the functionality of Kotlin and Swift SDKs
 */
export class Logger {
  private static config = LogConfig.getInstance();

  /**
   * Configure logging settings
   */
  static configure(
    loggingEnabled: boolean,
    debugLoggingEnabled: boolean,
    logLevelStr: string
  ): void {
    Logger.config.configure(loggingEnabled, debugLoggingEnabled, logLevelStr);
  }

  /**
   * Set the logging level
   */
  static setLogLevel(level: LogLevel): void {
    Logger.config.setLogLevel(level);
  }

  /**
   * Get the current log level
   */
  static getLogLevel(): LogLevel {
    return Logger.config.getCurrentLogLevel();
  }

  /**
   * Set logging enabled/disabled
   */
  static setLoggingEnabled(enabled: boolean): void {
    Logger.config.setLoggingEnabled(enabled);
  }

  /**
   * Set debug logging enabled/disabled
   */
  static setDebugLoggingEnabled(enabled: boolean): void {
    Logger.config.setDebugLoggingEnabled(enabled);
  }

  /**
   * Log a trace message
   */
  static trace(message: string): void {
    Logger.log(LogLevel.TRACE, message);
  }

  /**
   * Log a debug message
   */
  static debug(message: string): void {
    Logger.log(LogLevel.DEBUG, message);
  }

  /**
   * Log an info message
   */
  static info(message: string): void {
    Logger.log(LogLevel.INFO, message);
  }

  /**
   * Log a warning message
   */
  static warning(message: string): void {
    Logger.log(LogLevel.WARN, message);
  }

  /**
   * Log an error message
   */
  static error(message: string): void {
    Logger.log(LogLevel.ERROR, message);
  }

  /**
   * Internal logging method with consistent formatting
   */
  private static log(level: LogLevel, message: string): void {
    if (!Logger.config.isLoggingEnabled()) {
      return;
    }

    // Check if message's severity is high enough to be logged
    if (level <= Logger.config.getCurrentLogLevel()) {
      // Using a prefix similar to Kotlin's and Swift's implementation
      const logPrefix = 'Customfit.ai-SDK [React Native]';
      
      // Timestamp like Kotlin's "HH:mm:ss.SSS"
      const timestamp = Logger.formatTimestamp(new Date());
      const levelName = LogLevel[level].toUpperCase();

      let output = `[${timestamp}] ${logPrefix} [${levelName}] ${message}`;

      // Apply special formatting similar to Kotlin's directConsoleOutput
      if (message.includes('API POLL')) {
        output = `[${timestamp}] 📡 ${logPrefix} [${levelName}] ${message}`;
      } else if (message.includes('SUMMARY')) {
        output = `[${timestamp}] 📊 ${logPrefix} [${levelName}] ${message}`;
      } else if (message.includes('CONFIG VALUE') || message.includes('CONFIG UPDATE')) {
        output = `[${timestamp}] 🔧 ${logPrefix} [${levelName}] ${message}`;
      } else if (message.includes('TRACK') || message.includes('🔔')) {
        output = `[${timestamp}] 🔔 ${logPrefix} [${levelName}] ${message}`;
      }

      console.log(output);
    }
  }

  /**
   * For system messages from LogConfig itself, not subject to LogLevel filtering
   */
  static systemLog(message: string): void {
    if (!Logger.config.isLoggingEnabled()) {
      return;
    }

    const logPrefix = 'Customfit.ai-SDK [React Native]';
    const timestamp = Logger.formatTimestamp(new Date());
    console.log(`[${timestamp}] ${logPrefix} [SYSTEM] ${message}`);
  }

  /**
   * Format timestamp to match Kotlin/Swift format
   */
  private static formatTimestamp(date: Date): string {
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const seconds = date.getSeconds().toString().padStart(2, '0');
    const milliseconds = date.getMilliseconds().toString().padStart(3, '0');
    
    return `${hours}:${minutes}:${seconds}.${milliseconds}`;
  }
} 