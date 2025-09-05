import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'timer_manager.dart';

/// Request batching and deduplication utilities
/// Optimizes network requests by combining multiple requests into batches
/// and preventing duplicate concurrent requests
class RequestUtils with TimerManagementMixin {
  static final RequestUtils _instance = RequestUtils._internal();
  static RequestUtils get instance => _instance;
  RequestUtils._internal();

  // Request deduplication tracking
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  // Request batching
  final Map<String, _BatchGroup> _batchGroups = {};
  Timer? _batchTimer;

  static const Duration _batchWindow = Duration(milliseconds: 100);
  static const int _maxBatchSize = 10;

  /// Execute request with deduplication
  /// Multiple identical requests will return the same result
  Future<T> dedupedRequest<T>({required String key, required Future<T> Function() request}) async {
    // Check if there's already a pending request
    if (_pendingRequests.containsKey(key)) {
      if (kDebugMode) print('🔄 Deduplicating request: $key');
      return await _pendingRequests[key]!.future as T;
    }

    // Create new request
    final completer = Completer<T>();
    _pendingRequests[key] = completer;

    try {
      final result = await request();
      completer.complete(result);
      return result;
    } catch (error) {
      completer.completeError(error);
      rethrow;
    } finally {
      _pendingRequests.remove(key);
    }
  }

  /// Add request to batch group
  /// Requests in the same group will be executed together
  Future<T> batchedRequest<T>({
    required String groupKey,
    required String requestKey,
    required Future<T> Function() request,
    Duration? window,
  }) async {
    final effectiveWindow = window ?? _batchWindow;

    // Get or create batch group
    _BatchGroup<T> group =
        _batchGroups.putIfAbsent(groupKey, () => _BatchGroup<T>()) as _BatchGroup<T>;

    // Create batch item
    final batchItem = _BatchItem<T>(key: requestKey, request: request, completer: Completer<T>());

    group.items.add(batchItem);

    // Start batch timer if not already running
    createScopedTimer(
      key: 'batch_execution',
      delay: effectiveWindow,
      callback: () => _executeBatches(),
      forceRestart: true,
    );

    // Limit batch size
    if (group.items.length >= _maxBatchSize) {
      await _executeBatch(groupKey, group);
    }

    return batchItem.completer.future;
  }

  /// Execute all pending batches
  Future<void> _executeBatches() async {
    final groups = Map<String, _BatchGroup>.from(_batchGroups);
    _batchGroups.clear();

    for (final entry in groups.entries) {
      await _executeBatch(entry.key, entry.value);
    }
  }

  /// Execute a specific batch group
  Future<void> _executeBatch(String groupKey, _BatchGroup group) async {
    if (group.items.isEmpty) return;

    if (kDebugMode)
      if (kDebugMode) print('📦 Executing batch: $groupKey (${group.items.length} requests)');

    // Execute all requests in parallel
    final futures = group.items.map((item) async {
      try {
        final result = await item.request();
        item.completer.complete(result);
      } catch (error) {
        item.completer.completeError(error);
      }
    }).toList();

    await Future.wait(futures, eagerError: false);
  }

  /// Clear all pending requests and batches
  void clear() {
    // Cancel pending requests
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Request cancelled'));
      }
    }
    _pendingRequests.clear();

    // Cancel batch requests
    for (final group in _batchGroups.values) {
      for (final item in group.items) {
        if (!item.completer.isCompleted) {
          item.completer.completeError(Exception('Batch cancelled'));
        }
      }
    }
    _batchGroups.clear();

    disposeScopedTimers();
  }

  /// Get request statistics
  Map<String, dynamic> getStats() {
    return {
      'pending_requests': _pendingRequests.length,
      'batch_groups': _batchGroups.length,
      'total_batched_items': _batchGroups.values.fold<int>(
        0,
        (sum, group) => sum + group.items.length,
      ),
      'batch_timer_active': _batchTimer?.isActive ?? false,
    };
  }
}

class _BatchGroup<T> {
  final List<_BatchItem<T>> items = [];
}

class _BatchItem<T> {
  final String key;
  final Future<T> Function() request;
  final Completer<T> completer;

  _BatchItem({required this.key, required this.request, required this.completer});
}

/// Request queue for sequential execution
/// Useful for operations that must be executed in order
class RequestQueue {
  final Queue<_QueueItem> _queue = Queue();
  bool _processing = false;

  /// Add request to queue
  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() request,
    int priority = 0,
  }) async {
    final completer = Completer<T>();
    final item = _QueueItem(
      key: key,
      request: () async {
        try {
          final result = await request();
          completer.complete(result);
        } catch (error) {
          completer.completeError(error);
        }
      },
      priority: priority,
      completer: completer,
    );

    _queue.add(item);

    // Sort by priority (higher priority first)
    final items = _queue.toList();
    items.sort((a, b) => b.priority.compareTo(a.priority));
    _queue.clear();
    _queue.addAll(items);

    _processQueue();
    return completer.future;
  }

  /// Process queue items
  Future<void> _processQueue() async {
    if (_processing || _queue.isEmpty) return;

    _processing = true;

    while (_queue.isNotEmpty) {
      final item = _queue.removeFirst();
      if (kDebugMode) print('🔄 Processing queued request: ${item.key}');

      try {
        await item.request();
      } catch (e) {
        if (kDebugMode) print('❌ Queue item failed: ${item.key} - $e');
      }
    }

    _processing = false;
  }

  /// Clear all queued requests
  void clear() {
    for (final item in _queue) {
      if (!item.completer.isCompleted) {
        item.completer.completeError(Exception('Queue cleared'));
      }
    }
    _queue.clear();
    _processing = false;
  }

  /// Get queue statistics
  Map<String, dynamic> getStats() {
    return {'queue_length': _queue.length, 'processing': _processing};
  }
}

class _QueueItem {
  final String key;
  final Future<void> Function() request;
  final int priority;
  final Completer completer;

  _QueueItem({
    required this.key,
    required this.request,
    required this.priority,
    required this.completer,
  });
}

/// Request aggregator for combining multiple data sources
/// Useful for dashboard data that comes from multiple APIs
class RequestAggregator {
  static Future<Map<String, T?>> aggregate<T>({
    required Map<String, Future<T> Function()> requests,
    bool failFast = false,
    Duration? timeout,
  }) async {
    final results = <String, T?>{};

    if (failFast) {
      // Execute all requests in parallel, fail on first error
      final futures = <String, Future<T>>{};
      for (final entry in requests.entries) {
        futures[entry.key] = entry.value();
      }

      final completedFutures = await Future.wait(futures.values, eagerError: true);

      int index = 0;
      for (final key in futures.keys) {
        results[key] = completedFutures[index++];
      }
    } else {
      // Execute all requests in parallel, capture individual errors
      final futures = <String, Future<T>>{};
      for (final entry in requests.entries) {
        futures[entry.key] = entry.value();
      }

      final settledResults = await Future.wait(
        futures.values.map((future) async {
          try {
            return await future;
          } catch (e) {
            if (kDebugMode) print('⚠️ Request failed in aggregate: $e');
            return null;
          }
        }),
        eagerError: false,
      );

      int index = 0;
      for (final key in futures.keys) {
        results[key] = settledResults[index++];
      }
    }

    if (timeout != null) {
      return await Future.any([
        Future.value(results),
        Future.delayed(timeout, () => throw TimeoutException('Aggregate timeout', timeout)),
      ]);
    }

    return results;
  }
}

/// Conditional request executor
/// Executes requests based on conditions (network state, cache state, etc.)
class ConditionalRequests {
  static Future<T?> executeIf<T>({
    required bool condition,
    required Future<T> Function() request,
    T? fallback,
    String? conditionDescription,
  }) async {
    if (!condition) {
      if (kDebugMode && conditionDescription != null) {
        if (kDebugMode) print('⏭️ Skipping request due to condition: $conditionDescription');
      }
      return fallback;
    }

    try {
      return await request();
    } catch (e) {
      if (kDebugMode) print('❌ Conditional request failed: $e');
      return fallback;
    }
  }

  static Future<List<T>> executeWhen<T>({
    required Map<bool, Future<T> Function()> conditionalRequests,
    bool executeAll = false,
  }) async {
    final results = <T>[];

    for (final entry in conditionalRequests.entries) {
      final condition = entry.key;
      final request = entry.value;

      if (condition) {
        try {
          final result = await request();
          results.add(result);

          if (!executeAll) break; // Execute only first matching condition
        } catch (e) {
          if (kDebugMode) print('❌ Conditional request failed: $e');
          if (!executeAll) rethrow;
        }
      }
    }

    return results;
  }
}

class TimeoutException implements Exception {
  final String message;
  final Duration? duration;

  TimeoutException(this.message, this.duration);

  @override
  String toString() =>
      'TimeoutException: $message${duration != null ? ' (${duration!.inMilliseconds}ms)' : ''}';
}
