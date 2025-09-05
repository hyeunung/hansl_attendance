import 'package:flutter/foundation.dart';
import 'package:hansl/utils/logger.dart';

/// 간단한 성능 모니터링 서비스
/// Feature Flag 마이그레이션을 위한 성능 추적
class PerformanceMonitor {
  static final Map<String, List<Duration>> _metrics = {};
  static final Map<String, DateTime> _activeTrackers = {};

  /// 화면 로드 시간 추적
  static void trackScreenLoad(String screenName, Duration loadTime) {
    _recordMetric('screen_load_$screenName', loadTime);

    // 느린 화면 로드 경고
    if (loadTime.inMilliseconds > 500) {
      AppLogger.warning('느린 화면 로드 감지', {
        'screen': screenName,
        'duration_ms': loadTime.inMilliseconds,
      });
    }

    // 개발 모드에서는 콘솔에도 출력
    if (kDebugMode) {
      if (kDebugMode) print('📊 Screen Load: $screenName - ${loadTime.inMilliseconds}ms');
    }
  }

  /// 사용자 액션 추적
  static void trackAction(String action, Duration duration) {
    _recordMetric('action_$action', duration);

    // 느린 액션 경고
    if (duration.inMilliseconds > 1000) {
      AppLogger.warning('느린 사용자 액션 감지', {'action': action, 'duration_ms': duration.inMilliseconds});
    }
  }

  /// 메트릭 기록
  static void _recordMetric(String key, Duration duration) {
    _metrics.putIfAbsent(key, () => []).add(duration);

    // 최근 100개만 유지
    if (_metrics[key]!.length > 100) {
      _metrics[key]!.removeAt(0);
    }
  }

  /// 평균 시간 계산
  static Duration? getAverageDuration(String key) {
    final durations = _metrics[key];
    if (durations == null || durations.isEmpty) {
      return null;
    }

    final totalMs = durations.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);

    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  /// 성능 리포트 생성
  static Map<String, dynamic> generateReport() {
    final report = <String, dynamic>{};

    for (final entry in _metrics.entries) {
      final key = entry.key;
      final durations = entry.value;

      if (durations.isEmpty) continue;

      report[key] = {
        'count': durations.length,
        'average_ms': getAverageDuration(key)?.inMilliseconds ?? 0,
        'min_ms': durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b),
        'max_ms': durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b),
      };
    }

    return report;
  }
}
