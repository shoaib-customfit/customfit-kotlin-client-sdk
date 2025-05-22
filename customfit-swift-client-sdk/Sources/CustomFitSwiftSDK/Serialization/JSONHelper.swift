import Foundation

/// Helper class for handling JSON serialization of complex objects
public class JSONHelper {
    
    /// Convert any Swift object to a JSON-serializable value
    /// - Parameter value: Any Swift value
    /// - Returns: JSON-serializable value
    public static func anyToJSON(_ value: Any?) -> Any? {
        guard let value = value else {
            return nil
        }
        
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let bool as Bool:
            return bool
        case let date as Date:
            return CFConfigRequestSummary.timestampFormatter.string(from: date)
        case let array as [Any]:
            return array.map { anyToJSON($0) }.compactMap { $0 }
        case let dictionary as [String: Any]:
            var result = [String: Any]()
            for (key, value) in dictionary {
                if let jsonValue = anyToJSON(value) {
                    result[key] = jsonValue
                }
            }
            return result
        case let jsonConvertible as JSONConvertible:
            return jsonConvertible.toJSON()
        default:
            return String(describing: value)
        }
    }
    
    /// Convert a dictionary with arbitrary values to a dictionary with JSON-serializable values
    /// - Parameter dictionary: Source dictionary
    /// - Returns: Dictionary with JSON-serializable values
    public static func dictionaryToJSON(_ dictionary: [String: Any]) -> [String: Any] {
        var result = [String: Any]()
        
        for (key, value) in dictionary {
            if let jsonValue = anyToJSON(value) {
                result[key] = jsonValue
            }
        }
        
        return result
    }
    
    /// Convert an array with arbitrary values to an array with JSON-serializable values
    /// - Parameter array: Source array
    /// - Returns: Array with JSON-serializable values
    public static func arrayToJSON(_ array: [Any]) -> [Any] {
        return array.map { anyToJSON($0) }.compactMap { $0 }
    }
    
    /// Try to encode an object to JSON data
    /// - Parameter value: The value to encode
    /// - Returns: JSON data or nil if encoding failed
    public static func tryEncode<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(CFConfigRequestSummary.timestampFormatter)
        
        do {
            return try encoder.encode(value)
        } catch {
            Logger.error("JSON encoding error: \(error)")
            return nil
        }
    }
}

/// Protocol for objects that can convert themselves to JSON
public protocol JSONConvertible {
    /// Convert to a JSON serializable representation
    func toJSON() -> Any
} 