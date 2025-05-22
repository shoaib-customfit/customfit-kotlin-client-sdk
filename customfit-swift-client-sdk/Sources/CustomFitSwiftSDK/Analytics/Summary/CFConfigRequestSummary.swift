import Foundation

/// Config request summary data structure
public struct CFConfigRequestSummary: Codable {
    /// Config identifier
    public let configId: String?
    
    /// Version of the configuration
    public let version: String?
    
    /// User identifier
    public let userId: String?
    
    /// Time when the config was requested
    public let requestedTime: String
    
    /// Variation identifier
    public let variationId: String?
    
    /// Customer user identifier
    public let userCustomerId: String
    
    /// Session identifier
    public let sessionId: String
    
    /// Behaviour identifier
    public let behaviourId: String?
    
    /// Experience identifier
    public let experienceId: String?
    
    /// Rule identifier
    public let ruleId: String?
    
    /// Formatter for timestamps used by the server (yyy-MM-dd HH:mm:ss.SSSX format)
    public static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSX"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    enum CodingKeys: String, CodingKey {
        case configId = "config_id"
        case version
        case userId = "user_id"
        case requestedTime = "requested_time"
        case variationId = "variation_id"
        case userCustomerId = "user_customer_id"
        case sessionId = "session_id"
        case behaviourId = "behaviour_id"
        case experienceId = "experience_id"
        case ruleId = "rule_id"
    }
    
    /// Initialize a new config request summary
    /// - Parameters:
    ///   - configId: Config identifier
    ///   - version: Config version
    ///   - userId: User identifier
    ///   - requestedTime: Request time string
    ///   - variationId: Variation identifier
    ///   - userCustomerId: Customer user identifier
    ///   - sessionId: Session identifier
    ///   - behaviourId: Behaviour identifier
    ///   - experienceId: Experience identifier
    ///   - ruleId: Rule identifier
    public init(
        configId: String?,
        version: String?,
        userId: String?,
        requestedTime: String,
        variationId: String?,
        userCustomerId: String,
        sessionId: String,
        behaviourId: String?,
        experienceId: String?,
        ruleId: String?
    ) {
        self.configId = configId
        self.version = version
        self.userId = userId
        self.requestedTime = requestedTime
        self.variationId = variationId
        self.userCustomerId = userCustomerId
        self.sessionId = sessionId
        self.behaviourId = behaviourId
        self.experienceId = experienceId
        self.ruleId = ruleId
    }
    
    /// Initialize from config dictionary
    /// - Parameters:
    ///   - config: Config dictionary
    ///   - customerUserId: Customer user identifier
    ///   - sessionId: Session identifier
    public init(from config: [String: Any], customerUserId: String, sessionId: String) {
        self.configId = config["config_id"] as? String
        
        // Safely convert version to String
        if let versionVal = config["version"] {
            if let versionStr = versionVal as? String {
                self.version = versionStr
            } else {
                self.version = String(describing: versionVal)
            }
        } else {
            self.version = nil
        }
        
        self.userId = config["user_id"] as? String
        self.requestedTime = CFConfigRequestSummary.timestampFormatter.string(from: Date())
        self.variationId = config["variation_id"] as? String
        self.userCustomerId = customerUserId
        self.sessionId = sessionId
        
        if let experienceBehavior = config["experience_behaviour_response"] as? [String: Any] {
            self.behaviourId = experienceBehavior["behaviour_id"] as? String
            self.experienceId = experienceBehavior["experience_id"] as? String
            self.ruleId = experienceBehavior["rule_id"] as? String
        } else {
            self.behaviourId = config["behaviour_id"] as? String
            self.experienceId = config["experience_id"] as? String
            self.ruleId = config["rule_id"] as? String
        }
    }
    
    /// Convert to dictionary for JSON serialization
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let configId = configId { dict["config_id"] = configId }
        if let version = version { dict["version"] = version }
        if let userId = userId { dict["user_id"] = userId }
        dict["requested_time"] = requestedTime
        if let variationId = variationId { dict["variation_id"] = variationId }
        dict["user_customer_id"] = userCustomerId
        dict["session_id"] = sessionId
        if let behaviourId = behaviourId { dict["behaviour_id"] = behaviourId }
        if let experienceId = experienceId { dict["experience_id"] = experienceId }
        if let ruleId = ruleId { dict["rule_id"] = ruleId }
        
        return dict
    }
} 