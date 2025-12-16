# 🚨 긴급: Supabase API 키 완전 사라짐 대응

## 현재 상황
- 23분 전까지 정상 작동
- Dashboard에서 anon key와 service_role key 완전히 사라짐
- 사용자는 아무것도 건드리지 않음

## 🔥 즉시 해야 할 것

### 1단계: 프로젝트 상태 확인 (최우선)
Dashboard에서 확인:
- 프로젝트가 **"Paused"** 상태인지?
- **Billing** → **Subscription** 상태 확인
- 프로젝트가 삭제/아카이브되지 않았는지

### 2단계: 새 키 생성 (필수)
**Settings** → **API** → **Create new API keys** 클릭

⚠️ **주의**: 새 키를 생성하면 기존 키는 무효화됩니다!
하지만 이미 Dashboard에서 사라졌으므로 새로 생성해야 합니다.

### 3단계: 코드베이스 업데이트 (긴급)
새 키를 받으면 즉시 다음 파일들 업데이트:

1. **lib/main.dart** (line 78)
2. **test_all_push_notifications_with_db.sh** (line 11-12)
3. 모든 JavaScript 파일들:
   - check_jhw_leave.js
   - add_jhw_attendance_1201.js
   - check_jhw_leave_history.js
   - fix_jhw_leave.js
   - check_specific_employees.js
   - fix_inconsistent_data.js
   - investigate_inconsistent_employees.js
   - check_all_employees.js
   - debug_annual_leave.js

4. **.env** 파일 (있다면)

### 4단계: Supabase 지원팀 긴급 문의
이런 일은 정상이 아닙니다. 즉시 문의:
- https://supabase.com/support
- 또는 Discord: https://discord.supabase.com

**문의 내용**:
- 프로젝트 ID: qvhbigvdfyvhoegkhvef
- 문제: API 키가 23분 전까지 정상 작동하다가 Dashboard에서 완전히 사라짐
- 사용자는 아무것도 건드리지 않음
- 키 복구 가능한지 확인 요청

## 🎯 가능한 원인

### 1. Supabase 시스템 버그 (가능성 높음)
- Supabase 측의 일시적인 시스템 오류
- 키는 실제로 존재하지만 Dashboard에 표시 안 됨
- **해결**: 새 키 생성 또는 지원팀이 복구

### 2. 프로젝트 일시정지
- 무료 플랜의 자동 일시정지
- 결제 문제
- **해결**: Resume 후 키 재생성

### 3. 계정 보안 문제
- 계정 해킹 또는 무단 접근
- **해결**: 계정 보안 확인, 비밀번호 변경

### 4. Supabase 업데이트/마이그레이션
- 새로운 키 시스템으로 마이그레이션 중
- 기존 키 시스템 제거
- **해결**: 새 키 시스템으로 마이그레이션

## 📋 새 키 생성 후 체크리스트

- [ ] Dashboard에서 새 anon key 생성
- [ ] Dashboard에서 새 service_role key 생성
- [ ] lib/main.dart 업데이트
- [ ] 모든 JavaScript 파일 업데이트
- [ ] .env 파일 업데이트 (있다면)
- [ ] Edge Function 환경변수 업데이트 (Supabase Secrets)
- [ ] 앱 테스트 (로그인, API 호출 등)
- [ ] 푸시 알림 테스트
- [ ] 새 키를 안전한 곳에 백업

## ⚡ 임시 해결책

코드베이스에 하드코딩된 키들이 있으므로:
- 앱은 **일시적으로** 계속 작동할 수 있습니다
- 하지만 Dashboard에서 키가 사라졌다면 곧 무효화될 수 있습니다
- **즉시 새 키 생성 및 업데이트 필요**

## 🆘 최후의 수단

만약 새 키도 생성되지 않는다면:
1. **Supabase 지원팀 긴급 문의** (최우선)
2. 프로젝트를 새로 만들고 데이터 마이그레이션
3. 코드베이스의 키로 최대한 버티면서 지원팀 응답 대기










