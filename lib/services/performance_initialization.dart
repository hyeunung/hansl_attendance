import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'timer_manager.dart';
import 'async_operation_manager.dart' as async_ops;
import 'cache_service.dart';
import 'request_utils.dart';
import 'database_optimization_service.dart';
import 'ui_optimization_service.dart';
import 'performance_monitoring_service.dart';

/// Performance services initialization
/// Call this once at app startup to initialize all performance optimization services
class PerformanceInitialization {
  
  static bool _initialized = false;
  
  /// Check if performance services are initialized
  static bool get isInitialized => _initialized;

  /// Initialize all performance services
  /// Should be called once during app startup
  static Future<void> initialize() async {
    if (_initialized) {
      // Debug print removed
return;
    }

    try {
      // Debug print removed
// Supabase가 초기화되었는지 확인
      try {
        final _ = Supabase.instance.client;
      } catch (e) {
        // Debug print removed
return; // Supabase가 준비되지 않았으면 초기화 건너뛰기
      }

      // Initialize cache service
      await CacheService.instance.init();
      // Debug print removed
// Start timer maintenance
      TimerManager.instance.startMaintenanceTimer();
      // Debug print removed
// Initialize async operation manager
      // Debug print removed
// Initialize request utils
      // Debug print removed
// Initialize database optimization service
      // Debug print removed
// Initialize UI optimization service
      // Debug print removed
// Initialize comprehensive performance monitoring service
      await PerformanceMonitoringService.instance.startMonitoring();
      // Debug print removed
_initialized = true;

      // Debug code removed
    } catch (e) {
      // Debug code removed
      rethrow;
    }
  }

  /// Get comprehensive performance statistics
  static Map<String, dynamic> getPerformanceStats() {
    if (!_initialized) {
      return {'error': 'Performance services not initialized'};
    }

    // Supabase가 초기화되었는지 확인
    bool supabaseAvailable = false;
    try {
      final _ = Supabase.instance.client;
      supabaseAvailable = true;
    } catch (e) {
      // Supabase not available
    }

    return {
      'initialized': _initialized,
      'timer_stats': TimerManager.instance.getStats().toJson(),
      'async_stats': async_ops.AsyncOperationManager.instance.getStats().toJson(),
      'cache_stats': CacheService.instance.getStats(),
      'request_stats': RequestUtils.instance.getStats(),
      'database_stats': supabaseAvailable 
          ? DatabaseOptimizationService.instance.getPerformanceStats()
          : {'error': 'Supabase not initialized'},
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
      // Debug print removed
// Stop timer maintenance
      TimerManager.instance.stopMaintenanceTimer();
      TimerManager.instance.dispose();
      // Debug print removed
// Dispose async operations
      await async_ops.AsyncOperationManager.instance.dispose();
      // Debug print removed
// Dispose cache service
      CacheService.instance.dispose();
      // Debug print removed
// Clear request utils
      RequestUtils.instance.clear();
      // Debug print removed
// Dispose database optimization service
      DatabaseOptimizationService.instance.dispose();
      // Debug print removed
// Dispose UI optimization service
      UIOptimizationService.instance.dispose();
      // Debug print removed
// Stop performance monitoring service
      PerformanceMonitoringService.instance.stopMonitoring();
      PerformanceMonitoringService.instance.dispose();
      // Debug print removed
      _initialized = false;

      // Debug code removed
    } catch (e) {
      // Debug print removed
      rethrow;
    }
  }

  /// Log initial statistics
  // static void _logInitialStats() {
  //   if (!kDebugMode) return;

  //   // Debug print removed
  // final stats = getPerformanceStats();

  //   // Debug code removed
  //   // Debug code removed
  //   // Debug code removed
  //   // Debug code removed
  //   // Debug code removed
  // }

  /// Log periodic performance statistics
  /// Useful for monitoring performance over time
  static void logPerformanceStats() {
    if (!kDebugMode || !_initialized) return;

    final stats = getPerformanceStats();
    // final timerStats = stats['timer_stats'];
    // final asyncStats = stats['async_stats'];
    // final cacheStats = stats['cache_stats'];
    // final requestStats = stats['request_stats'];
    // final databaseStats = stats['database_stats'];
    // final uiStats = stats['ui_stats'];

    // Debug print removed
// Debug code removed
    // Debug code removed
    // Debug code removed
    // Debug code removed
    // Debug code removed
    // Debug code removed

    // Show comprehensive monitoring status
    final monitoringStats = stats['performance_monitoring'];
    if (monitoringStats != null && monitoringStats['monitoring'] == true) {
      // Debug code removed
      // Debug code removed
    }
  }

  /// Enable comprehensive performance monitoring
  /// Includes both periodic logging and detailed metrics collection
  static void enablePerformanceMonitoring({
    Duration interval = const Duration(minutes: 10),
  }) {
    if (!_initialized) {
      // Debug code removed
      return;
    }

    if (!PerformanceMonitoringService.instance.isMonitoring) {
      PerformanceMonitoringService.instance.startMonitoring();
    }

    // Enable periodic logging
    TimerManager.instance.createPeriodicTimer(
      key: 'performance_monitoring',
      interval: interval,
      callback: (_) => logPerformanceStats(),
    );

    // Debug code removed
  }

  /// Disable comprehensive performance monitoring
  static void disablePerformanceMonitoring() {
    TimerManager.instance.cancelTimer('performance_monitoring');

    // Stop comprehensive monitoring but keep it available
    if (PerformanceMonitoringService.instance.isMonitoring) {
      PerformanceMonitoringService.instance.stopMonitoring();
    }

    // Debug code removed
  }

  /// Force cleanup of all services
  /// Useful for freeing up memory when app goes to background
  static Future<void> performMaintenance() async {
    if (!_initialized) return;

    // Debug print removed
// Get stats before cleanup
    // final statsBefore = getPerformanceStats();

    // Force cleanup
    await CacheService.instance.clearAll();
    await async_ops.AsyncOperationManager.instance.cancelAllOperations();
    RequestUtils.instance.clear();
    DatabaseOptimizationService.instance.clearPerformanceStats();
    UIOptimizationService.instance.cleanup();
    UIOptimizationService.instance.clearStats();

    // Generate performance report before cleanup
    if (PerformanceMonitoringService.instance.isMonitoring) {
      final report = PerformanceMonitoringService.instance
          .generatePerformanceReport();
      if (kDebugMode && report.containsKey('performance_score')) {
        // Debug code removed
      }
    }

    // Get stats after cleanup
    // final statsAfter = getPerformanceStats();

    // Debug code removed
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

    final timerStats = baseStats['timer_stats'] as Map<String, dynamic>?;
    if (timerStats != null) {
      final activeTimers = timerStats['active_timers'] as int? ?? 0;
      if (activeTimers > 15) {
        score -= 20 * (activeTimers - 15) / 15;
        issues.add('High timer count: $activeTimers active');
        recommendations.add('Review and optimize timer usage patterns');
      }
    }

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
