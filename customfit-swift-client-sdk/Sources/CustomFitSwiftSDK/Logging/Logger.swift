import Foundation

/// Logger for the CustomFit SDK
public struct Logger {
    /// Log level for the SDK
    public enum LogLevel: Int, Comparable {
        /// Verbose logging (most detailed)
        case verbose = 0
        
        /// Debug logging
        case debug = 1
        
        /// Info logging
        case info = 2
        
        /// Warning logging
        case warning = 3
        
        /// Error logging (least detailed)
        case error = 4
        
        /// No logging at all
        case none = 5
        
        /// Implement Comparable protocol
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Current log level
    private static var currentLogLevel: LogLevel = .info
    
    /// Set the logging level
    /// - Parameter level: The log level to set
    public static func setLogLevel(level: LogLevel) {
        currentLogLevel = level
    }
    
    /// Get the current log level
    /// - Returns: The current log level
    public static func getLogLevel() -> LogLevel {
        return currentLogLevel
    }
    
    /// Log a verbose message
    /// - Parameter message: The message to log
    public static func verbose(_ message: String) {
        if currentLogLevel <= .verbose {
            log(level: "VERBOSE", message: message)
        }
    }
    
    /// Log a debug message
    /// - Parameter message: The message to log
    public static func debug(_ message: String) {
        if currentLogLevel <= .debug {
            log(level: "DEBUG", message: message)
        }
    }
    
    /// Log an info message
    /// - Parameter message: The message to log
    public static func info(_ message: String) {
        if currentLogLevel <= .info {
            log(level: "INFO", message: message)
        }
    }
    
    /// Log a warning message
    /// - Parameter message: The message to log
    public static func warning(_ message: String) {
        if currentLogLevel <= .warning {
            log(level: "WARN", message: message)
        }
    }
    
    /// Log an error message
    /// - Parameter message: The message to log
    public static func error(_ message: String) {
        if currentLogLevel <= .error {
            log(level: "ERROR", message: message)
        }
    }
    
    /// Log a message with a level
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    private static func log(level: String, message: String) {
        print("[\(CFConstants.General.LOGGER_NAME)] [\(level)] \(message)")
    }
}
