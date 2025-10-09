# 🚀 발주/구매대기 푸시알림 테스트 가이드

## 📱 테스트 전 확인사항

1. **FCM 토큰 확인**
   - 테스트할 사용자들이 최근에 앱에 로그인했는지 확인
   - SQL: `check_purchase_roles.sql` 실행

2. **역할(Role) 확인**
   - middle_manager
   - raw_material_manager
   - consumable_manager
   - lead buyer
   - app_admin

## 🔧 테스트 실행 순서

### Step 1: Supabase Dashboard 접속
[SQL Editor 열기](https://supabase.com/dashboard/project/tqyfakmpdijktyowsozw/sql/new)

### Step 2: 권한 확인
```sql
-- check_purchase_roles.sql 실행
-- FCM 토큰이 있는 사용자 확인
```

### Step 3: 메인 테스트 실행

#### 옵션 A: 현재 구현된 기능만 테스트
```sql
-- test_all_purchase_notifications_fixed.sql 실행
-- 승인 플로우만 테스트 (반려 제외)
```

#### 옵션 B: 반려 포함 전체 테스트 (마이그레이션 필요)
```sql
-- 1. 먼저 반려 알림 마이그레이션 적용
-- 20250202_add_purchase_rejection_notification.sql 실행

-- 2. 전체 테스트 실행
-- test_all_purchase_notifications_with_rejection.sql 실행
```

### Step 4: 결과 확인
```sql
-- check_notification_results.sql 실행
-- 각 쿼리별로 알림 발송 현황 확인
```

## 📊 예상 알림 시나리오

### 1. 새 발주 요청
- **수신자**: middle_manager + app_admin
- **제목**: 🆕 새 발주 승인 요청
- **내용**: {요청자}님이 {카테고리} 발주({번호})를 요청했습니다. 금액: {금액}원

### 2. 1차 승인 → 발주 카테고리
- **수신자**: raw_material_manager + app_admin
- **제목**: 🔍 최종 발주 승인 요청
- **내용**: {요청자}님의 발주({번호})가 1차 승인되었습니다. 최종 승인이 필요합니다.

### 3. 1차 승인 → 구매요청 카테고리
- **수신자**: consumable_manager + app_admin
- **제목**: 🔍 최종 발주 승인 요청
- **내용**: {요청자}님의 구매 요청({번호})가 1차 승인되었습니다. 최종 승인이 필요합니다.

### 4. 최종 승인 완료
- **수신자1**: 요청자 본인
  - **제목**: ✅ 발주 승인 완료
  - **내용**: 발주 요청({번호})이 최종 승인되었습니다.
  
- **수신자2**: lead buyer (구매요청만)
  - **제목**: 🛒 새로운 구매대기 항목
  - **내용**: {요청자}님의 구매 요청({번호})이 구매대기 목록에 추가되었습니다.

### 5. 선진행 구매요청
- **동시 발송**:
  - middle_manager: 🆕 [선진행] 새 발주 승인 요청
  - lead buyer: 🛒 [선진행] 새로운 구매대기 항목

### 6. 반려 (마이그레이션 적용 시)
- **수신자**: 요청자 본인
- **제목**: ❌ 발주 반려 / ❌ 발주 최종 반려
- **내용**: 발주 요청({번호})이 반려되었습니다. 사유: {반려사유}

## ⚠️ 문제 해결

### 알림이 안 올 때
1. **FCM 토큰 확인**: 해당 사용자가 앱에 로그인했는지
2. **권한 확인**: purchase_role 배열에 올바른 권한이 있는지
3. **트리거 상태**: `trigger_notify_purchase_status`가 활성화되어 있는지
4. **Edge Function**: Supabase Dashboard → Functions → Logs 확인

### 중복 알림
- notifications 테이블에서 중복 확인
- Edge Function의 skip_db_notification 파라미터 확인

### 반려 알림이 안 올 때
- 20250202_add_purchase_rejection_notification.sql 마이그레이션 적용 확인
- middle_manager_comment 또는 rejection_reason 필드 값 확인

## 📝 테스트 후 정리

```sql
-- 테스트 데이터 삭제 (선택사항)
DELETE FROM purchase_request_items 
WHERE purchase_order_number LIKE 'TEST-%' 
   OR purchase_order_number LIKE 'P_-%'
   OR purchase_order_number LIKE 'RAW-%'
   OR purchase_order_number LIKE 'BUY-%'
   OR purchase_order_number LIKE 'ADV-%';

DELETE FROM purchase_requests 
WHERE purchase_order_number LIKE 'TEST-%' 
   OR purchase_order_number LIKE 'P_-%'
   OR purchase_order_number LIKE 'RAW-%'
   OR purchase_order_number LIKE 'BUY-%'
   OR purchase_order_number LIKE 'ADV-%';

-- 알림 내역 정리 (선택사항)
DELETE FROM notifications 
WHERE data->>'purchase_order_number' LIKE 'TEST-%'
   OR data->>'purchase_order_number' LIKE 'P_-%';
```

---
테스트 진행 후 문제가 있으면 알려주세요! 🎯
