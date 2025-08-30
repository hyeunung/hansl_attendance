# 📋 HANSL 리팩토링 마이그레이션 계획

## 🎯 목표
기존 연차/출장 신청 화면을 리팩토링된 버전으로 안전하게 교체

## 📅 마이그레이션 일정

### Phase 1: 준비 단계 (1주차)
- [x] 리팩토링된 코드 작성 완료
- [x] 단위 테스트 작성
- [x] 위젯 테스트 작성
- [x] 통합 테스트 작성
- [ ] 테스트 실행 및 검증
- [ ] 코드 리뷰

### Phase 2: 단계적 적용 (2주차)
- [x] Feature Flag 구현 (`lib/services/feature_flag_service.dart`)
- [x] A/B 테스트 설정 (FeatureFlagService.shouldUseNewFeature)
- [x] 화면 라우터 구현 (`lib/screens/leave/leave_screen_router.dart`)
- [x] 성능 모니터링 서비스 (`lib/services/performance_monitor.dart`)
- [ ] 내부 테스트 그룹 선정

### Phase 3: 배포 (3주차)
- [ ] 점진적 롤아웃 (10% → 50% → 100%)
- [ ] 모니터링 및 피드백 수집
- [ ] 이슈 대응

### Phase 4: 마무리 (4주차)
- [ ] 기존 코드 제거
- [ ] 문서 업데이트
- [ ] 회고 및 개선사항 정리

## 🔄 교체 전략

### 1. Feature Flag 구현

```dart
// lib/config/feature_flags.dart
class FeatureFlags {
  static bool get useRefactoredLeaveScreen {
    // SharedPreferences 또는 원격 설정에서 값 가져오기
    return _getFlag('use_refactored_leave_screen') ?? false;
  }
  
  static bool get useRefactoredBusinessTripScreen {
    return _getFlag('use_refactored_business_trip_screen') ?? false;
  }
}
```

### 2. 라우팅 수정

```dart
// lib/screens/main_tab.dart 또는 라우팅 파일
Widget _getLeaveRequestScreen() {
  if (FeatureFlags.useRefactoredLeaveScreen) {
    return const AnnualLeaveRequestScreenOptimized();
  } else {
    return const AnnualLeaveRequestScreen();
  }
}

Widget _getBusinessTripScreen() {
  if (FeatureFlags.useRefactoredBusinessTripScreen) {
    return const BusinessTripRequestScreenRefactored();
  } else {
    return const BusinessTripRequestScreen();
  }
}
```

### 3. A/B 테스트 설정

```dart
// lib/services/ab_test_service.dart
class ABTestService {
  static bool shouldUseNewScreen(String userId) {
    // 사용자 ID 기반 그룹 분할
    final hash = userId.hashCode;
    final percentage = hash % 100;
    
    // 처음 10% 사용자에게만 새 화면 표시
    return percentage < 10;
  }
}
```

## 📊 모니터링 지표

### 성능 지표
- **화면 로드 시간**: 목표 < 500ms
- **메모리 사용량**: 기존 대비 30% 감소
- **프레임 드롭**: 60fps 유지

### 사용성 지표
- **신청 완료율**: 기존 대비 동일 이상
- **에러 발생률**: 기존 대비 50% 감소
- **사용자 이탈률**: 기존 대비 20% 감소

### 코드 품질 지표
- **테스트 커버리지**: > 80%
- **크래시 프리 세션**: > 99.5%
- **코드 복잡도**: 기존 대비 60% 감소

## 🚨 롤백 계획

### 롤백 트리거
- 크래시 율 > 1%
- 신청 완료율 < 기존 대비 90%
- 중대한 보안 이슈 발견

### 롤백 절차
1. Feature Flag 즉시 비활성화
2. 앱 강제 업데이트 푸시 (필요시)
3. 사용자 공지
4. 원인 분석 및 수정

## 📝 체크리스트

### 배포 전 체크리스트
- [ ] 모든 테스트 통과
- [ ] 코드 리뷰 완료
- [ ] 성능 테스트 완료
- [ ] 보안 검토 완료
- [ ] 접근성 테스트 완료
- [ ] 다국어 지원 확인

### 배포 후 체크리스트
- [ ] 크래시 리포트 모니터링
- [ ] 성능 지표 확인
- [ ] 사용자 피드백 수집
- [ ] 에러 로그 분석
- [ ] A/B 테스트 결과 분석

## ✅ 구현 완료 항목

### 완료된 서비스 및 컴포넌트
1. **Feature Flag 서비스** (`lib/services/feature_flag_service.dart`)
   - 플래그 관리 및 A/B 테스트 지원
   - 점진적 롤아웃 기능
   - SharedPreferences 기반 영속성

2. **화면 라우터** 
   - `lib/screens/leave/leave_screen_router.dart` - 연차 신청 화면 라우팅
   - `lib/screens/leave/leave_screen_router.dart` - 출장 신청 화면 라우팅
   - 성능 측정 통합

3. **성능 모니터링** (`lib/services/performance_monitor.dart`)
   - 화면 로드 시간 추적
   - 사용자 액션 측정
   - 성능 리포트 생성

4. **Feature Flag 설정 화면** (`lib/screens/settings/feature_flag_settings_screen.dart`)
   - 개발/테스트용 플래그 관리 UI
   - 런타임 플래그 변경 지원

5. **리팩토링된 화면**
   - `annual_leave_request_screen_optimized.dart` - 연차 신청 화면 (655줄 → 475줄)
   - `business_trip_request_screen_optimized.dart` - 출장 신청 화면 (923줄 → 550줄)

6. **분리된 위젯 컴포넌트**
   - 연차 관련: `leave_calendar_widget.dart`, `leave_info_card_widget.dart`, `leave_date_chips_widget.dart`
   - 출장 관련: `trip_calendar_widget.dart`, `trip_date_chips_widget.dart`, `transport_selector_widget.dart`
   - 공통: `notification_banner_widget.dart`, `employee_selector_widget.dart`

7. **테스트 스위트**
   - 단위 테스트 (validators, utils)
   - 위젯 테스트 (components)
   - 통합 테스트 (end-to-end flows)
   - 테스트 실행 스크립트 (`run_tests.sh`)

## 🔧 구현 상세

### Step 1: Feature Flag 서비스 구현 ✅

```dart
// lib/services/feature_flag_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();
  
  SharedPreferences? _prefs;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  bool isEnabled(String flag) {
    return _prefs?.getBool(flag) ?? _defaultFlags[flag] ?? false;
  }
  
  Future<void> setFlag(String flag, bool value) async {
    await _prefs?.setBool(flag, value);
  }
  
  static const Map<String, bool> _defaultFlags = {
    'refactored_leave_screen': false,
    'refactored_business_trip_screen': false,
    'new_validators': true,
    'enhanced_logging': true,
  };
}
```

### Step 2: 점진적 마이그레이션

```dart
// lib/screens/leave/leave_screen_router.dart
import 'package:flutter/material.dart';
import 'package:hansl/services/feature_flag_service.dart';
import 'annual_leave_request_screen.dart';
import 'annual_leave_request_screen_optimized.dart';

class LeaveScreenRouter extends StatelessWidget {
  const LeaveScreenRouter({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final featureFlags = FeatureFlagService();
    
    if (featureFlags.isEnabled('refactored_leave_screen')) {
      // 새 화면 사용
      return const AnnualLeaveRequestScreenOptimized();
    } else {
      // 기존 화면 사용
      return const AnnualLeaveRequestScreen();
    }
  }
}
```

### Step 3: 성능 모니터링

```dart
// lib/services/performance_monitor.dart
class PerformanceMonitor {
  static void trackScreenLoad(String screenName, Duration loadTime) {
    AppLogger.performance('Screen Load: $screenName', loadTime);
    
    // Firebase Performance 또는 다른 모니터링 서비스에 전송
    if (loadTime.inMilliseconds > 500) {
      AppLogger.warning('Slow screen load detected', {
        'screen': screenName,
        'duration': loadTime.inMilliseconds,
      });
    }
  }
  
  static void trackAction(String action, Duration duration) {
    AppLogger.performance('Action: $action', duration);
  }
}
```

## 📈 예상 개선 효과

### 정량적 개선
- **코드 라인 수**: 50% 감소
- **빌드 시간**: 20% 단축
- **메모리 사용량**: 30% 감소
- **CPU 사용량**: 25% 감소

### 정성적 개선
- **코드 가독성**: 크게 향상
- **유지보수성**: 모듈화로 인한 개선
- **테스트 용이성**: 단위 테스트 가능
- **재사용성**: 컴포넌트 재사용 가능

## 🎯 성공 기준

### 기술적 성공 기준
- ✅ 모든 테스트 통과
- ✅ 성능 지표 목표 달성
- ✅ 보안 취약점 0건

### 비즈니스 성공 기준
- ✅ 사용자 만족도 유지/향상
- ✅ 신청 프로세스 완료율 95% 이상
- ✅ 지원 티켓 감소

## 📞 담당자 및 연락처

- **프로젝트 리드**: 개발팀
- **테스트 담당**: QA팀
- **배포 담당**: DevOps팀
- **비상 연락처**: (긴급 이슈 발생 시)

## 📚 참고 문서

- [Flutter 공식 문서](https://flutter.dev/docs)
- [Provider 패턴 가이드](https://pub.dev/packages/provider)
- [Flutter 테스팅 가이드](https://flutter.dev/docs/testing)
- [성능 최적화 가이드](https://flutter.dev/docs/perf)