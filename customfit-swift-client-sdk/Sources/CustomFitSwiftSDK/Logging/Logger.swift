import Foundation

/// Manages logging configuration
public class LogConfig {
    public static let shared = LogConfig()

    public private(set) var currentLogLevel: Logger.LogLevel = .debug
    public private(set) var loggingEnabled: Bool = true
    public private(set) var debugLoggingEnabled: Bool = false

    private init() {}

    /// Configure logging based on settings
    public func configure(
        loggingEnabled: Bool,
        debugLoggingEnabled: Bool,
        logLevelStr: String
    ) {
        self.loggingEnabled = loggingEnabled
        self.debugLoggingEnabled = debugLoggingEnabled

        let levelFromString = Logger.LogLevel.fromString(logLevelStr)

        // If debug logging is disabled, cap the maximum log level at INFO
        self.currentLogLevel = if !debugLoggingEnabled && levelFromString.rawValue < Logger.LogLevel.info.rawValue {
            Logger.LogLevel.info // Assuming lower rawValue means more verbose, so cap at info
        } else {
            levelFromString
        }

        if loggingEnabled {
            Logger.systemLog("LogConfig configured: logLevel=\(self.currentLogLevel), debugEnabled=\(self.debugLoggingEnabled)")
        } else {
            Logger.systemLog("LogConfig: logging disabled")
        }
    }

    /// Set logging enabled state at runtime
    public func setLoggingEnabled(enabled: Bool) {
        if self.loggingEnabled != enabled {
            self.loggingEnabled = enabled
            Logger.systemLog("LogConfig: logging \(enabled ? "enabled" : "disabled")")
        }
    }

    /// Set debug logging enabled state at runtime
    public func setDebugLoggingEnabled(enabled: Bool) {
        if self.debugLoggingEnabled != enabled {
            self.debugLoggingEnabled = enabled
            // If debug logging is being disabled, cap the log level at INFO
            if !enabled && currentLogLevel.rawValue < Logger.LogLevel.info.rawValue { // Adjust if higher rawValue means more verbose
                currentLogLevel = Logger.LogLevel.info
            }
            Logger.systemLog("LogConfig: debug logging \(enabled ? "enabled" : "disabled")")
        }
    }

    /// Set log level at runtime
    public func setLogLevel(level: Logger.LogLevel) {
        // If debug logging is disabled, cap the level at INFO
        let newLevel = if !debugLoggingEnabled && level.rawValue < Logger.LogLevel.info.rawValue { // Adjust based on LogLevel definition
            Logger.LogLevel.info
        } else {
            level
        }

        if currentLogLevel != newLevel {
            currentLogLevel = newLevel
            Logger.systemLog("LogConfig: log level set to \(newLevel)")
        }
    }
}

/// Logger for the CustomFit SDK
public struct Logger {
    /// Log level for the SDK (aligned with Kotlin's ERROR to TRACE severity)
    public enum LogLevel: Int, Comparable {
        // Kotlin: ERROR(1), WARN(2), INFO(3), DEBUG(4), TRACE(5)
        // Swift: Lower value = higher priority (more severe)
        case error = 1   // Corresponds to Kotlin ERROR
        case warning = 2 // Corresponds to Kotlin WARN
        case info = 3    // Corresponds to Kotlin INFO
        case debug = 4   // Corresponds to Kotlin DEBUG
        case trace = 5   // Corresponds to Kotlin TRACE (was verbose)

        /// Implement Comparable protocol
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            // Lower rawValue means more severe/higher priority
            // So, to check if lhs should log (e.g. currentLogLevel = .info (3), messageLevel = .debug (4) )
            // We need currentLogLevel.rawValue <= messageLevel.rawValue for Kotlin's logic
            // Here, if currentLogLevel = .debug (4) and we want to log a .info (3) message, it should not log.
            // If currentLogLevel = .debug (4) and we want to log a .trace(5) message, it should log.
            // This means we log if messageLevel.rawValue >= currentLogLevel.rawValue
            return lhs.rawValue < rhs.rawValue // Keep this as is for now, adjust checks below
        }

        public static func fromString(_ levelStr: String) -> LogLevel {
            switch levelStr.uppercased() {
                case "ERROR": return .error
                case "WARN", "WARNING": return .warning // Allow "WARN" also
                case "INFO": return .info
                case "DEBUG": return .debug
                case "TRACE", "VERBOSE": return .trace // Allow "VERBOSE" also
                default: return .debug // Default to DEBUG if unknown, as in Kotlin
            }
        }
    }

    // Use LogConfig for log level and enabled status
    private static var config: LogConfig { LogConfig.shared }

    /// Set the logging level - delegates to LogConfig
    /// - Parameter level: The log level to set
    public static func setLogLevel(level: LogLevel) {
        config.setLogLevel(level: level)
    }

    /// Get the current log level - delegates to LogConfig
    /// - Returns: The current log level
    public static func getLogLevel() -> LogLevel {
        return config.currentLogLevel
    }
    
    /// Configure overall logging - delegates to LogConfig
    public static func configure(loggingEnabled: Bool, debugLoggingEnabled: Bool, logLevelStr: String) {
        config.configure(loggingEnabled: loggingEnabled, debugLoggingEnabled: debugLoggingEnabled, logLevelStr: logLevelStr)
    }

    public static func setLoggingEnabled(enabled: Bool) {
        config.setLoggingEnabled(enabled: enabled)
    }
    
    public static func setDebugLoggingEnabled(enabled: Bool) {
        config.setDebugLoggingEnabled(enabled: enabled)
    }

    /// Log a trace message (formerly verbose)
    /// - Parameter message: The message to log
    public static func trace(_ message: String) {
        log(level: .trace, message: message)
    }

    /// Log a debug message
    /// - Parameter message: The message to log
    public static func debug(_ message: String) {
        log(level: .debug, message: message)
    }

    /// Log an info message
    /// - Parameter message: The message to log
    public static func info(_ message: String) {
        log(level: .info, message: message)
    }

    /// Log a warning message
    /// - Parameter message: The message to log
    public static func warning(_ message: String) {
        log(level: .warning, message: message)
    }
    
    /// Log a warning message with an Error
    /// - Parameter error: The error to log
    /// - Parameter message: The message to log
    public static func warning(_ error: Error, _ message: String) {
        log(level: .warning, message: "\(message) - Error: \(error.localizedDescription)")
    }

    /// Log an error message
    /// - Parameter message: The message to log
    public static func error(_ message: String) {
        log(level: .error, message: message)
    }

    /// Log an error message with an Error
    /// - Parameter error: The error to log
    /// - Parameter message: The message to log
    public static func error(_ error: Error, _ message: String) {
        log(level: .error, message: "\(message) - Error: \(error.localizedDescription)")
    }

    /// Log a message with a specific level
    private static func log(level: LogLevel, message: String) {
        guard config.loggingEnabled else { return }
        // Kotlin: currentLogLevel.value >= level.value  (e.g. INFO(3) >= DEBUG(4) is false)
        // so, currentLogLevel.shouldLog(level) means this.value >= level.value
        // For Swift, log if messageLevel.rawValue >= config.currentLogLevel.rawValue
        // Example: message is .debug (4), current is .info (3).  4 >= 3 -> log.
        // Example: message is .info (3), current is .debug (4).  3 >= 4 -> don't log.
        if level.rawValue >= config.currentLogLevel.rawValue { // Check if message's severity is high enough
            // Using a prefix similar to Kotlin's TimberInitializer
            let logPrefix = "Customfit.ai-SDK [Swift]"
            // Timestamp like Kotlin's "HH:mm:ss.SSS"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss.SSS"
            let timestamp = dateFormatter.string(from: Date())

            var output = "[\(timestamp)] \(logPrefix) [\(String(describing: level).uppercased())] \(message)"

            // Apply special formatting similar to Kotlin's directConsoleOutput
            if message.contains("API POLL") {
                output = "[\(timestamp)] 📡 \(logPrefix) [\(String(describing: level).uppercased())] \(message)"
            } else if message.contains("SUMMARY") {
                output = "[\(timestamp)] 📊 \(logPrefix) [\(String(describing: level).uppercased())] \(message)"
            } else if message.contains("CONFIG VALUE") || message.contains("CONFIG UPDATE") {
                output = "[\(timestamp)] 🔧 \(logPrefix) [\(String(describing: level).uppercased())] \(message)"
            } else if message.contains("TRACK") || message.contains("🔔") {
                output = "[\(timestamp)] 🔔 \(logPrefix) [\(String(describing: level).uppercased())] \(message)"
            }
            print(output)
        }
    }
    
    /// For system messages from LogConfig itself, not subject to LogLevel filtering beyond loggingEnabled
    internal static func systemLog(_ message: String) {
        guard config.loggingEnabled else { return }
        let logPrefix = "Customfit.ai-SDK [Swift]"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(logPrefix) [SYSTEM] \(message)")
    }
}
