import 'package:flutter/foundation.dart';
import 'timer_manager.dart';
import 'async_operation_manager.dart';
import 'cache_service.dart';
import 'request_utils.dart';
import 'database_optimization_service.dart';
import 'ui_optimization_service.dart';

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
      'database_stats': DatabaseOptimizationService.instance.getPerformanceStats(),
      'ui_stats': UIOptimizationService.instance.getUIPerformanceStats(),
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
      
      _initialized = false;
      
      if (kDebugMode) print('🎉 All performance services disposed successfully');
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
    print('  🔄 Operations: ${stats['async_stats']['active_operations']} active');
    print('  📡 Requests: ${stats['request_stats']['pending_requests']} pending');
    print('  🗃️ Database: ${stats['database_stats']['total_queries']} total queries');
    print('  🎨 UI: ${stats['ui_stats']['active_components']} active components');
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
    print('  ⏱️ Timers: ${timerStats['active_timers']} active, ${timerStats['net_timers']} net created');
    print('  🔄 Operations: ${asyncStats['active_operations']} active, ${(asyncStats['success_rate'] * 100).toStringAsFixed(1)}% success rate');
    print('  📦 Cache: ${cacheStats['memory_valid']}/${cacheStats['memory_total']} valid entries');
    print('  📡 Requests: ${requestStats['pending_requests']} pending, ${requestStats['batch_groups']} batch groups');
    print('  🗃️ Database: ${databaseStats['total_queries']} queries, ${(databaseStats['cache_hit_rate'] * 100).toStringAsFixed(1)}% cache hit rate');
    print('  🎨 UI: ${uiStats['active_components']} components, ${(uiStats['rebuild_savings_percentage']).toStringAsFixed(1)}% rebuilds saved');
  }
  
  /// Enable periodic performance logging
  /// Logs stats every specified interval
  static void enablePerformanceMonitoring({Duration interval = const Duration(minutes: 10)}) {
    if (!_initialized) {
      if (kDebugMode) print('⚠️ Cannot enable monitoring: services not initialized');
      return;
    }
    
    TimerManager.instance.createPeriodicTimer(
      key: 'performance_monitoring',
      interval: interval,
      callback: (_) => logPerformanceStats(),
    );
    
    if (kDebugMode) {
      print('📈 Performance monitoring enabled (interval: ${interval.inMinutes}m)');
    }
  }
  
  /// Disable periodic performance logging
  static void disablePerformanceMonitoring() {
    TimerManager.instance.cancelTimer('performance_monitoring');
    
    if (kDebugMode) {
      print('📈 Performance monitoring disabled');
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
}