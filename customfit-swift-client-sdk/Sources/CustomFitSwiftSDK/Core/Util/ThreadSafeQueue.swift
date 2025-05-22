import Foundation

/// A thread-safe queue implementation that mimics Java's LinkedBlockingQueue
public class ThreadSafeQueue<T> {
    
    // MARK: - Properties
    
    /// Internal storage
    private var elements = [T]()
    
    /// Capacity of the queue
    private let capacity: Int
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Condition for signaling when queue state changes
    private let condition = NSCondition()
    
    /// Current queue count
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return elements.count
    }
    
    /// Whether the queue is empty
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return elements.isEmpty
    }
    
    /// Whether the queue is full
    public var isFull: Bool {
        lock.lock()
        defer { lock.unlock() }
        return elements.count >= capacity
    }
    
    // MARK: - Initialization
    
    /// Initialize a new ThreadSafeQueue with the specified capacity
    /// - Parameter capacity: Maximum capacity
    public init(capacity: Int) {
        self.capacity = capacity
    }
    
    // MARK: - Queue Operations
    
    /// Add an element to the queue if there is space
    /// - Parameter element: Element to add
    /// - Returns: Whether the element was added
    public func enqueue(_ element: T) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        if elements.count >= capacity {
            return false
        }
        
        elements.append(element)
        condition.signal()
        return true
    }
    
    /// Add an element to the queue, waiting if necessary until space becomes available
    /// - Parameters:
    ///   - element: Element to add
    ///   - timeout: Optional timeout in seconds
    /// - Returns: Whether the element was added
    /// - Throws: Error if the operation times out
    public func enqueueBlocking(_ element: T, timeout: TimeInterval? = nil) throws -> Bool {
        condition.lock()
        defer { condition.unlock() }
        
        let startTime = Date()
        
        while true {
            lock.lock()
            let isFull = elements.count >= capacity
            lock.unlock()
            
            if !isFull {
                lock.lock()
                elements.append(element)
                lock.unlock()
                condition.signal()
                return true
            }
            
            if let timeout = timeout {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed >= timeout {
                    throw NSError(domain: "ThreadSafeQueue", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enqueue operation timed out"])
                }
                
                let remaining = timeout - elapsed
                let result = condition.wait(until: Date(timeIntervalSinceNow: remaining))
                if !result {
                    throw NSError(domain: "ThreadSafeQueue", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enqueue operation timed out"])
                }
            } else {
                condition.wait()
            }
        }
    }
    
    /// Remove and return the first element from the queue, or nil if the queue is empty
    /// - Returns: First element or nil
    public func dequeue() -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        if elements.isEmpty {
            return nil
        }
        
        return elements.removeFirst()
    }
    
    /// Remove and return the first element from the queue, waiting if necessary until an element is available
    /// - Parameter timeout: Optional timeout in seconds
    /// - Returns: First element
    /// - Throws: Error if the operation times out
    public func dequeueBlocking(timeout: TimeInterval? = nil) throws -> T? {
        condition.lock()
        defer { condition.unlock() }
        
        let startTime = Date()
        
        while true {
            lock.lock()
            let isEmpty = elements.isEmpty
            let element = isEmpty ? nil : elements.removeFirst()
            lock.unlock()
            
            if !isEmpty {
                condition.signal()
                return element
            }
            
            if let timeout = timeout {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed >= timeout {
                    throw NSError(domain: "ThreadSafeQueue", code: 2, userInfo: [NSLocalizedDescriptionKey: "Dequeue operation timed out"])
                }
                
                let remaining = timeout - elapsed
                let result = condition.wait(until: Date(timeIntervalSinceNow: remaining))
                if !result {
                    throw NSError(domain: "ThreadSafeQueue", code: 2, userInfo: [NSLocalizedDescriptionKey: "Dequeue operation timed out"])
                }
            } else {
                condition.wait()
            }
        }
    }
    
    /// Look at the first element without removing it
    /// - Returns: First element or nil
    public func peek() -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        return elements.first
    }
    
    /// Remove all elements from the queue to the provided array
    /// - Parameter array: Array to fill
    /// - Returns: Number of elements drained
    @discardableResult
    public func drainTo(_ array: inout [T]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        let count = elements.count
        array.append(contentsOf: elements)
        elements.removeAll()
        return count
    }
    
    /// Get a snapshot of the current elements without modifying the queue
    /// - Returns: Array of elements
    public func snapshot() -> [T] {
        lock.lock()
        defer { lock.unlock() }
        
        return elements
    }
    
    /// Clear the queue
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        elements.removeAll()
    }
    
    /// Offer multiple elements to the queue, adding as many as possible before capacity is reached
    /// - Parameter elements: Elements to add
    /// - Returns: Number of elements successfully added
    @discardableResult
    public func offerAll(_ elements: [T]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        let remainingCapacity = capacity - self.elements.count
        
        if remainingCapacity <= 0 {
            return 0
        }
        
        let elementsToAdd = min(elements.count, remainingCapacity)
        self.elements.append(contentsOf: elements.prefix(elementsToAdd))
        
        return elementsToAdd
    }
} 