# HANSL 프로젝트 구조 및 폴더/파일 역할 설명

## 폴더/파일 구조 예시

```
lib/
  main.dart
  theme/
    app_colors.dart
    app_theme.dart
    app_text_theme.dart
  screens/
    splash/
      splash_screen.dart
    auth/
      login_screen.dart
    attendance/
      attendance_screen.dart
    leave/
      leave_status_screen.dart
      annual_leave_request_screen.dart
      business_trip_request_screen.dart
    approval/
      approval_screen.dart
    calendar/
      calendar_screen.dart
    settings/
      settings_screen.dart
  widgets/
    custom_button.dart
    custom_text_field.dart
  services/
    supabase_service.dart
    auth_service.dart
    attendance_service.dart
    leave_service.dart
  models/
    employee.dart
    attendance.dart
    leave_request.dart
  providers/
    auth_provider.dart
    user_provider.dart
    attendance_provider.dart
    leave_provider.dart
  utils/
    date_utils.dart
    validator.dart
  constants/
    app_strings.dart
    app_times.dart
assets/
  fonts/
    NotoSans-*.otf
```

---

## 폴더/파일별 역할 설명

- **lib/main.dart**: 앱의 시작점, 전체 앱 실행 코드
- **lib/theme/**: 앱의 디자인 시스템(색, 폰트, 테마 등)
  - `app_colors.dart`: 주요 색상 정의
  - `app_theme.dart`: 전체 테마(색, 폰트, 버튼 스타일 등)
  - `app_text_theme.dart`: 폰트 종류, 크기, 굵기 등 텍스트 스타일
- **lib/screens/**: 각 화면별 UI/로직(앱의 주요 페이지)
  - `splash/splash_screen.dart`: 로고/앱 로딩 화면
  - `auth/login_screen.dart`: 로그인 화면
  - `attendance/attendance_screen.dart`: 출퇴근(근무 기록) 화면
  - `leave/leave_status_screen.dart`: 내 연차/출장 현황 화면
  - `leave/annual_leave_request_screen.dart`: 연차 신청 화면
  - `leave/business_trip_request_screen.dart`: 출장 신청 화면
  - `approval/approval_screen.dart`: 관리자 승인 화면
  - `calendar/calendar_screen.dart`: 달력(팀/개인 일정) 화면
  - `settings/settings_screen.dart`: 설정(내 정보, 로그아웃 등) 화면
- **lib/widgets/**: 여러 화면에서 재사용하는 부품(버튼, 입력창 등)
  - `custom_button.dart`: 커스텀 버튼
  - `custom_text_field.dart`: 입력창
- **lib/services/**: 외부 서비스/API 연동, 인증, DB 처리
  - `supabase_service.dart`: Supabase DB 연동
  - `auth_service.dart`: 인증 관련 함수
  - `attendance_service.dart`: 출퇴근 기록 함수
  - `leave_service.dart`: 연차/출장 함수
- **lib/models/**: 데이터 구조(클래스) 정의
  - `employee.dart`: 직원 정보
  - `attendance.dart`: 출퇴근 기록
  - `leave_request.dart`: 연차/출장 신청
- **lib/providers/**: 상태관리(앱의 데이터/상태 관리)
  - `auth_provider.dart`: 로그인 상태, 사용자 정보
  - `attendance_provider.dart`: 출퇴근 기록 상태
  - `leave_provider.dart`: 연차/출장 상태
- **lib/utils/**: 유틸리티 함수(날짜 계산, 유효성 검사 등)
  - `date_utils.dart`: 날짜 계산, 포맷
  - `validator.dart`: 입력값 유효성 검사
- **lib/constants/**: 앱에서 반복적으로 쓰는 상수(문구, 시간 등)
  - `app_strings.dart`: 안내 문구, 버튼 텍스트
  - `app_times.dart`: 출근 마감, 리셋 시간 등
- **assets/fonts/**: 회사 지정 폰트 파일(NotoSans 등)

---

> 이 문서는 프로젝트 구조와 각 파일/폴더의 역할을 쉽게 파악하고, 협업 및 유지보수에 도움을 주기 위해 작성되었습니다. 