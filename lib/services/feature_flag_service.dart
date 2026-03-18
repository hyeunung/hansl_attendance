import 'package:shared_preferences/shared_preferences.dart';

/// Feature Flag 관리 서비스
/// 점진적 롤아웃과 A/B 테스팅을 위한 기능 플래그 시스템
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  SharedPreferences? _prefs;
  final Map<String, bool> _overrides = {};

  /// 기본 플래그 설정
  static const Map<String, bool> _defaultFlags = {
    'refactored_leave_screen': true, // 리팩토링된 화면 활성화
    // refactored_business_trip_screen 제거됨 - 출장 신청은 웹에서만
    'refactored_attendance_screen': true, // 출석 화면 리팩토링 활성화
    'use_edge_functions': true, // Edge Functions 사용
    'new_validators': true,
    'enhanced_logging': false, // 로깅 비활성화
    'performance_monitoring': false, // 성능 모니터링 비활성화
    'show_debug_info': false, // 디버그 정보 표시 비활성화
  };

  /// 서비스 초기화
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      // Debug code removed
      _logCurrentFlags();
    } catch (e) {
      // Debug code removed
    }
  }

  /// 플래그 활성화 여부 확인
  bool isEnabled(String flag) {
    // 1. 오버라이드 확인
    if (_overrides.containsKey(flag)) {
      return _overrides[flag]!;
    }

    // 2. SharedPreferences 확인
    if (_prefs != null) {
      final value = _prefs!.getBool(flag);
      if (value != null) {
        return value;
      }
    }

    // 3. 기본값 반환
    return _defaultFlags[flag] ?? false;
  }

  /// 플래그 설정
  Future<void> setFlag(String flag, bool value) async {
    try {
      await _prefs?.setBool(flag, value);
      // Debug code removed
    } catch (e) {
      // Debug code removed
    }
  }

  /// 플래그 오버라이드 (테스트용)
  void override(String flag, bool value) {
    _overrides[flag] = value;
    // Debug code removed
  }

  /// 오버라이드 초기화
  void clearOverrides() {
    _overrides.clear();
    // Debug code removed
  }

  /// A/B 테스트 그룹 결정
  bool shouldUseNewFeature(
    String userId,
    String featureFlag, {
    int percentage = 10,
  }) {
    // 플래그가 완전히 비활성화된 경우
    if (!isEnabled(featureFlag)) {
      return false;
    }

    // 사용자 ID 기반 그룹 분할
    final hash = userId.hashCode;
    final userPercentage = hash.abs() % 100;

    final result = userPercentage < percentage;
    // Debug code removed

    return result;
  }

  /// 점진적 롤아웃 단계
  int getRolloutPercentage(String flag) {
    final key = '${flag}_rollout_percentage';
    return _prefs?.getInt(key) ?? 0;
  }

  /// 점진적 롤아웃 단계 설정
  Future<void> setRolloutPercentage(String flag, int percentage) async {
    final key = '${flag}_rollout_percentage';
    await _prefs?.setInt(key, percentage.clamp(0, 100));
    // Debug code removed
  }

  /// 현재 활성화된 플래그 목록
  Map<String, bool> getAllFlags() {
    final Map<String, bool> currentFlags = {};

    // 기본값 추가
    currentFlags.addAll(_defaultFlags);

    // SharedPreferences 값으로 덮어쓰기
    if (_prefs != null) {
      for (final key in _defaultFlags.keys) {
        final value = _prefs!.getBool(key);
        if (value != null) {
          currentFlags[key] = value;
        }
      }
    }

    // 오버라이드로 최종 덮어쓰기
    currentFlags.addAll(_overrides);

    return currentFlags;
  }

  /// 현재 플래그 상태 로깅
  void _logCurrentFlags() {
    // final flags = getAllFlags();
    // Debug code removed
  }

  /// 플래그 상태 초기화 (개발/테스트용)
  Future<void> resetToDefaults() async {
    if (_prefs != null) {
      for (final key in _defaultFlags.keys) {
        await _prefs!.remove(key);
      }
    }
    _overrides.clear();
    // Debug code removed
  }
}

/// 간편 접근을 위한 정적 메서드
class FeatureFlags {
  static final _service = FeatureFlagService();

  /// 리팩토링된 연차 신청 화면 사용 여부
  static bool get useRefactoredLeaveScreen =>
      _service.isEnabled('refactored_leave_screen');

  /// 새로운 검증 로직 사용 여부
  static bool get useNewValidators => _service.isEnabled('new_validators');

  /// 향상된 로깅 사용 여부
  static bool get useEnhancedLogging => _service.isEnabled('enhanced_logging');

  /// 성능 모니터링 활성화 여부
  static bool get performanceMonitoring =>
      _service.isEnabled('performance_monitoring');

  /// 디버그 정보 표시 여부
  static bool get showDebugInfo => _service.isEnabled('show_debug_info');

  /// 리팩토링된 출석 화면 사용 여부
  static bool get useRefactoredAttendanceScreen =>
      _service.isEnabled('refactored_attendance_screen');

  /// Edge Functions 사용 여부
  static bool get useEdgeFunctions => _service.isEnabled('use_edge_functions');
}
