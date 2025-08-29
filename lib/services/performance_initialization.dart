import 'package:flutter/foundation.dart';
import 'timer_manager.dart';
import 'async_operation_manager.dart';
import 'cache_service.dart';
import 'request_utils.dart';
import 'database_optimization_service.dart';
import 'ui_optimization_service.dart';
import 'performance_monitoring_service.dart';

/// Performance services initialization
/// Call this once at app startup to initialize all performance optimization services
class PerformanceInitialization {
  static bool _initialized = false;

  /// Initialize all performance services
  /// Should be called once during app startup
  static Future<void> initialize() async {
    if (_initialized) {
      if (kDebugMode) print('⚠️ Performance services already initialized');
      return;
    }

    try {
      if (kDebugMode) print('🚀 Initializing performance services...');

      // Initialize cache service
      await CacheService.instance.init();
      if (kDebugMode) print('✅ CacheService initialized');

      // Start timer maintenance
      TimerManager.instance.startMaintenanceTimer();
      if (kDebugMode) print('✅ TimerManager maintenance started');

      // Initialize async operation manager
      // (No explicit initialization needed, but log for visibility)
      if (kDebugMode) print('✅ AsyncOperationManager ready');

      // Initialize request utils
      // (No explicit initialization needed, but log for visibility)
      if (kDebugMode) print('✅ RequestUtils ready');

      // Initialize database optimization service
      // (No explicit initialization needed, but log for visibility)
      if (kDebugMode) print('✅ DatabaseOptimizationService ready');

      // Initialize UI optimization service
      // (No explicit initialization needed, but log for visibility)
      if (kDebugMode) print('✅ UIOptimizationService ready');

      // Initialize comprehensive performance monitoring service
      await PerformanceMonitoringService.instance.startMonitoring();
      if (kDebugMode) print('✅ PerformanceMonitoringService started');

      _initialized = true;

      if (kDebugMode) {
        print('🎉 All performance services initialized successfully');
        _logInitialStats();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize performance services: $e');
      rethrow;
    }
  }

  /// Get comprehensive performance statistics
  static Map<String, dynamic> getPerformanceStats() {
    if (!_initialized) {
      return {'error': 'Performance services not initialized'};
    }

    return {
      'initialized': _initialized,
      'timer_stats': TimerManager.instance.getStats().toJson(),
      'async_stats': AsyncOperationManager.instance.getStats().toJson(),
      'cache_stats': CacheService.instance.getStats(),
      'request_stats': RequestUtils.instance.getStats(),
      'database_stats': DatabaseOptimizationService.instance
          .getPerformanceStats(),
      'ui_stats': UIOptimizationService.instance.getUIPerformanceStats(),
      'performance_monitoring': PerformanceMonitoringService.instance
          .getCurrentStatus(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose all performance services
  /// Call this when app is shutting down
  static Future<void> dispose() async {
    if (!_initialized) return;

    try {
      if (kDebugMode) print('🛑 Disposing performance services...');

      // Stop timer maintenance
      TimerManager.instance.stopMaintenanceTimer();
      TimerManager.instance.dispose();
      if (kDebugMode) print('✅ TimerManager disposed');

      // Dispose async operations
      await AsyncOperationManager.instance.dispose();
      if (kDebugMode) print('✅ AsyncOperationManager disposed');

      // Dispose cache service
      CacheService.instance.dispose();
      if (kDebugMode) print('✅ CacheService disposed');

      // Clear request utils
      RequestUtils.instance.clear();
      if (kDebugMode) print('✅ RequestUtils cleared');

      // Dispose database optimization service
      DatabaseOptimizationService.instance.dispose();
      if (kDebugMode) print('✅ DatabaseOptimizationService disposed');

      // Dispose UI optimization service
      UIOptimizationService.instance.dispose();
      if (kDebugMode) print('✅ UIOptimizationService disposed');

      // Stop performance monitoring service
      PerformanceMonitoringService.instance.stopMonitoring();
      PerformanceMonitoringService.instance.dispose();
      if (kDebugMode) print('✅ PerformanceMonitoringService stopped');

      _initialized = false;

      if (kDebugMode)
        print('🎉 All performance services disposed successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to dispose performance services: $e');
    }
  }

  /// Check if services are initialized
  static bool get isInitialized => _initialized;

  /// Log initial statistics
  static void _logInitialStats() {
    if (!kDebugMode) return;

    print('📊 Initial Performance Stats:');
    final stats = getPerformanceStats();

    print('  📦 Cache: ${stats['cache_stats']['memory_total']} memory entries');
    print('  ⏱️ Timers: ${stats['timer_stats']['active_timers']} active');
    print(
      '  🔄 Operations: ${stats['async_stats']['active_operations']} active',
    );
    print(
      '  📡 Requests: ${stats['request_stats']['pending_requests']} pending',
    );
    print(
      '  🗃️ Database: ${stats['database_stats']['total_queries']} total queries',
    );
    print(
      '  🎨 UI: ${stats['ui_stats']['active_components']} active components',
    );
  }

  /// Log periodic performance statistics
  /// Useful for monitoring performance over time
  static void logPerformanceStats() {
    if (!kDebugMode || !_initialized) return;

    final stats = getPerformanceStats();
    final timerStats = stats['timer_stats'];
    final asyncStats = stats['async_stats'];
    final cacheStats = stats['cache_stats'];
    final requestStats = stats['request_stats'];
    final databaseStats = stats['database_stats'];
    final uiStats = stats['ui_stats'];

    print('📊 Performance Stats:');
    print(
      '  ⏱️ Timers: ${timerStats['active_timers']} active, ${timerStats['net_timers']} net created',
    );
    print(
      '  🔄 Operations: ${asyncStats['active_operations']} active, ${(asyncStats['success_rate'] * 100).toStringAsFixed(1)}% success rate',
    );
    print(
      '  📦 Cache: ${cacheStats['memory_valid']}/${cacheStats['memory_total']} valid entries',
    );
    print(
      '  📡 Requests: ${requestStats['pending_requests']} pending, ${requestStats['batch_groups']} batch groups',
    );
    print(
      '  🗃️ Database: ${databaseStats['total_queries']} queries, ${(databaseStats['cache_hit_rate'] * 100).toStringAsFixed(1)}% cache hit rate',
    );
    print(
      '  🎨 UI: ${uiStats['active_components']} components, ${(uiStats['rebuild_savings_percentage']).toStringAsFixed(1)}% rebuilds saved',
    );

    // Show comprehensive monitoring status
    final monitoringStats = stats['performance_monitoring'];
    if (monitoringStats != null && monitoringStats['monitoring'] == true) {
      print(
        '  📊 Monitoring: ${monitoringStats['snapshots_collected']} snapshots collected',
      );
      print(
        '  📈 Current: ${monitoringStats['memory_mb']}MB RAM, ${monitoringStats['fps']} FPS, ${monitoringStats['cache_hit_rate']} cache',
      );
    }
  }

  /// Enable comprehensive performance monitoring
  /// Includes both periodic logging and detailed metrics collection
  static void enablePerformanceMonitoring({
    Duration interval = const Duration(minutes: 10),
  }) {
    if (!_initialized) {
      if (kDebugMode)
        print('⚠️ Cannot enable monitoring: services not initialized');
      return;
    }

    // Enable comprehensive monitoring (already started in initialize())
    if (!PerformanceMonitoringService.instance.isMonitoring) {
      PerformanceMonitoringService.instance.startMonitoring();
    }

    // Enable periodic logging
    TimerManager.instance.createPeriodicTimer(
      key: 'performance_monitoring',
      interval: interval,
      callback: (_) => logPerformanceStats(),
    );

    if (kDebugMode) {
      print(
        '📈 Comprehensive performance monitoring enabled (interval: ${interval.inMinutes}m)',
      );
      print('📊 Real-time monitoring: snapshots every 30s');
    }
  }

  /// Disable comprehensive performance monitoring
  static void disablePerformanceMonitoring() {
    TimerManager.instance.cancelTimer('performance_monitoring');

    // Stop comprehensive monitoring but keep it available
    if (PerformanceMonitoringService.instance.isMonitoring) {
      PerformanceMonitoringService.instance.stopMonitoring();
    }

    if (kDebugMode) {
      print('📈 Comprehensive performance monitoring disabled');
    }
  }

  /// Force cleanup of all services
  /// Useful for freeing up memory when app goes to background
  static Future<void> performMaintenance() async {
    if (!_initialized) return;

    if (kDebugMode) print('🧹 Performing maintenance...');

    // Get stats before cleanup
    final statsBefore = getPerformanceStats();

    // Force cleanup
    await CacheService.instance.clearAll();
    await AsyncOperationManager.instance.cancelAllOperations();
    RequestUtils.instance.clear();
    DatabaseOptimizationService.instance.clearPerformanceStats();
    UIOptimizationService.instance.cleanup();
    UIOptimizationService.instance.clearStats();

    // Generate performance report before cleanup
    if (PerformanceMonitoringService.instance.isMonitoring) {
      final report = PerformanceMonitoringService.instance
          .generatePerformanceReport();
      if (kDebugMode && report.containsKey('performance_score')) {
        print('📊 Performance Score: ${report['performance_score']}/100');
      }
    }

    // Get stats after cleanup
    final statsAfter = getPerformanceStats();

    if (kDebugMode) {
      final timersBefore = statsBefore['timer_stats']['active_timers'];
      final timersAfter = statsAfter['timer_stats']['active_timers'];
      final operationsBefore = statsBefore['async_stats']['active_operations'];
      final operationsAfter = statsAfter['async_stats']['active_operations'];

      print('🧹 Maintenance completed:');
      print('  ⏱️ Timers: $timersBefore → $timersAfter');
      print('  🔄 Operations: $operationsBefore → $operationsAfter');
      print('  📦 Cache: cleared all entries');
    }
  }

  /// Get comprehensive performance report
  /// Includes detailed analysis and recommendations
  static Map<String, dynamic> getComprehensiveReport() {
    if (!_initialized) {
      return {'error': 'Performance services not initialized'};
    }

    final baseStats = getPerformanceStats();
    final monitoringReport = PerformanceMonitoringService.instance
        .generatePerformanceReport();

    return {
      'base_stats': baseStats,
      'monitoring_report': monitoringReport,
      'system_health': _calculateSystemHealth(baseStats, monitoringReport),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Calculate overall system health score (0-100)
  static Map<String, dynamic> _calculateSystemHealth(
    Map<String, dynamic> baseStats,
    Map<String, dynamic> monitoringReport,
  ) {
    double score = 100.0;
    final issues = <String>[];
    final recommendations = <String>[];

    // Cache health (25% weight)
    final cacheStats = baseStats['cache_stats'] as Map<String, dynamic>?;
    if (cacheStats != null) {
      final hitRate = (cacheStats['hit_rate'] as double?) ?? 0.0;
      if (hitRate < 0.7) {
        score -= 25 * (0.7 - hitRate) / 0.7;
        issues.add(
          'Low cache hit rate: ${(hitRate * 100).toStringAsFixed(1)}%',
        );
        recommendations.add(
          'Consider optimizing cache strategy and TTL values',
        );
      }
    }

    // Timer health (20% weight)
    final timerStats = baseStats['timer_stats'] as Map<String, dynamic>?;
    if (timerStats != null) {
      final activeTimers = timerStats['active_timers'] as int? ?? 0;
      if (activeTimers > 15) {
        score -= 20 * (activeTimers - 15) / 15;
        issues.add('High timer count: $activeTimers active');
        recommendations.add('Review and optimize timer usage patterns');
      }
    }

    // Async operations health (20% weight)
    final asyncStats = baseStats['async_stats'] as Map<String, dynamic>?;
    if (asyncStats != null) {
      final successRate = (asyncStats['success_rate'] as double?) ?? 1.0;
      final activeOps = asyncStats['active_operations'] as int? ?? 0;

      if (successRate < 0.95) {
        score -= 10 * (0.95 - successRate) / 0.05;
        issues.add(
          'Low async success rate: ${(successRate * 100).toStringAsFixed(1)}%',
        );
        recommendations.add('Investigate and handle async operation failures');
      }

      if (activeOps > 10) {
        score -= 10 * (activeOps - 10) / 10;
        issues.add('High concurrent operations: $activeOps active');
        recommendations.add('Consider implementing operation queueing');
      }
    }

    // Database health (20% weight)
    final dbStats = baseStats['database_stats'] as Map<String, dynamic>?;
    if (dbStats != null) {
      final dbHitRate = (dbStats['cache_hit_rate'] as double?) ?? 0.0;
      final avgExecTime = (dbStats['avg_execution_time_ms'] as double?) ?? 0.0;

      if (dbHitRate < 0.8) {
        score -= 10 * (0.8 - dbHitRate) / 0.8;
        issues.add(
          'Low DB cache hit rate: ${(dbHitRate * 100).toStringAsFixed(1)}%',
        );
        recommendations.add('Optimize database query caching strategy');
      }

      if (avgExecTime > 500) {
        score -= 10 * (avgExecTime - 500) / 500;
        issues.add('Slow DB queries: ${avgExecTime.toStringAsFixed(0)}ms avg');
        recommendations.add('Optimize slow database queries and add indexes');
      }
    }

    // Performance monitoring health (15% weight)
    if (monitoringReport.containsKey('performance_score')) {
      final perfScore =
          monitoringReport['performance_score'] as double? ?? 100.0;
      score = score * 0.85 + perfScore * 0.15;
    }

    return {
      'score': score.clamp(0.0, 100.0),
      'grade': _getHealthGrade(score),
      'issues': issues,
      'recommendations': recommendations,
      'summary': _getHealthSummary(score, issues.length),
    };
  }

  /// Get health grade based on score
  static String _getHealthGrade(double score) {
    if (score >= 90) return 'A+ (Excellent)';
    if (score >= 80) return 'A (Very Good)';
    if (score >= 70) return 'B (Good)';
    if (score >= 60) return 'C (Fair)';
    if (score >= 50) return 'D (Poor)';
    return 'F (Critical)';
  }

  /// Get health summary
  static String _getHealthSummary(double score, int issueCount) {
    if (score >= 90 && issueCount == 0) {
      return 'System performance is excellent with no issues detected.';
    } else if (score >= 80) {
      return 'System performance is good with ${issueCount == 0 ? 'no' : issueCount} minor issues.';
    } else if (score >= 60) {
      return 'System performance is acceptable but has $issueCount areas for improvement.';
    } else {
      return 'System performance needs attention with $issueCount critical issues.';
    }
  }
}
