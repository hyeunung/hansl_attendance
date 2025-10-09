
/// 간단한 성능 모니터링 서비스
/// Feature Flag 마이그레이션을 위한 성능 추적
class PerformanceMonitor {
  
  // Debug logging function removed
  
  static final Map<String, List<Duration>> _metrics = {};
  static final Map<String, DateTime> _activeTrackers = {};

  /// 시간 추적 시작
  static void startTracking(String key) {
    _activeTrackers[key] = DateTime.now();
  }

  /// 시간 추적 종료 및 기록
  static Duration? stopTracking(String key) {
    final startTime = _activeTrackers.remove(key);
    if (startTime == null) return null;

    final duration = DateTime.now().difference(startTime);
    _recordMetric(key, duration);
    return duration;
  }

  /// 화면 로드 시간 추적
  static void trackScreenLoad(String screenName, Duration loadTime) {
    _recordMetric('screen_load_$screenName', loadTime);

    // 느린 화면 로드 경고
    if (loadTime.inMilliseconds > 500) {
      // Debug code removed
    }

    // 개발 모드에서는 콘솔에도 출력
    // Debug code removed
  }

  /// 사용자 액션 추적
  static void trackAction(String action, Duration duration) {
    _recordMetric('action_$action', duration);

    // 느린 액션 경고
    if (duration.inMilliseconds > 1000) {
      // Debug code removed
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

    final totalMs = durations.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );

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
        'min_ms': durations
            .map((d) => d.inMilliseconds)
            .reduce((a, b) => a < b ? a : b),
        'max_ms': durations
            .map((d) => d.inMilliseconds)
            .reduce((a, b) => a > b ? a : b),
      };
    }

    return report;
  }
}
