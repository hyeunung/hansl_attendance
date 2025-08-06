import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Advanced async operation management with cancellation tokens
/// Optimizes database queries, prevents memory leaks, and handles timeouts
class AsyncOperationManager {
  static final AsyncOperationManager _instance = AsyncOperationManager._internal();
  static AsyncOperationManager get instance => _instance;
  AsyncOperationManager._internal();

  // Active operations tracking
  final Map<String, CancellableOperation> _operations = {};
  
  // Operation queues for sequential execution
  final Map<String, Queue<QueuedOperation>> _queues = {};
  final Map<String, bool> _queueProcessing = {};
  
  // Statistics
  int _totalOperationsStarted = 0;
  int _totalOperationsCompleted = 0;
  int _totalOperationsCancelled = 0;
  int _totalOperationsTimedOut = 0;

  /// Execute operation with cancellation support and timeout
  Future<T> execute<T>({
    required String key,
    required Future<T> Function(CancellationToken token) operation,
    Duration? timeout,
    bool cancelPrevious = true,
    String? description,
  }) async {
    // Cancel previous operation if requested
    if (cancelPrevious && _operations.containsKey(key)) {
      await cancelOperation(key);
    }
    
    // Check for duplicate operation
    if (_operations.containsKey(key)) {
      if (kDebugMode) print('⚠️ Operation already running: $key');
      throw StateError('Operation already in progress: $key');
    }
    
    final token = CancellationToken();
    final completer = Completer<T>();
    final cancellableOp = CancellableOperation(
      key: key,
      token: token,
      completer: completer,
      description: description,
      startTime: DateTime.now(),
    );
    
    _operations[key] = cancellableOp;
    _totalOperationsStarted++;
    
    if (kDebugMode) {
      print('🚀 Starting operation: $key${description != null ? ' ($description)' : ''}');
    }
    
    // Execute with optional timeout
    Future<T> executionFuture = _executeWithCancellation(operation, token, key);
    
    if (timeout != null) {
      executionFuture = executionFuture.timeout(
        timeout,
        onTimeout: () {
          _totalOperationsTimedOut++;
          token.cancel('Operation timed out after ${timeout.inMilliseconds}ms');
          throw TimeoutException('Operation timed out', timeout);
        },
      );
    }
    
    try {
      final result = await executionFuture;
      
      if (!token.isCancelled) {
        completer.complete(result);
        _totalOperationsCompleted++;
        
        if (kDebugMode) {
          final duration = DateTime.now().difference(cancellableOp.startTime);
          print('✅ Operation completed: $key (${duration.inMilliseconds}ms)');
        }
      }
      
      return result;
    } catch (e) {
      if (token.isCancelled) {
        _totalOperationsCancelled++;
        if (kDebugMode) print('❌ Operation cancelled: $key');
      } else {
        if (kDebugMode) print('❌ Operation failed: $key - $e');
      }
      
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    } finally {
      _operations.remove(key);
    }
  }
  
  /// Execute operation in a sequential queue
  Future<T> executeInQueue<T>({
    required String queueKey,
    required String operationKey,
    required Future<T> Function(CancellationToken token) operation,
    Duration? timeout,
    int priority = 0,
    String? description,
  }) async {
    final completer = Completer<T>();
    final token = CancellationToken();
    
    final queuedOp = QueuedOperation(
      key: operationKey,
      operation: () async {
        try {
          final result = await execute<T>(
            key: '${queueKey}_$operationKey',
            operation: operation,
            timeout: timeout,
            cancelPrevious: false,
            description: description,
          );
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      },
      priority: priority,
      token: token,
      description: description,
    );
    
    // Add to queue
    final queue = _queues.putIfAbsent(queueKey, () => Queue<QueuedOperation>());
    queue.add(queuedOp);
    
    // Sort queue by priority
    final items = queue.toList();
    items.sort((a, b) => b.priority.compareTo(a.priority));
    queue.clear();
    queue.addAll(items);
    
    // Start processing queue if not already running
    _processQueue(queueKey);
    
    return completer.future;
  }
  
  /// Batch execute multiple operations with individual cancellation
  Future<Map<String, T?>> executeBatch<T>({
    required Map<String, Future<T> Function(CancellationToken token)> operations,
    Duration? timeout,
    bool failFast = false,
    bool cancelPrevious = true,
  }) async {
    final results = <String, T?>{};
    final batchToken = CancellationToken();
    
    try {
      if (failFast) {
        // Execute in parallel, fail on first error
        final futures = <String, Future<T>>{};
        
        for (final entry in operations.entries) {
          final key = 'batch_${entry.key}_${DateTime.now().millisecondsSinceEpoch}';
          futures[entry.key] = execute<T>(
            key: key,
            operation: entry.value,
            timeout: timeout,
            cancelPrevious: cancelPrevious,
          );
        }
        
        final completedResults = await Future.wait(futures.values);
        int index = 0;
        for (final key in futures.keys) {
          results[key] = completedResults[index++];
        }
      } else {
        // Execute in parallel, capture individual errors
        final futures = <String, Future<T?>>{};
        
        for (final entry in operations.entries) {
          final key = 'batch_${entry.key}_${DateTime.now().millisecondsSinceEpoch}';
          futures[entry.key] = execute<T>(
            key: key,
            operation: entry.value,
            timeout: timeout,
            cancelPrevious: cancelPrevious,
          ).catchError((e) {
            if (kDebugMode) print('⚠️ Batch operation failed: ${entry.key} - $e');
            return null;
          });
        }
        
        final settledResults = await Future.wait(futures.values);
        int index = 0;
        for (final key in futures.keys) {
          results[key] = settledResults[index++];
        }
      }
    } catch (e) {
      batchToken.cancel('Batch execution failed');
      rethrow;
    }
    
    return results;
  }
  
  /// Cancel a specific operation
  Future<bool> cancelOperation(String key) async {
    final operation = _operations[key];
    if (operation == null) return false;
    
    operation.token.cancel('Operation cancelled by request');
    
    try {
      await operation.completer.future.timeout(const Duration(seconds: 1));
    } catch (e) {
      // Expected for cancelled operations
    }
    
    _operations.remove(key);
    return true;
  }
  
  /// Cancel operations by prefix
  Future<int> cancelOperationsByPrefix(String prefix) async {
    final keysToCancel = _operations.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    
    int cancelledCount = 0;
    for (final key in keysToCancel) {
      if (await cancelOperation(key)) {
        cancelledCount++;
      }
    }
    
    if (cancelledCount > 0 && kDebugMode) {
      print('❌ Cancelled $cancelledCount operations with prefix: $prefix');
    }
    
    return cancelledCount;
  }
  
  /// Cancel all active operations
  Future<int> cancelAllOperations() async {
    final keys = _operations.keys.toList();
    int cancelledCount = 0;
    
    for (final key in keys) {
      if (await cancelOperation(key)) {
        cancelledCount++;
      }
    }
    
    if (cancelledCount > 0 && kDebugMode) {
      print('❌ Cancelled all operations: $cancelledCount operations');
    }
    
    return cancelledCount;
  }
  
  /// Check if operation is active
  bool isOperationActive(String key) {
    return _operations.containsKey(key);
  }
  
  /// Get active operation keys
  List<String> getActiveOperationKeys() {
    return List.unmodifiable(_operations.keys);
  }
  
  /// Get operation statistics
  AsyncOperationStats getStats() {
    return AsyncOperationStats(
      activeOperations: _operations.length,
      totalStarted: _totalOperationsStarted,
      totalCompleted: _totalOperationsCompleted,
      totalCancelled: _totalOperationsCancelled,
      totalTimedOut: _totalOperationsTimedOut,
      activeQueues: _queues.length,
      activeOperationKeys: List.unmodifiable(_operations.keys),
    );
  }
  
  // Private methods
  
  Future<T> _executeWithCancellation<T>(
    Future<T> Function(CancellationToken token) operation,
    CancellationToken token,
    String key,
  ) async {
    return await operation(token);
  }
  
  Future<void> _processQueue(String queueKey) async {
    if (_queueProcessing[queueKey] == true) return;
    
    _queueProcessing[queueKey] = true;
    final queue = _queues[queueKey];
    
    if (queue == null) {
      _queueProcessing[queueKey] = false;
      return;
    }
    
    try {
      while (queue.isNotEmpty) {
        final operation = queue.removeFirst();
        
        if (operation.token.isCancelled) {
          if (kDebugMode) print('⏭️ Skipping cancelled queued operation: ${operation.key}');
          continue;
        }
        
        if (kDebugMode) {
          print('🔄 Processing queued operation: ${operation.key}');
        }
        
        try {
          await operation.operation();
        } catch (e) {
          if (kDebugMode) print('❌ Queued operation failed: ${operation.key} - $e');
        }
      }
    } finally {
      _queueProcessing[queueKey] = false;
      
      // Clean up empty queue
      if (queue.isEmpty) {
        _queues.remove(queueKey);
      }
    }
  }
  
  /// Dispose all resources
  Future<void> dispose() async {
    await cancelAllOperations();
    
    // Clear queues
    for (final queue in _queues.values) {
      for (final operation in queue) {
        operation.token.cancel('Manager disposed');
      }
      queue.clear();
    }
    _queues.clear();
    _queueProcessing.clear();
    
    if (kDebugMode) print('🗑️ AsyncOperationManager disposed');
  }
}

/// Cancellation token for async operations
class CancellationToken {
  bool _isCancelled = false;
  String? _reason;
  final List<void Function()> _listeners = [];
  
  bool get isCancelled => _isCancelled;
  String? get reason => _reason;
  
  void cancel([String? reason]) {
    if (_isCancelled) return;
    
    _isCancelled = true;
    _reason = reason;
    
    // Notify all listeners
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        if (kDebugMode) print('⚠️ Error in cancellation listener: $e');
      }
    }
    
    _listeners.clear();
  }
  
  void onCancelled(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
  
  void throwIfCancelled() {
    if (_isCancelled) {
      throw OperationCancelledException(_reason ?? 'Operation was cancelled');
    }
  }
}

/// Exception thrown when operation is cancelled
class OperationCancelledException implements Exception {
  final String message;
  
  OperationCancelledException(this.message);
  
  @override
  String toString() => 'OperationCancelledException: $message';
}

/// Data class for operation statistics
class AsyncOperationStats {
  final int activeOperations;
  final int totalStarted;
  final int totalCompleted;
  final int totalCancelled;
  final int totalTimedOut;
  final int activeQueues;
  final List<String> activeOperationKeys;
  
  const AsyncOperationStats({
    required this.activeOperations,
    required this.totalStarted,
    required this.totalCompleted,
    required this.totalCancelled,
    required this.totalTimedOut,
    required this.activeQueues,
    required this.activeOperationKeys,
  });
  
  int get totalFinished => totalCompleted + totalCancelled + totalTimedOut;
  double get successRate => totalStarted > 0 ? totalCompleted / totalStarted : 0.0;
  double get cancellationRate => totalStarted > 0 ? totalCancelled / totalStarted : 0.0;
  
  @override
  String toString() {
    return 'AsyncOperationStats(active: $activeOperations, started: $totalStarted, '
           'completed: $totalCompleted, cancelled: $totalCancelled, '
           'timedOut: $totalTimedOut, queues: $activeQueues)';
  }
  
  Map<String, dynamic> toJson() {
    return {
      'active_operations': activeOperations,
      'total_started': totalStarted,
      'total_completed': totalCompleted,
      'total_cancelled': totalCancelled,
      'total_timed_out': totalTimedOut,
      'total_finished': totalFinished,
      'success_rate': successRate,
      'cancellation_rate': cancellationRate,
      'active_queues': activeQueues,
      'active_operation_keys': activeOperationKeys,
    };
  }
}

/// Internal class for tracking cancellable operations
class CancellableOperation {
  final String key;
  final CancellationToken token;
  final Completer completer;
  final String? description;
  final DateTime startTime;
  
  CancellableOperation({
    required this.key,
    required this.token,
    required this.completer,
    this.description,
    required this.startTime,
  });
}

/// Internal class for queued operations
class QueuedOperation {
  final String key;
  final Future<void> Function() operation;
  final int priority;
  final CancellationToken token;
  final String? description;
  
  QueuedOperation({
    required this.key,
    required this.operation,
    required this.priority,
    required this.token,
    this.description,
  });
}

/// Mixin for easy async operation management integration
mixin AsyncOperationMixin {
  final AsyncOperationManager _asyncManager = AsyncOperationManager.instance;
  
  /// Create a scoped operation key with object hash
  String _scopedOperationKey(String key) => '${runtimeType.toString()}_${hashCode}_$key';
  
  /// Execute scoped async operation
  Future<T> executeScopedOperation<T>({
    required String key,
    required Future<T> Function(CancellationToken token) operation,
    Duration? timeout,
    bool cancelPrevious = true,
    String? description,
  }) {
    return _asyncManager.execute<T>(
      key: _scopedOperationKey(key),
      operation: operation,
      timeout: timeout,
      cancelPrevious: cancelPrevious,
      description: description,
    );
  }
  
  /// Cancel a scoped operation
  Future<bool> cancelScopedOperation(String key) {
    return _asyncManager.cancelOperation(_scopedOperationKey(key));
  }
  
  /// Cancel all operations for this object
  Future<int> cancelAllScopedOperations() {
    return _asyncManager.cancelOperationsByPrefix('${runtimeType.toString()}_$hashCode');
  }
  
  /// Dispose scoped operations (call from dispose method)
  Future<void> disposeScopedOperations() async {
    final cancelledCount = await cancelAllScopedOperations();
    if (kDebugMode && cancelledCount > 0) {
      print('🗑️ Disposed $cancelledCount scoped operations for ${runtimeType.toString()}');
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  final Duration? duration;
  
  TimeoutException(this.message, this.duration);
  
  @override
  String toString() => 'TimeoutException: $message${duration != null ? ' (${duration!.inMilliseconds}ms)' : ''}';
}