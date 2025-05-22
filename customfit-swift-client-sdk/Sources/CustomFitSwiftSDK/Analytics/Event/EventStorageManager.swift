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
    
    /// Events file URL
    private var eventsFile: URL {
        guard let storageUrl = storageUrl else {
            fatalError("Storage URL not available")
        }
        return storageUrl.appendingPathComponent(EventStorageManager.EVENTS_FILE)
    }
    
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
    
    /// Create storage directory if it doesn't exist
    /// - Throws: Error if directory creation fails
    private func createStorageDirectoryIfNeeded() throws {
        guard let storageUrl = storageUrl else {
            throw NSError(domain: "EventStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Storage directory not available"])
        }
        
        if !fileManager.fileExists(atPath: storageUrl.path) {
            try fileManager.createDirectory(at: storageUrl, withIntermediateDirectories: true)
            Logger.debug("Created event storage directory: \(storageUrl.path)")
        }
    }
    
    /// Store events to disk
    /// - Parameter events: Events to store
    /// - Throws: Error if storage fails
    func storeEvents(events: [EventData]) throws {
        // Create directory if needed
        try createStorageDirectoryIfNeeded()
        
        // Convert events to dictionaries
        let eventDicts = events.map { $0.toDictionary() }
        
        // Serialize to JSON
        let data = try JSONSerialization.data(withJSONObject: eventDicts, options: [.prettyPrinted])
        
        // Write to file
        try data.write(to: eventsFile, options: .atomicWrite)
        
        Logger.debug("Stored \(events.count) events to file: \(eventsFile.path)")
    }
    
    /// Load events from disk
    /// - Returns: Loaded events
    /// - Throws: Error if loading fails
    func loadEvents() throws -> [EventData] {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: eventsFile.path) else {
            Logger.debug("No events file exists at: \(eventsFile.path)")
            return []
        }
        
        // Read data
        let data = try Data(contentsOf: eventsFile)
        
        // Parse JSON
        guard let eventDicts = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            throw NSError(domain: "EventStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid event data format"])
        }
        
        // Convert to EventData objects
        var events = [EventData]()
        for dict in eventDicts {
            if let event = EventData.fromDictionary(dict) {
                events.append(event)
            } else {
                Logger.warning("Failed to parse event from stored data")
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