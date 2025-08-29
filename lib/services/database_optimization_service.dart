import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_service.dart';
import 'timer_manager.dart';
import 'async_operation_manager.dart';

/// Database query optimization service
/// Provides optimized database access patterns with intelligent caching,
/// query batching, and performance monitoring
class DatabaseOptimizationService
    with TimerManagementMixin, AsyncOperationMixin {
  static final DatabaseOptimizationService _instance =
      DatabaseOptimizationService._internal();
  static DatabaseOptimizationService get instance => _instance;
  DatabaseOptimizationService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final CacheService _cache = CacheService.instance;

  // Query performance tracking
  int _totalQueries = 0;
  int _cacheHits = 0;
  int _batchedQueries = 0;
  final List<QueryPerformance> _performanceLog = [];

  // Query batching

  /// Optimized employee queries with intelligent caching
  Future<Map<String, dynamic>?> getEmployeeByEmail(
    String email, {
    Duration? cacheTtl,
    List<String>? selectFields,
    String? cacheKey,
    CancellationToken? cancellationToken,
  }) async {
    final effectiveCacheKey = cacheKey ?? 'employee_email_$email';
    final effectiveFields = selectFields ?? ['*'];
    final fieldsStr = effectiveFields.join(',');

    return await _cache.getOrFetch<Map<String, dynamic>>(
      key: '${effectiveCacheKey}_$fieldsStr',
      fallback: () => _executeWithTimeout(
        operation: () async {
          _recordQueryStart('getEmployeeByEmail');
          final response = await _client
              .from('employees')
              .select(fieldsStr)
              .eq('email', email)
              .single();
          _recordQueryEnd('getEmployeeByEmail', true);
          return response;
        },
        timeout: const Duration(seconds: 10),
        cancellationToken: cancellationToken,
      ),
      ttl: cacheTtl ?? CacheConfig.employeeDataTtl,
      fromJson: (json) => json,
      toJson: (data) => data,
    );
  }

  /// Optimized employee role lookup with caching
  Future<Map<String, dynamic>?> getEmployeeRole(
    String userId, {
    Duration? cacheTtl,
    CancellationToken? cancellationToken,
  }) async {
    return await _cache.getOrFetch<Map<String, dynamic>>(
      key: 'employee_role_$userId',
      fallback: () => _executeWithTimeout(
        operation: () async {
          _recordQueryStart('getEmployeeRole');
          final response = await _client
              .from('employees')
              .select('role, is_admin, department')
              .eq('id', userId)
              .single();
          _recordQueryEnd('getEmployeeRole', true);
          return response;
        },
        timeout: const Duration(seconds: 8),
        cancellationToken: cancellationToken,
      ),
      ttl: cacheTtl ?? CacheConfig.employeeDataTtl,
      fromJson: (json) => json,
      toJson: (data) => data,
    );
  }

  /// Optimized attendance record queries with date-aware caching
  Future<List<Map<String, dynamic>>> getAttendanceRecords(
    String employeeId, {
    DateTime? date,
    int? limit,
    bool includeHistory = false,
    Duration? cacheTtl,
    CancellationToken? cancellationToken,
  }) async {
    final dateStr =
        date?.toIso8601String().substring(0, 10) ??
        DateTime.now().toIso8601String().substring(0, 10);
    final limitStr = limit != null ? '_limit_$limit' : '';
    final historyStr = includeHistory ? '_with_history' : '';

    final cacheKey = 'attendance_${employeeId}_$dateStr$limitStr$historyStr';

    // Use shorter TTL for today's data, longer for historical data
    final isToday =
        dateStr == DateTime.now().toIso8601String().substring(0, 10);
    final effectiveTtl =
        cacheTtl ??
        (isToday
            ? CacheConfig.attendanceTodayTtl
            : CacheConfig.attendanceHistoryTtl);

    return await _cache.getOrFetch<List<Map<String, dynamic>>>(
          key: cacheKey,
          fallback: () => _executeWithTimeout(
            operation: () async {
              _recordQueryStart('getAttendanceRecords');

              // Build query step by step without reassigning different types
              dynamic query = _client
                  .from('attendance_records')
                  .select()
                  .eq('employee_id', employeeId);

              if (!includeHistory) {
                query = query.eq('date', dateStr);
              }

              if (limit != null) {
                query = query.limit(limit);
              }

              query = query.order('date', ascending: false);

              final response = await query;
              _recordQueryEnd('getAttendanceRecords', true);

              return (response as List).cast<Map<String, dynamic>>();
            },
            timeout: const Duration(seconds: 15),
            cancellationToken: cancellationToken,
          ),
          ttl: effectiveTtl,
          fromJson: (json) =>
              (json['data'] as List?)?.cast<Map<String, dynamic>>() ??
              <Map<String, dynamic>>[],
          toJson: (data) => {'data': data},
        ) ??
        [];
  }

  /// Optimized leave requests with complex filtering and caching
  Future<List<Map<String, dynamic>>> getLeaveRequests({
    String? userEmail,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool includeEmployeeData = true,
    Duration? cacheTtl,
    CancellationToken? cancellationToken,
  }) async {
    // Generate cache key based on parameters
    final keyParts = <String>[
      'leave',
      if (userEmail != null) 'user_$userEmail',
      if (status != null) 'status_$status',
      if (startDate != null)
        'start_${startDate.toIso8601String().substring(0, 10)}',
      if (endDate != null) 'end_${endDate.toIso8601String().substring(0, 10)}',
      if (includeEmployeeData) 'with_employee',
    ];
    final cacheKey = keyParts.join('_');

    return await _cache.getOrFetch<List<Map<String, dynamic>>>(
          key: cacheKey,
          fallback: () => _executeWithTimeout(
            operation: () async {
              _recordQueryStart('getLeaveRequests');

              dynamic query = _client.from('leave').select('*');

              if (userEmail != null) {
                query = query.eq('user_email', userEmail);
              }

              if (status != null) {
                query = query.eq('status', status);
              }

              if (startDate != null) {
                query = query.gte(
                  'start_date',
                  startDate.toIso8601String().substring(0, 10),
                );
              }

              if (endDate != null) {
                query = query.lte(
                  'end_date',
                  endDate.toIso8601String().substring(0, 10),
                );
              }

              query = query.order('created_at', ascending: false);

              final leaveData = await query;
              final leaveList = (leaveData as List)
                  .cast<Map<String, dynamic>>();

              // Add employee data if requested
              if (includeEmployeeData) {
                await _enrichWithEmployeeData(leaveList);
              }

              _recordQueryEnd('getLeaveRequests', true);
              return leaveList;
            },
            timeout: const Duration(seconds: 20),
            cancellationToken: cancellationToken,
          ),
          ttl: cacheTtl ?? CacheConfig.leaveDataTtl,
          fromJson: (json) =>
              (json['data'] as List?)?.cast<Map<String, dynamic>>() ??
              <Map<String, dynamic>>[],
          toJson: (data) => {'data': data},
        ) ??
        [];
  }

  /// Batch employee data enrichment to reduce N+1 queries
  Future<void> _enrichWithEmployeeData(
    List<Map<String, dynamic>> leaveList,
  ) async {
    if (leaveList.isEmpty) return;

    // Extract unique emails
    final emails = leaveList
        .map((leave) => leave['user_email'] as String?)
        .where((email) => email != null)
        .toSet()
        .cast<String>();

    if (emails.isEmpty) return;

    // Single query to get all employee data
    final employeeData = await _client
        .from('employees')
        .select('email, name, role, is_admin, department, attendance_role')
        .inFilter('email', emails.toList());

    // Create lookup map
    final employeeMap = <String, Map<String, dynamic>>{};
    for (final emp in employeeData as List) {
      final empData = emp as Map<String, dynamic>;
      final email = empData['email'] as String?;
      if (email != null) {
        employeeMap[email] = empData;
      }
    }

    // Enrich leave data
    for (final leave in leaveList) {
      final userEmail = leave['user_email'] as String?;
      if (userEmail != null) {
        leave['employees'] =
            employeeMap[userEmail] ??
            {
              'name': leave['name'] ?? '알 수 없음',
              'email': userEmail,
              'role': null,
              'is_admin': false,
              'department': null,
            };
      }
    }
  }

  /// Optimized insert with conflict handling and caching invalidation
  Future<T> optimizedInsert<T>({
    required String table,
    required Map<String, dynamic> data,
    List<String>? invalidateCachePatterns,
    bool upsert = false,
    CancellationToken? cancellationToken,
  }) async {
    return await _executeWithTimeout(
      operation: () async {
        _recordQueryStart('optimizedInsert_$table');

        final response = upsert
            ? await _client.from(table).upsert(data).select()
            : await _client.from(table).insert(data).select();

        // Invalidate related cache patterns
        if (invalidateCachePatterns != null) {
          for (final pattern in invalidateCachePatterns) {
            await _cache.invalidatePattern(pattern);
          }
        }

        _recordQueryEnd('optimizedInsert_$table', true);
        return response as T;
      },
      timeout: const Duration(seconds: 15),
      cancellationToken: cancellationToken,
    );
  }

  /// Optimized update with caching invalidation
  Future<T> optimizedUpdate<T>({
    required String table,
    required Map<String, dynamic> data,
    required Map<String, dynamic> match,
    List<String>? invalidateCachePatterns,
    CancellationToken? cancellationToken,
  }) async {
    return await _executeWithTimeout(
      operation: () async {
        _recordQueryStart('optimizedUpdate_$table');

        dynamic query = _client.from(table).update(data);

        for (final entry in match.entries) {
          query = query.eq(entry.key, entry.value);
        }

        final response = await query.select();

        // Invalidate related cache patterns
        if (invalidateCachePatterns != null) {
          for (final pattern in invalidateCachePatterns) {
            await _cache.invalidatePattern(pattern);
          }
        }

        _recordQueryEnd('optimizedUpdate_$table', true);
        return response as T;
      },
      timeout: const Duration(seconds: 15),
      cancellationToken: cancellationToken,
    );
  }

  /// Batch query execution for multiple related queries
  Future<Map<String, dynamic>> batchQueries({
    required Map<String, Future<dynamic> Function()> queries,
    Duration? timeout,
    CancellationToken? cancellationToken,
  }) async {
    _recordQueryStart('batchQueries');
    _batchedQueries += queries.length;

    final results = <String, dynamic>{};

    try {
      final futures = queries.map((key, queryFn) => MapEntry(key, queryFn()));

      final settledResults = await Future.wait(
        futures.values.map((future) async {
          try {
            return await future;
          } catch (e) {
            if (kDebugMode) print('⚠️ Batch query failed: $e');
            return null;
          }
        }),
        eagerError: false,
      );

      int index = 0;
      for (final key in futures.keys) {
        results[key] = settledResults[index++];
      }

      _recordQueryEnd('batchQueries', true);
      return results;
    } catch (e) {
      _recordQueryEnd('batchQueries', false);
      rethrow;
    }
  }

  /// Query performance monitoring
  void _recordQueryStart(String queryType) {
    _totalQueries++;
    final performance = QueryPerformance(
      queryType: queryType,
      startTime: DateTime.now(),
    );
    _performanceLog.add(performance);

    // Keep only recent entries
    if (_performanceLog.length > 100) {
      _performanceLog.removeRange(0, _performanceLog.length - 100);
    }
  }

  void _recordQueryEnd(String queryType, bool success) {
    final entry = _performanceLog.lastWhere(
      (p) => p.queryType == queryType && p.endTime == null,
      orElse: () =>
          QueryPerformance(queryType: queryType, startTime: DateTime.now()),
    );

    entry.endTime = DateTime.now();
    entry.success = success;
  }

  /// Execute operation with timeout and cancellation support
  Future<T> _executeWithTimeout<T>({
    required Future<T> Function() operation,
    Duration timeout = const Duration(seconds: 30),
    CancellationToken? cancellationToken,
  }) async {
    if (cancellationToken != null && cancellationToken.isCancelled) {
      throw const CancellationException('Operation was cancelled');
    }

    return await operation().timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException('Database operation timed out', timeout);
      },
    );
  }

  /// Get query performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final recentQueries = _performanceLog
        .where(
          (p) =>
              p.endTime != null &&
              p.endTime!.isAfter(
                DateTime.now().subtract(const Duration(minutes: 10)),
              ),
        )
        .toList();

    final totalExecutionTime = recentQueries.fold<int>(
      0,
      (sum, p) => sum + (p.endTime!.difference(p.startTime).inMilliseconds),
    );

    final avgExecutionTime = recentQueries.isNotEmpty
        ? totalExecutionTime / recentQueries.length
        : 0.0;

    final successfulQueries = recentQueries.where((p) => p.success).length;
    final successRate = recentQueries.isNotEmpty
        ? successfulQueries / recentQueries.length
        : 1.0;

    return {
      'total_queries': _totalQueries,
      'cache_hits': _cacheHits,
      'batched_queries': _batchedQueries,
      'recent_queries': recentQueries.length,
      'avg_execution_time_ms': avgExecutionTime,
      'success_rate': successRate,
      'cache_hit_rate': _totalQueries > 0 ? _cacheHits / _totalQueries : 0.0,
      'performance_log': _performanceLog
          .where((p) => p.endTime != null)
          .map(
            (p) => {
              'query_type': p.queryType,
              'execution_time_ms': p.endTime!
                  .difference(p.startTime)
                  .inMilliseconds,
              'success': p.success,
              'timestamp': p.startTime.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  /// Clear performance statistics
  void clearPerformanceStats() {
    _totalQueries = 0;
    _cacheHits = 0;
    _batchedQueries = 0;
    _performanceLog.clear();
  }

  /// Invalidate cache patterns manually
  Future<void> invalidateCache({List<String>? patterns}) async {
    if (patterns != null && patterns.isNotEmpty) {
      for (final pattern in patterns) {
        await _cache.invalidatePattern(pattern);
        if (kDebugMode) print('🗑️ Cache invalidated: $pattern');
      }
    } else {
      await _cache.clearAll();
      if (kDebugMode) print('🗑️ All cache cleared');
    }
  }

  /// Dispose resources
  void dispose() {
    clearPerformanceStats();
  }
}

/// Query performance tracking
class QueryPerformance {
  final String queryType;
  final DateTime startTime;
  DateTime? endTime;
  bool success = false;

  QueryPerformance({
    required this.queryType,
    required this.startTime,
    this.endTime,
    this.success = false,
  });
}

/// Database query builder helper
class QueryBuilder {
  final SupabaseClient _client;
  final String _table;
  final List<String> _select = ['*'];
  final List<String> _filters = [];
  final List<String> _orders = [];
  int? _limit;

  QueryBuilder(this._client, this._table);

  QueryBuilder select(List<String> fields) {
    _select.clear();
    _select.addAll(fields);
    return this;
  }

  QueryBuilder eq(String column, dynamic value) {
    _filters.add('$column.eq.$value');
    return this;
  }

  QueryBuilder neq(String column, dynamic value) {
    _filters.add('$column.neq.$value');
    return this;
  }

  QueryBuilder gte(String column, dynamic value) {
    _filters.add('$column.gte.$value');
    return this;
  }

  QueryBuilder lte(String column, dynamic value) {
    _filters.add('$column.lte.$value');
    return this;
  }

  QueryBuilder order(String column, {bool ascending = true}) {
    _orders.add('$column${ascending ? '.asc' : '.desc'}');
    return this;
  }

  QueryBuilder limit(int count) {
    _limit = count;
    return this;
  }

  Future<List<Map<String, dynamic>>> execute() async {
    dynamic query = _client.from(_table).select(_select.join(','));

    for (final filter in _filters) {
      final parts = filter.split('.');
      if (parts.length >= 3) {
        final column = parts[0];
        final op = parts[1];
        final value = parts.sublist(2).join('.');

        switch (op) {
          case 'eq':
            query = query.eq(column, value);
            break;
          case 'neq':
            query = query.neq(column, value);
            break;
          case 'gte':
            query = query.gte(column, value);
            break;
          case 'lte':
            query = query.lte(column, value);
            break;
        }
      }
    }

    for (final order in _orders) {
      final parts = order.split('.');
      if (parts.length >= 2) {
        final column = parts[0];
        final direction = parts[1];
        query = query.order(column, ascending: direction == 'asc');
      }
    }

    if (_limit != null) {
      query = query.limit(_limit!);
    }

    final response = await query;
    return (response as List).cast<Map<String, dynamic>>();
  }
}

/// Timeout exception for database operations
class TimeoutException implements Exception {
  final String message;
  final Duration? duration;

  TimeoutException(this.message, this.duration);

  @override
  String toString() =>
      'TimeoutException: $message${duration != null ? ' (${duration!.inSeconds}s)' : ''}';
}

/// Cancellation exception for database operations
class CancellationException implements Exception {
  final String message;

  const CancellationException(this.message);

  @override
  String toString() => 'CancellationException: $message';
}
