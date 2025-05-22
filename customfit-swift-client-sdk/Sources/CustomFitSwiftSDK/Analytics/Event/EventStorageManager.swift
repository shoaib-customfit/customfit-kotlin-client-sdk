import Foundation

/// Manages event storage and persistence
public class EventStorageManager {
    
    // MARK: - Constants
    
    /// Storage directory name
    private static let STORAGE_DIR = "CustomFitEvents"
    
    /// Events file name
    private static let EVENTS_FILE = "events.json"
    
    // MARK: - Properties
    
    /// Config reference for settings
    private let config: CFConfig
    
    /// File manager for storage operations
    private let fileManager: FileManager
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Storage URL for events
    private let storageUrl: URL?
    
    // MARK: - Initialization
    
    /// Initialize with configuration
    /// - Parameter config: The SDK configuration
    public init(config: CFConfig) {
        self.config = config
        self.fileManager = FileManager.default
        
        // Set up storage directory
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let storageDirectory = documentsDirectory.appendingPathComponent(EventStorageManager.STORAGE_DIR, isDirectory: true)
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: storageDirectory.path) {
                do {
                    try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
                    self.storageUrl = storageDirectory
                } catch {
                    Logger.error("Failed to create event storage directory: \(error.localizedDescription)")
                    self.storageUrl = nil
                }
            } else {
                self.storageUrl = storageDirectory
            }
        } else {
            self.storageUrl = nil
        }
    }
    
    // MARK: - Storage Methods
    
    /// Store events to persistent storage
    /// - Parameter events: Events to store
    /// - Throws: Error if storage fails
    public func storeEvents(events: [EventData]) throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard let storageUrl = storageUrl else {
            throw NSError(domain: "EventStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Storage directory not available"])
        }
        
        let eventsFile = storageUrl.appendingPathComponent(EventStorageManager.EVENTS_FILE)
        
        // Convert events to dictionaries
        let eventDicts = events.map { $0.toDictionary() }
        
        // Serialize to JSON
        let data = try JSONSerialization.data(withJSONObject: eventDicts, options: [.prettyPrinted])
        
        // Write to file
        try data.write(to: eventsFile, options: .atomic)
        
        Logger.debug("Stored \(events.count) events to file: \(eventsFile.path)")
    }
    
    /// Load events from persistent storage
    /// - Returns: Array of events
    /// - Throws: Error if loading fails
    public func loadEvents() throws -> [EventData] {
        lock.lock()
        defer { lock.unlock() }
        
        guard let storageUrl = storageUrl else {
            throw NSError(domain: "EventStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Storage directory not available"])
        }
        
        let eventsFile = storageUrl.appendingPathComponent(EventStorageManager.EVENTS_FILE)
        
        // Check if file exists
        guard fileManager.fileExists(atPath: eventsFile.path) else {
            return []
        }
        
        // Read file
        let data = try Data(contentsOf: eventsFile)
        
        // Parse JSON
        guard let eventDicts = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "EventStorageManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format in stored events"])
        }
        
        // Convert dictionaries to events
        var events = [EventData]()
        for dict in eventDicts {
            if let event = EventData.fromDictionary(dict) {
                events.append(event)
            } else {
                Logger.warning("Failed to parse event from dictionary: \(dict)")
            }
        }
        
        Logger.debug("Loaded \(events.count) events from file: \(eventsFile.path)")
        
        return events
    }
    
    /// Clear all stored events
    /// - Throws: Error if clearing fails
    public func clearEvents() throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard let storageUrl = storageUrl else {
            throw NSError(domain: "EventStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Storage directory not available"])
        }
        
        let eventsFile = storageUrl.appendingPathComponent(EventStorageManager.EVENTS_FILE)
        
        // Check if file exists
        guard fileManager.fileExists(atPath: eventsFile.path) else {
            return
        }
        
        // Remove file
        try fileManager.removeItem(at: eventsFile)
        
        Logger.debug("Cleared stored events at: \(eventsFile.path)")
    }
    
    /// Check if storage exists
    /// - Returns: Whether storage exists
    public func hasStorage() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let storageUrl = storageUrl else {
            return false
        }
        
        let eventsFile = storageUrl.appendingPathComponent(EventStorageManager.EVENTS_FILE)
        return fileManager.fileExists(atPath: eventsFile.path)
    }
    
    /// Get the number of stored events
    /// - Returns: Number of events in storage
    /// - Throws: Error if counting fails
    public func getStoredEventCount() throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        guard let storageUrl = storageUrl else {
            throw NSError(domain: "EventStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Storage directory not available"])
        }
        
        let eventsFile = storageUrl.appendingPathComponent(EventStorageManager.EVENTS_FILE)
        
        // Check if file exists
        guard fileManager.fileExists(atPath: eventsFile.path) else {
            return 0
        }
        
        // Read file
        let data = try Data(contentsOf: eventsFile)
        
        // Parse JSON
        guard let eventDicts = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "EventStorageManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format in stored events"])
        }
        
        return eventDicts.count
    }
} 