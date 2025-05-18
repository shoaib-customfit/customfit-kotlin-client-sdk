import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../logging/logger.dart';
import '../../core/util/synchronization.dart';

/// A persistent queue for processing operations in the background.
/// Supports durability across app restarts and prioritization.
class BackgroundQueue {
  static const String _source = 'BackgroundQueue';

  /// Name of this queue instance (used for logging and persistence)
  final String _queueName;

  /// Path to the queue file
  late String _queueFilePath;

  /// Lock for queue operations
  final _queueLock = Object();

  /// Queue of pending operations
  final List<QueuedOperation> _pendingOperations = [];

  /// Whether the queue is currently being processed
  bool _isProcessing = false;

  /// Maximum retry count for failed operations
  final int _maxRetries;

  /// Whether the queue is paused
  bool _isPaused = false;

  /// Callback to execute for operations
  final Future<bool> Function(Map<String, dynamic> data) _processor;

  /// Whether the queue has been initialized
  bool _isInitialized = false;

  /// Completer for initialization
  final Completer<void> _initCompleter = Completer<void>();

  /// Create a new background queue
  ///
  /// [queueName] Name of this queue (used for logging and persistence)
  /// [processor] Callback to process operations
  /// [maxRetries] Maximum number of retries for failed operations
  BackgroundQueue({
    required String queueName,
    required Future<bool> Function(Map<String, dynamic> data) processor,
    int maxRetries = 3,
  })  : _queueName = queueName,
        _processor = processor,
        _maxRetries = maxRetries {
    _initialize();
  }

  /// Initialize the queue
  Future<void> _initialize() async {
    try {
      // Get directory for storing queue data
      final appDir = await getApplicationDocumentsDirectory();
      final queueDir = Directory('${appDir.path}/cf_queues');

      // Create directory if it doesn't exist
      if (!await queueDir.exists()) {
        await queueDir.create(recursive: true);
      }

      // Set queue file path
      _queueFilePath = '${queueDir.path}/${_queueName}_queue.json';

      Logger.d('Queue file path: $_queueFilePath');

      // Load persisted queue
      await _loadPersistedQueue();

      // Mark as initialized
      _isInitialized = true;
      _initCompleter.complete();

      Logger.i(
          'Background queue $_queueName initialized with ${_pendingOperations.length} operations');

      // Start processing if there are pending operations
      if (_pendingOperations.isNotEmpty) {
        _startProcessing();
      }
    } catch (e) {
      Logger.e('Error initializing background queue: $e');

      // Complete with error but don't rethrow to avoid crashing
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    }
  }

  /// Load previously persisted queue from disk
  Future<void> _loadPersistedQueue() async {
    try {
      final file = File(_queueFilePath);

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);

        synchronized(_queueLock, () {
          _pendingOperations.clear();

          for (final json in jsonList) {
            final op = QueuedOperation.fromJson(json);
            _pendingOperations.add(op);
          }

          // Sort by priority then timestamp
          _sortQueue();
        });

        Logger.d(
            'Loaded ${_pendingOperations.length} operations from persisted queue');
      }
    } catch (e) {
      Logger.e('Error loading persisted queue: $e');
      // Continue with empty queue on error
    }
  }

  /// Save queue to disk
  Future<void> _persistQueue() async {
    try {
      final file = File(_queueFilePath);

      final List<Map<String, dynamic>> jsonList = synchronized(_queueLock, () {
        return _pendingOperations.map((op) => op.toJson()).toList();
      });

      await file.writeAsString(jsonEncode(jsonList));
      Logger.d('Persisted ${jsonList.length} operations to queue file');
    } catch (e) {
      Logger.e('Error persisting queue: $e');
    }
  }

  /// Sort the queue by priority (higher first) then timestamp (older first)
  void _sortQueue() {
    synchronized(_queueLock, () {
      _pendingOperations.sort((a, b) {
        // Higher priority first
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;

        // Older timestamp first
        return a.timestamp.compareTo(b.timestamp);
      });
    });
  }

  /// Add an operation to the queue
  ///
  /// [data] The data for the operation
  /// [priority] Priority of the operation (higher is processed first)
  /// [uniqueKey] Optional key to ensure uniqueness (will replace existing operation with same key)
  Future<String> enqueue(
    Map<String, dynamic> data, {
    int priority = 0,
    String? uniqueKey,
  }) async {
    // Wait for initialization
    if (!_isInitialized) {
      await _initCompleter.future;
    }

    final String id = uniqueKey ?? const Uuid().v4();

    synchronized(_queueLock, () {
      // Check if operation with same uniqueKey exists
      if (uniqueKey != null) {
        final existingIndex =
            _pendingOperations.indexWhere((op) => op.id == uniqueKey);
        if (existingIndex != -1) {
          Logger.d('Replacing existing operation with uniqueKey: $uniqueKey');
          _pendingOperations.removeAt(existingIndex);
        }
      }

      // Add new operation
      final operation = QueuedOperation(
        id: id,
        data: data,
        priority: priority,
        timestamp: DateTime.now(),
        retryCount: 0,
      );

      _pendingOperations.add(operation);

      // Re-sort queue
      _sortQueue();
    });

    // Persist queue
    await _persistQueue();

    Logger.d('Enqueued operation with ID: $id (priority: $priority)');

    // Start processing if not already running
    if (!_isProcessing && !_isPaused) {
      _startProcessing();
    }

    return id;
  }

  /// Start processing the queue
  void _startProcessing() {
    synchronized(_queueLock, () {
      if (_isProcessing || _isPaused || _pendingOperations.isEmpty) {
        return;
      }

      _isProcessing = true;
    });

    Logger.d('Starting queue processing');

    // Process outside of the lock
    _processNextOperation();
  }

  /// Process the next operation in the queue
  Future<void> _processNextOperation() async {
    QueuedOperation? operation;

    // Get the next operation under the lock
    synchronized(_queueLock, () {
      if (_pendingOperations.isEmpty || _isPaused) {
        _isProcessing = false;
        return;
      }

      operation = _pendingOperations.first;
    });

    // If no operation or paused, stop processing
    if (operation == null) {
      synchronized(_queueLock, () {
        _isProcessing = false;
      });
      return;
    }

    try {
      Logger.d('Processing operation: ${operation!.id}');

      // Process the operation
      final success = await _processor(operation!.data);

      // Remove operation if successful
      if (success) {
        synchronized(_queueLock, () {
          _pendingOperations.remove(operation);
        });

        Logger.d('Operation processed successfully: ${operation!.id}');

        // Persist queue
        await _persistQueue();

        // Process next operation
        _processNextOperation();
      } else {
        // Handle retry
        await _handleRetry(operation!);
      }
    } catch (e) {
      Logger.e('Error processing operation ${operation!.id}: $e');

      // Handle retry
      await _handleRetry(operation!);
    }
  }

  /// Handle retry logic for a failed operation
  Future<void> _handleRetry(QueuedOperation operation) async {
    synchronized(_queueLock, () {
      // Remove from current position
      _pendingOperations.remove(operation);

      // If under retry limit, increment retry count and requeue
      if (operation.retryCount < _maxRetries) {
        final updatedOp = operation.copyWithIncrementedRetry();

        // Move to end of its priority level
        _pendingOperations.add(updatedOp);

        // Re-sort queue
        _sortQueue();

        Logger.w(
            'Operation ${operation.id} failed, retrying (${updatedOp.retryCount}/$_maxRetries)');
      } else {
        // Operation failed permanently
        Logger.e(
            'Operation ${operation.id} failed permanently after ${operation.retryCount} retries');
      }
    });

    // Persist queue
    await _persistQueue();

    // Process next operation
    _processNextOperation();
  }

  /// Pause queue processing
  void pause() {
    synchronized(_queueLock, () {
      _isPaused = true;
      Logger.i('Queue $_queueName paused');
    });
  }

  /// Resume queue processing
  void resume() {
    final shouldStart = synchronized(_queueLock, () {
      final wasPaused = _isPaused;
      _isPaused = false;
      Logger.i('Queue $_queueName resumed');
      return wasPaused && !_isProcessing && _pendingOperations.isNotEmpty;
    });

    if (shouldStart) {
      _startProcessing();
    }
  }

  /// Get number of pending operations
  int getPendingCount() {
    return synchronized(_queueLock, () => _pendingOperations.length);
  }

  /// Check if operation with given ID exists in the queue
  bool containsOperation(String id) {
    return synchronized(
        _queueLock, () => _pendingOperations.any((op) => op.id == id));
  }

  /// Remove an operation from the queue by ID
  Future<bool> removeOperation(String id) async {
    final removed = synchronized(_queueLock, () {
      final index = _pendingOperations.indexWhere((op) => op.id == id);

      if (index == -1) {
        return false;
      }

      _pendingOperations.removeAt(index);
      return true;
    });

    if (removed) {
      await _persistQueue();
      Logger.d('Removed operation with ID: $id');
    }

    return removed;
  }

  /// Clear all operations from the queue
  Future<void> clear() async {
    synchronized(_queueLock, () {
      _pendingOperations.clear();
    });

    await _persistQueue();
    Logger.i('Cleared all operations from queue $_queueName');
  }

  /// Flush the queue, processing all operations immediately
  Future<int> flush() async {
    // Wait for initialization
    if (!_isInitialized) {
      await _initCompleter.future;
    }

    final operations = synchronized<List<QueuedOperation>>(_queueLock, () {
      return List.from(_pendingOperations);
    });

    int successCount = 0;

    // Process all operations
    for (final operation in operations) {
      try {
        Logger.d('Flushing operation: ${operation.id}');

        // Process the operation
        final success = await _processor(operation.data);

        if (success) {
          synchronized(_queueLock, () {
            _pendingOperations.remove(operation);
          });

          successCount++;
          Logger.d('Successfully flushed operation: ${operation.id}');
        } else {
          Logger.w('Failed to flush operation: ${operation.id}');
        }
      } catch (e) {
        Logger.e('Error flushing operation ${operation.id}: $e');
      }
    }

    // Persist queue
    await _persistQueue();

    Logger.i(
        'Flushed $successCount/${operations.length} operations from queue $_queueName');

    return successCount;
  }

  /// Shutdown the queue
  Future<void> shutdown() async {
    // Pause processing
    pause();

    // Persist queue to ensure no operations are lost
    await _persistQueue();

    Logger.i('Queue $_queueName shut down');
  }
}

/// Represents an operation in the queue
class QueuedOperation {
  final String id;
  final Map<String, dynamic> data;
  final int priority;
  final DateTime timestamp;
  final int retryCount;

  QueuedOperation({
    required this.id,
    required this.data,
    required this.priority,
    required this.timestamp,
    required this.retryCount,
  });

  /// Create a new instance with incremented retry count
  QueuedOperation copyWithIncrementedRetry() {
    return QueuedOperation(
      id: id,
      data: data,
      priority: priority,
      timestamp: timestamp,
      retryCount: retryCount + 1,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data,
      'priority': priority,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'retryCount': retryCount,
    };
  }

  /// Create from JSON
  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'],
      data: json['data'],
      priority: json['priority'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      retryCount: json['retryCount'],
    );
  }
}
