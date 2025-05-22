import Foundation

/// Represents summary data tracked by the SDK
public struct SummaryData {
    
    // MARK: - Properties
    
    /// Summary name/type
    public let name: String
    
    /// Count value
    public let count: Int
    
    /// Additional properties
    public let properties: [String: Any]
    
    /// Timestamp of when this summary was created
    public let timestamp: Date
    
    // MARK: - Initialization
    
    /// Initialize a new summary
    /// - Parameters:
    ///   - name: Summary name
    ///   - count: Count value
    ///   - properties: Additional properties
    ///   - timestamp: Optional timestamp (defaults to now)
    public init(
        name: String,
        count: Int = 1,
        properties: [String: Any] = [:],
        timestamp: Date = Date()
    ) {
        self.name = name
        self.count = count
        self.properties = properties
        self.timestamp = timestamp
    }
    
    // MARK: - Conversion Methods
    
    /// Convert to dictionary for serialization
    /// - Returns: Dictionary representation
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "count": count,
            "timestamp": formatDateToIsoString(timestamp)
        ]
        
        // Add all properties
        if !properties.isEmpty {
            dict["properties"] = properties
        }
        
        return dict
    }
    
    /// Convert from dictionary
    /// - Parameter dict: Dictionary representation
    /// - Returns: SummaryData or nil if invalid
    public static func fromDictionary(_ dict: [String: Any]) -> SummaryData? {
        guard let name = dict["name"] as? String else { return nil }
        
        let count = dict["count"] as? Int ?? 1
        let properties = dict["properties"] as? [String: Any] ?? [:]
        
        var timestamp = Date()
        if let timestampStr = dict["timestamp"] as? String {
            timestamp = parseIsoString(timestampStr) ?? Date()
        }
        
        return SummaryData(
            name: name,
            count: count,
            properties: properties,
            timestamp: timestamp
        )
    }
    
    // MARK: - Helper Methods
    
    /// Format date to ISO 8601 string
    /// - Parameter date: Date to format
    /// - Returns: ISO 8601 string
    private func formatDateToIsoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    /// Parse ISO 8601 string to date
    /// - Parameter string: ISO 8601 string
    /// - Returns: Date or nil if invalid
    private static func parseIsoString(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
} 