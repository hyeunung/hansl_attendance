# 🚀 Feature Flag 가이드 - HANSL 리팩토링

## 🎯 빠른 시작

### 1. 테스트 실행
```bash
# 모든 테스트 실행
chmod +x run_tests.sh
./run_tests.sh

# 특정 테스트만 실행
flutter test test/utils/validators/
flutter test test/widgets/
flutter test integration_test/
```

### 2. 리팩토링된 화면 활성화

#### 방법 1: 코드에서 직접 변경
```dart
// lib/services/feature_flag_service.dart
static const Map<String, bool> _defaultFlags = {
  'refactored_leave_screen': true,  // ← true로 변경
  'refactored_business_trip_screen': false,
  'new_validators': true,
  'enhanced_logging': true,
  'performance_monitoring': true,
  'show_debug_info': true,  // ← 디버그 정보 표시
};
```

#### 방법 2: 앱 내 설정 화면 사용
1. 앱 실행
2. 설정 화면 진입
3. "Feature Flags (개발용)" 메뉴 선택
4. 원하는 플래그 ON/OFF

#### 방법 3: A/B 테스트 설정
```dart
// 특정 사용자에게만 새 화면 표시 (10% 롤아웃)
final shouldUseNew = FeatureFlagService().shouldUseNewFeature(
  userId,
  'refactored_leave_screen',
  percentage: 10,
);
```

## 📊 성능 모니터링

### 성능 메트릭 확인
```dart
// 디버그 콘솔에서 확인
PerformanceMonitor.logReport();

// 프로그래맵틱하게 확인
final report = PerformanceMonitor.generateReport();
print(report);
```

### 예상 개선 지표
- 🚀 **화면 로드 시간**: 500ms → 350ms (30% 감소)
- 💾 **메모리 사용량**: 120MB → 85MB (30% 감소)
- 🔄 **리빌드 횟수**: 10회/분 → 3회/분 (70% 감소)
- 📊 **코드 라인 수**: 655 → 350 (47% 감소)

## 🔧 테스트 환경 설정

### 필수 Provider 설정
```dart
// test/helpers/test_providers.dart
class TestProviders {
  static Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }
}
```

### 테스트 실행 예시
```dart
testWidgets('연차 신청 프로세스', (tester) async {
  await tester.pumpWidget(
    TestProviders.wrap(
      const AnnualLeaveRequestScreenOptimized(),
    ),
  );
  
  // 테스트 로직...
});
```

## 📁 프로젝트 구조

```
lib/
├── screens/
│   ├── leave/
│   │   ├── annual_leave_request_screen.dart         # 기존 화면
│   │   ├── annual_leave_request_screen_optimized.dart # 리팩토링된 화면
│   │   └── leave_screen_router.dart                  # 라우터
│   └── settings/
│       └── feature_flag_settings_screen.dart         # 플래그 설정 UI
├── services/
│   ├── feature_flag_service.dart                     # 플래그 관리
│   └── performance_monitor.dart                      # 성능 추적
├── widgets/
│   ├── leave/
│   │   ├── leave_calendar_widget.dart                # 캘린더 컴포넌트
│   │   ├── leave_info_card_widget.dart               # 연차 정보 카드
│   │   └── leave_type_selector_widget.dart           # 타입 선택기
│   └── common/
│       └── notification_banner_widget.dart           # 알림 배너
└── utils/
    ├── validators/
    │   └── leave_validators.dart                      # 입력 검증
    └── logger.dart                                   # 로깅 시스템

test/
├── utils/validators/                                  # 단위 테스트
├── widgets/                                           # 위젯 테스트
└── integration_test/                                   # 통합 테스트
```

## 📑 체크리스트

### 배포 전
- [ ] 모든 테스트 통과 (`./run_tests.sh`)
- [ ] Feature Flag 기본값 확인 (false로 설정)
- [ ] 성능 메트릭 확인
- [ ] 코드 리뷰 완료

### 내부 테스트 (1주차)
- [ ] Feature Flag 10% 활성화
- [ ] 내부 테스트 그룹 선정
- [ ] 버그 및 피드백 수집
- [ ] 성능 비교 분석

### 단계적 롤아웃 (2-3주차)
- [ ] 25% 사용자 활성화
- [ ] 모니터링 및 에러률 확인
- [ ] 50% 사용자 활성화
- [ ] 최종 성능 평가

### 완전 배포 (4주차)
- [ ] 100% 활성화
- [ ] 기존 코드 제거
- [ ] Feature Flag 정리
- [ ] 문서 업데이트

## 🎆 예상 효과

### 정량적 개선
| 지표 | 기존 | 개선 | 향상률 |
|------|--------|--------|----------|
| 코드 라인 수 | 655 | 350 | -47% |
| 메모리 사용량 | 120MB | 85MB | -30% |
| 화면 로드 시간 | 500ms | 350ms | -30% |
| 리빌드 횟수 | 10/min | 3/min | -70% |
| 테스트 커버리지 | 0% | 80% | +80% |

### 정성적 개선
- ✅ 모듈화된 컴포넌트로 재사용성 향상
- ✅ 보안 취약점 해결 (SQL Injection, XSS)
- ✅ 체계적인 로깅 시스템
- ✅ 테스트 가능한 코드 구조
- ✅ 명확한 마이그레이션 경로

## 🆘 문의 및 지원

기술적 문의사항이나 이슈가 있으면 개발팀에 문의하세요.

## 📖 참고 문서
- [Flutter 테스팅 가이드](https://flutter.dev/docs/testing)
- [Provider 패턴](https://pub.dev/packages/provider)
- [Flutter 성능 최적화](https://flutter.dev/docs/perf)