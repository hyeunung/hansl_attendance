# 문의하기 시스템 통합 가이드

## 📌 개요
Flutter 앱(hansl)과 웹앱(hanslworkspace)의 문의하기 시스템을 통합하여 중앙 관리 시스템을 구축했습니다.

## 🏗️ 시스템 구조

### 데이터베이스
- **테이블**: `support_inquiries`
- **위치**: Supabase (공유 DB)
- **RLS**: 활성화됨 (사용자별 권한 제어)

### 주요 필드
```sql
- id: 문의 ID (자동 생성)
- user_id: 작성자 ID
- user_email: 작성자 이메일
- user_name: 작성자 이름
- inquiry_type: 문의 유형 (bug, modify, delete, other)
- subject: 제목
- message: 내용
- status: 상태 (open, in_progress, resolved, closed)
- resolution_note: 답변 내용
- handled_by: 처리 담당자
- created_at: 생성일시
- updated_at: 수정일시
```

## 👥 권한 체계

### 일반 직원 (app_admin이 아닌 사용자)
- ✅ 문의 작성 가능
- ✅ 본인 문의 조회 (Flutter + 웹 모두)
- ❌ 타인 문의 조회 불가
- ❌ 문의 상태 변경 불가

### 관리자 (app_admin)
- ❌ 문의 작성 불가 (Flutter 앱에서)
- ✅ 모든 문의 조회
- ✅ 상태 변경 (open → in_progress → resolved → closed)
- ✅ 답변 작성

## 📱 Flutter 앱 구현

### 파일 구조
```
lib/
├── services/
│   └── inquiry_service.dart       # 문의 서비스 로직
├── screens/
│   ├── inquiry/
│   │   └── inquiry_screen.dart    # 문의하기 화면
│   └── settings/
│       └── settings_screen.dart   # 설정 화면 (문의 진입점)
```

### 문의 유형 (Flutter)
- **앱관련**: 앱 기능 관련 문의
- **오류**: 버그 신고
- **기타**: 기타 문의사항

### 주요 기능
1. **문의 작성**: 유형 선택 → 제목/내용 입력 → 제출
2. **문의 목록**: 작성한 모든 문의 확인 (웹/앱 통합)
3. **실시간 업데이트**: Supabase Realtime으로 답변 즉시 반영
4. **Push 알림**: 답변 시 FCM 푸시 알림

## 🌐 웹앱 구현

### 파일 구조
```
src/
├── components/
│   └── support/
│       └── SupportMain.tsx        # 문의 관리 화면
├── services/
│   └── supportService.ts          # 문의 서비스 로직
```

### 문의 유형 (웹)
- **bug**: 버그 신고
- **modify**: 수정 요청 (발주 관련)
- **delete**: 삭제 요청 (발주 관련)
- **other**: 기타 문의

## 🔔 알림 시스템

### 실시간 알림 (Supabase Realtime)
- 앱이 실행 중일 때 즉시 업데이트
- 답변 작성 시 실시간 반영

### Push 알림 (Firebase FCM)
- 앱이 백그라운드/종료 상태일 때
- Edge Function: `notify_inquiry_response`
- 트리거: 답변 작성 또는 상태 변경 시

## 🚀 배포 가이드

### 1. 데이터베이스 마이그레이션
```bash
# Supabase CLI로 마이그레이션 실행
supabase db push
```

### 2. Edge Function 배포
```bash
# 문의 답변 알림 함수 배포
supabase functions deploy notify_inquiry_response
```

### 3. 환경 변수 설정
```bash
# Supabase Dashboard에서 설정
FCM_SERVER_KEY=your_fcm_server_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

### 4. Flutter 앱 빌드
```bash
flutter pub get
flutter build apk --release
```

## 🔧 유지보수

### 문의 상태 흐름
```
open (대기중) → in_progress (처리중) → resolved (해결됨) → closed (종료)
```

### 트러블슈팅

#### Push 알림이 오지 않는 경우
1. FCM 토큰 확인 (`employees.fcm_token`)
2. FCM_SERVER_KEY 환경 변수 확인
3. Edge Function 로그 확인

#### 실시간 업데이트가 안 되는 경우
1. Supabase Realtime 활성화 확인
2. RLS 정책 확인
3. 네트워크 연결 상태 확인

#### 권한 오류 발생 시
1. `purchase_role` 필드 확인
2. RLS 정책 검토
3. 인증 토큰 유효성 확인

## 📊 모니터링

### 주요 메트릭
- 일일 문의 건수
- 평균 응답 시간
- 문의 유형별 분포
- 해결률

### 로그 확인
```sql
-- 최근 문의 조회
SELECT * FROM support_inquiries 
ORDER BY created_at DESC 
LIMIT 20;

-- 미처리 문의 확인
SELECT * FROM support_inquiries 
WHERE status = 'open' 
ORDER BY created_at ASC;

-- 관리자별 처리 건수
SELECT handled_by, COUNT(*) as count 
FROM support_inquiries 
WHERE handled_by IS NOT NULL 
GROUP BY handled_by;
```

## 🔐 보안 고려사항

1. **RLS 정책**: 사용자별 데이터 접근 제한
2. **인증**: Supabase JWT 토큰 기반
3. **권한 검증**: app_admin 권한 서버 측 검증
4. **데이터 암호화**: HTTPS 통신
5. **입력 검증**: SQL Injection 방지

## 📝 향후 개선사항

1. **카테고리 세분화**: 문의 유형 추가
2. **파일 첨부**: 스크린샷 등 첨부 기능
3. **검색 기능**: 문의 내역 검색
4. **통계 대시보드**: 관리자용 통계 화면
5. **자동 응답**: FAQ 기반 자동 응답
6. **평가 시스템**: 답변 만족도 평가

## 📞 문의
- 기술 지원: IT팀
- 시스템 관리: 관리자 (app_admin)