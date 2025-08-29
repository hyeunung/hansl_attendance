import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'cache_service.dart';
import 'timer_manager.dart';
import 'ui_optimization_service.dart';
import 'async_operation_manager.dart';
import 'database_optimization_service.dart';

/// 종합 성능 모니터링 서비스
/// 실시간으로 앱 성능을 추적하고 분석하여 최적화 기회를 제공
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance =
      PerformanceMonitoringService._internal();
  static PerformanceMonitoringService get instance => _instance;
  PerformanceMonitoringService._internal();

  // 성능 데이터 수집
  final Map<String, PerformanceMetric> _metrics = {};
  final Queue<PerformanceSnapshot> _snapshots = Queue<PerformanceSnapshot>();
  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  // 성능 임계값들
  static const Duration _snapshotInterval = Duration(seconds: 30);
  static const int _maxSnapshots = 100; // 최대 50분간 기록
  static const double _criticalMemoryThreshold = 500.0; // MB
  static const int _criticalFpsThreshold = 50;

  /// 성능 모니터링 시작
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    await _initializeMetrics();

    // 주기적 성능 스냅샷 수집
    _monitoringTimer = Timer.periodic(_snapshotInterval, (_) async {
      await _takePerformanceSnapshot();
    });

    if (kDebugMode) {
      print(
        '🔍 Performance monitoring started - snapshots every ${_snapshotInterval.inSeconds}s',
      );
    }
  }

  /// 성능 모니터링 중지
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    if (kDebugMode) {
      print('🛑 Performance monitoring stopped');
    }
  }

  /// 메트릭 초기화
  Future<void> _initializeMetrics() async {
    _metrics.clear();
    _metrics.addAll({
      'app_start_time': PerformanceMetric(
        'App Start Time',
        'ms',
        MetricType.timing,
      ),
      'memory_usage': PerformanceMetric(
        'Memory Usage',
        'MB',
        MetricType.memory,
      ),
      'cpu_usage': PerformanceMetric('CPU Usage', '%', MetricType.cpu),
      'network_requests': PerformanceMetric(
        'Network Requests',
        'count',
        MetricType.counter,
      ),
      'cache_hit_rate': PerformanceMetric(
        'Cache Hit Rate',
        '%',
        MetricType.percentage,
      ),
      'ui_rebuilds': PerformanceMetric(
        'UI Rebuilds',
        'count/min',
        MetricType.counter,
      ),
      'timer_count': PerformanceMetric(
        'Active Timers',
        'count',
        MetricType.counter,
      ),
      'async_operations': PerformanceMetric(
        'Async Operations',
        'count',
        MetricType.counter,
      ),
      'database_queries': PerformanceMetric(
        'DB Queries',
        'count/min',
        MetricType.counter,
      ),
      'frame_rate': PerformanceMetric(
        'Frame Rate',
        'FPS',
        MetricType.performance,
      ),
    });
  }

  /// 성능 스냅샷 수집
  Future<void> _takePerformanceSnapshot() async {
    try {
      final timestamp = DateTime.now();

      // 각 서비스에서 성능 데이터 수집
      final cacheStats = CacheService.instance.getCacheStats();
      final timerStats = TimerManager.instance.getStats();
      final uiStats = UIOptimizationService.instance.getUIPerformanceStats();
      final asyncStats = AsyncOperationManager.instance.getStats();
      final dbStats = DatabaseOptimizationService.instance
          .getPerformanceStats();

      // 메모리 사용량 (시뮬레이션 - 실제로는 플랫폼별 구현 필요)
      final memoryUsage = await _getMemoryUsage();
      final frameRate = await _getFrameRate();

      final snapshot = PerformanceSnapshot(
        timestamp: timestamp,
        memoryUsage: memoryUsage,
        cacheHitRate: cacheStats.containsKey('hit_rate')
            ? cacheStats['hit_rate']?.toDouble() ?? 0.0
            : 0.0,
        activeTimers: timerStats.activeTimers,
        uiRebuilds: uiStats.containsKey('total_rebuilds')
            ? uiStats['total_rebuilds']?.toInt() ?? 0
            : 0,
        asyncOperations: asyncStats.activeOperations,
        frameRate: frameRate,
        networkRequests: cacheStats.containsKey('total_requests')
            ? cacheStats['total_requests']?.toInt() ?? 0
            : 0,
        databaseQueries: dbStats['recent_queries']?.toInt() ?? 0,
      );

      _addSnapshot(snapshot);
      await _analyzePerformance(snapshot);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Performance snapshot failed: $e');
      }
    }
  }

  /// 스냅샷 추가 및 관리
  void _addSnapshot(PerformanceSnapshot snapshot) {
    _snapshots.add(snapshot);

    // 최대 개수 초과 시 오래된 데이터 제거
    while (_snapshots.length > _maxSnapshots) {
      _snapshots.removeFirst();
    }
  }

  /// 성능 분석 및 경고
  Future<void> _analyzePerformance(PerformanceSnapshot snapshot) async {
    final issues = <String>[];

    // 메모리 사용량 체크
    if (snapshot.memoryUsage > _criticalMemoryThreshold) {
      issues.add(
        '🔴 High memory usage: ${snapshot.memoryUsage.toStringAsFixed(1)}MB',
      );
    }

    // 프레임율 체크
    if (snapshot.frameRate < _criticalFpsThreshold) {
      issues.add(
        '🔴 Low frame rate: ${snapshot.frameRate.toStringAsFixed(1)} FPS',
      );
    }

    // UI 리빌드 과다 체크
    if (_snapshots.length >= 2) {
      final prev = _snapshots.elementAt(_snapshots.length - 2);
      final rebuildDiff = snapshot.uiRebuilds - prev.uiRebuilds;
      final timeDiff = snapshot.timestamp.difference(prev.timestamp).inSeconds;
      final rebuildsPerSecond = rebuildDiff / timeDiff;

      if (rebuildsPerSecond > 10) {
        issues.add(
          '⚠️ High UI rebuild rate: ${rebuildsPerSecond.toStringAsFixed(1)}/sec',
        );
      }
    }

    // 캐시 효율성 체크
    if (snapshot.cacheHitRate < 70.0) {
      issues.add(
        '📊 Low cache hit rate: ${snapshot.cacheHitRate.toStringAsFixed(1)}%',
      );
    }

    // 이슈가 있으면 디버그 출력
    if (issues.isNotEmpty && kDebugMode) {
      print('🚨 Performance Issues Detected:');
      for (final issue in issues) {
        print('  $issue');
      }
    }
  }

  /// 메모리 사용량 측정 (플랫폼별 구현 시뮬레이션)
  Future<double> _getMemoryUsage() async {
    try {
      // 실제 구현에서는 플랫폼별 메모리 API 사용
      // iOS: mach_task_basic_info
      // Android: Debug.getMemoryInfo()

      // 시뮬레이션: 100-400MB 범위의 랜덤 값
      return 150.0 + (DateTime.now().millisecondsSinceEpoch % 250);
    } catch (e) {
      return 0.0;
    }
  }

  /// 프레임율 측정
  Future<double> _getFrameRate() async {
    try {
      // Flutter의 SchedulerBinding을 통한 프레임율 측정 시뮬레이션
      // 실제 구현에서는 WidgetsBinding.instance.addTimingsCallback 사용

      // 시뮬레이션: 55-60 FPS 범위
      return 55.0 + (DateTime.now().millisecondsSinceEpoch % 5);
    } catch (e) {
      return 60.0; // 기본값
    }
  }

  /// 종합 성능 리포트 생성
  Map<String, dynamic> generatePerformanceReport() {
    if (_snapshots.isEmpty) {
      return {'error': 'No performance data available'};
    }

    final latest = _snapshots.last;
    final duration = _snapshots.length > 1
        ? latest.timestamp.difference(_snapshots.first.timestamp)
        : Duration.zero;

    // 평균값 계산
    final avgMemory =
        _snapshots.map((s) => s.memoryUsage).reduce((a, b) => a + b) /
        _snapshots.length;
    final avgFrameRate =
        _snapshots.map((s) => s.frameRate).reduce((a, b) => a + b) /
        _snapshots.length;
    final avgCacheHitRate =
        _snapshots.map((s) => s.cacheHitRate).reduce((a, b) => a + b) /
        _snapshots.length;

    // 트렌드 분석
    final memoryTrend = _calculateTrend(
      _snapshots.map((s) => s.memoryUsage).toList(),
    );
    final frameRateTrend = _calculateTrend(
      _snapshots.map((s) => s.frameRate).toList(),
    );

    return {
      'monitoring_duration_minutes': duration.inMinutes,
      'snapshots_count': _snapshots.length,
      'latest_snapshot': {
        'timestamp': latest.timestamp.toIso8601String(),
        'memory_usage_mb': latest.memoryUsage.toStringAsFixed(1),
        'frame_rate_fps': latest.frameRate.toStringAsFixed(1),
        'cache_hit_rate_percent': latest.cacheHitRate.toStringAsFixed(1),
        'active_timers': latest.activeTimers,
        'ui_rebuilds': latest.uiRebuilds,
        'async_operations': latest.asyncOperations,
      },
      'averages': {
        'memory_usage_mb': avgMemory.toStringAsFixed(1),
        'frame_rate_fps': avgFrameRate.toStringAsFixed(1),
        'cache_hit_rate_percent': avgCacheHitRate.toStringAsFixed(1),
      },
      'trends': {
        'memory_usage': _getTrendDescription(memoryTrend),
        'frame_rate': _getTrendDescription(frameRateTrend),
      },
      'performance_score': _calculatePerformanceScore(
        latest,
        avgMemory,
        avgFrameRate,
        avgCacheHitRate,
      ),
      'recommendations': _generateRecommendations(
        latest,
        avgMemory,
        avgFrameRate,
        avgCacheHitRate,
      ),
    };
  }

  /// 트렌드 계산 (기울기)
  double _calculateTrend(List<double> values) {
    if (values.length < 2) return 0.0;

    // 간단한 선형 트렌드 계산
    final first =
        values.take(values.length ~/ 3).reduce((a, b) => a + b) /
        (values.length ~/ 3);
    final last =
        values.skip(values.length * 2 ~/ 3).reduce((a, b) => a + b) /
        (values.length ~/ 3);

    return (last - first) / first * 100; // 퍼센트 변화
  }

  /// 트렌드 설명
  String _getTrendDescription(double trend) {
    if (trend > 5) return '증가 중 ↗️';
    if (trend < -5) return '감소 중 ↘️';
    return '안정적 ➡️';
  }

  /// 성능 점수 계산 (0-100)
  double _calculatePerformanceScore(
    PerformanceSnapshot latest,
    double avgMemory,
    double avgFrameRate,
    double avgCacheHitRate,
  ) {
    double score = 100.0;

    // 메모리 사용량 (30% 가중치)
    if (avgMemory > 400)
      score -= 30;
    else if (avgMemory > 300)
      score -= 20;
    else if (avgMemory > 200)
      score -= 10;

    // 프레임율 (40% 가중치)
    if (avgFrameRate < 50)
      score -= 40;
    else if (avgFrameRate < 55)
      score -= 25;
    else if (avgFrameRate < 58)
      score -= 10;

    // 캐시 효율성 (20% 가중치)
    if (avgCacheHitRate < 50)
      score -= 20;
    else if (avgCacheHitRate < 70)
      score -= 10;
    else if (avgCacheHitRate < 85)
      score -= 5;

    // 타이머 과다 사용 (10% 가중치)
    if (latest.activeTimers > 20)
      score -= 10;
    else if (latest.activeTimers > 10)
      score -= 5;

    return score.clamp(0.0, 100.0);
  }

  /// 개선 권장사항 생성
  List<String> _generateRecommendations(
    PerformanceSnapshot latest,
    double avgMemory,
    double avgFrameRate,
    double avgCacheHitRate,
  ) {
    final recommendations = <String>[];

    if (avgMemory > 300) {
      recommendations.add('💾 메모리 사용량 최적화 - 불필요한 객체 정리 필요');
    }

    if (avgFrameRate < 55) {
      recommendations.add('🎨 UI 성능 개선 - 위젯 리빌드 최적화 권장');
    }

    if (avgCacheHitRate < 70) {
      recommendations.add('🔄 캐시 정책 개선 - 캐시 TTL 및 전략 재검토');
    }

    if (latest.activeTimers > 15) {
      recommendations.add('⏰ 타이머 관리 최적화 - 불필요한 타이머 정리');
    }

    if (latest.asyncOperations > 10) {
      recommendations.add('🔄 비동기 작업 최적화 - 동시 실행 작업 수 제한');
    }

    if (recommendations.isEmpty) {
      recommendations.add('✅ 성능이 양호합니다 - 현재 최적화 상태 유지');
    }

    return recommendations;
  }

  /// 모니터링 상태 확인
  bool get isMonitoring => _isMonitoring;

  /// 현재 성능 상태 요약
  Map<String, dynamic> getCurrentStatus() {
    if (_snapshots.isEmpty) {
      return {'status': 'No data available'};
    }

    final latest = _snapshots.last;
    return {
      'monitoring': _isMonitoring,
      'last_update': latest.timestamp.toIso8601String(),
      'memory_mb': latest.memoryUsage.toStringAsFixed(1),
      'fps': latest.frameRate.toStringAsFixed(1),
      'cache_hit_rate': '${latest.cacheHitRate.toStringAsFixed(1)}%',
      'active_timers': latest.activeTimers,
      'snapshots_collected': _snapshots.length,
    };
  }

  /// 자원 정리
  void dispose() {
    stopMonitoring();
    _metrics.clear();
    _snapshots.clear();
  }
}

/// 성능 메트릭 클래스
class PerformanceMetric {
  final String name;
  final String unit;
  final MetricType type;
  final List<double> values = [];
  DateTime? lastUpdated;

  PerformanceMetric(this.name, this.unit, this.type);

  void addValue(double value) {
    values.add(value);
    lastUpdated = DateTime.now();

    // 최대 1000개 값만 유지
    if (values.length > 1000) {
      values.removeAt(0);
    }
  }

  double get average =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
  double get latest => values.isEmpty ? 0.0 : values.last;
  double get min =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
  double get max =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
}

/// 메트릭 타입
enum MetricType { timing, memory, cpu, counter, percentage, performance }

/// 성능 스냅샷 클래스
class PerformanceSnapshot {
  final DateTime timestamp;
  final double memoryUsage;
  final double cacheHitRate;
  final int activeTimers;
  final int uiRebuilds;
  final int asyncOperations;
  final double frameRate;
  final int networkRequests;
  final int databaseQueries;

  const PerformanceSnapshot({
    required this.timestamp,
    required this.memoryUsage,
    required this.cacheHitRate,
    required this.activeTimers,
    required this.uiRebuilds,
    required this.asyncOperations,
    required this.frameRate,
    required this.networkRequests,
    required this.databaseQueries,
  });

  @override
  String toString() {
    return 'PerformanceSnapshot{'
        'timestamp: $timestamp, '
        'memory: ${memoryUsage.toStringAsFixed(1)}MB, '
        'fps: ${frameRate.toStringAsFixed(1)}, '
        'cache: ${cacheHitRate.toStringAsFixed(1)}%, '
        'timers: $activeTimers, '
        'rebuilds: $uiRebuilds'
        '}';
  }
}
