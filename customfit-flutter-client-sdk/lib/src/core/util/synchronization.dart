import 'dart:async';
import 'dart:collection';

/// Implements a simple mutex-like synchronization primitive in Dart
class Mutex {
  final Completer<void> _completer = Completer<void>()..complete();
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();
  bool _locked = false;

  /// Acquires the lock. If the lock is already held, this will wait until it's released.
  Future<void> acquire() async {
    // Fast path - if not locked, acquire immediately
    if (!_locked) {
      _locked = true;
      return;
    }

    // Slow path - wait in the queue
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
  }

  /// Releases the lock and allows the next waiter to acquire it.
  void release() {
    if (!_locked) {
      throw StateError('Cannot release a mutex that is not locked');
    }

    if (_waitQueue.isEmpty) {
      _locked = false;
    } else {
      // Complete the next waiter
      final nextCompleter = _waitQueue.removeFirst();
      nextCompleter.complete();
    }
  }

  /// Checks if the mutex is currently locked
  bool get isLocked => _locked;

  /// Executes a function within a lock and safely releases it afterward
  Future<T> withLock<T>(Future<T> Function() fn) async {
    await acquire();
    try {
      return await fn();
    } finally {
      release();
    }
  }

  /// Executes a synchronous function within a lock
  T withLockSync<T>(T Function() fn) {
    acquire(); // Acquires immediately since it's sync
    try {
      return fn();
    } finally {
      release();
    }
  }
}

/// Implements a read-write lock for concurrent reads, exclusive writes
class ReadWriteLock {
  int _readers = 0;
  bool _writing = false;
  final Queue<Completer<void>> _writeQueue = Queue<Completer<void>>();
  final Queue<Completer<void>> _readQueue = Queue<Completer<void>>();

  /// Acquires a read lock, allowing concurrent reads but no writes
  Future<void> acquireRead() async {
    // If no writers and no queued writers, grant read immediately
    if (!_writing && _writeQueue.isEmpty) {
      _readers++;
      return;
    }

    // Otherwise wait in the read queue
    final completer = Completer<void>();
    _readQueue.add(completer);
    await completer.future;
  }

  /// Releases a read lock
  void releaseRead() {
    if (_readers <= 0) {
      throw StateError('Cannot release a read lock that is not held');
    }

    _readers--;
    _grantNextLock();
  }

  /// Acquires a write lock, which is exclusive (no concurrent reads or writes)
  Future<void> acquireWrite() async {
    // If no readers and no writers, grant write immediately
    if (_readers == 0 && !_writing) {
      _writing = true;
      return;
    }

    // Otherwise wait in the write queue
    final completer = Completer<void>();
    _writeQueue.add(completer);
    await completer.future;
  }

  /// Releases a write lock
  void releaseWrite() {
    if (!_writing) {
      throw StateError('Cannot release a write lock that is not held');
    }

    _writing = false;
    _grantNextLock();
  }

  /// Grants the next lock based on queue priority
  void _grantNextLock() {
    // If there are waiting writers and no active readers, grant the next write lock
    if (_writeQueue.isNotEmpty && _readers == 0 && !_writing) {
      _writing = true;
      final completer = _writeQueue.removeFirst();
      completer.complete();
      return;
    }

    // Otherwise, if no active writers, grant all waiting read locks
    if (_readQueue.isNotEmpty && !_writing) {
      while (_readQueue.isNotEmpty) {
        _readers++;
        final completer = _readQueue.removeFirst();
        completer.complete();
      }
    }
  }

  /// Executes a function with a read lock
  Future<T> withReadLock<T>(Future<T> Function() fn) async {
    await acquireRead();
    try {
      return await fn();
    } finally {
      releaseRead();
    }
  }

  /// Executes a function with a write lock
  Future<T> withWriteLock<T>(Future<T> Function() fn) async {
    await acquireWrite();
    try {
      return await fn();
    } finally {
      releaseWrite();
    }
  }
}

/// ReentrantLock allows the same thread (in this case, zone) to acquire
/// the lock multiple times without deadlocking
class ReentrantLock {
  int _holdCount = 0;
  final Mutex _mutex = Mutex();
  Zone? _ownerZone;

  /// Acquires the lock, allowing reentrant acquires
  Future<void> acquire() async {
    final currentZone = Zone.current;

    // If we already own the lock, just increment hold count
    if (_ownerZone == currentZone) {
      _holdCount++;
      return;
    }

    // Otherwise actually acquire the lock
    await _mutex.acquire();
    _ownerZone = currentZone;
    _holdCount = 1;
  }

  /// Releases the lock, only fully releasing when all holds are released
  void release() {
    if (_ownerZone != Zone.current) {
      throw StateError('Cannot release a lock owned by another zone');
    }

    _holdCount--;
    if (_holdCount == 0) {
      _ownerZone = null;
      _mutex.release();
    }
  }

  /// Executes a function within the lock
  Future<T> withLock<T>(Future<T> Function() fn) async {
    await acquire();
    try {
      return await fn();
    } finally {
      release();
    }
  }
}

// Keep a global cache of mutexes for lock objects
final Map<Object, Mutex> _synchronizedMutexes = {};
final Map<Object, Mutex> _asyncMutexes = {};

/// Improves on the previous synchronized implementation by using a map of Mutex objects
/// This approach provides actual locking when used with async functions
T synchronized<T>(Object lock, T Function() fn) {
  // Get or create a mutex for this lock
  final mutex = _synchronizedMutexes.putIfAbsent(lock, () => Mutex());

  // If the function is synchronous, use sync version to avoid async overhead
  return mutex.withLockSync(fn);
}

/// Similar to synchronized but works with async functions
Future<T> synchronizedAsync<T>(Object lock, Future<T> Function() fn) async {
  // Get or create a mutex for this lock
  final mutex = _asyncMutexes.putIfAbsent(lock, () => Mutex());

  // Use the async version of withLock
  return await mutex.withLock(fn);
}
