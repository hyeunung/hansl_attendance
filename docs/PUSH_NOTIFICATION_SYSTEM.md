# 푸시알림 시스템 전체 로직 및 필터

## 1. 발주/구매 관련 알림 (purchase_requests 테이블)

### 1-1. 새 발주 요청 알림 (notify_new_purchase_request)
- **트리거**: INSERT 시
- **조건**: middle_manager_status = 'pending'
- **알림 대상**: middle_manager 역할 사용자 + app_admin 역할 사용자
- **알림 내용**: "🆕 새 발주 승인 요청" - "{신청자}님이 {카테고리} 발주({발주번호})를 요청했습니다. 금액: {총액}원"

### 1-2. 1차 승인 완료 → 최종 승인자 알림 (notify_purchase_status_change)
- **트리거**: UPDATE 시
- **조건**: middle_manager_status가 pending → approved로 변경
- **알림 대상** (카테고리별 분기):
  - 발주: raw_material_manager + app_admin
  - 구매 요청/구매요청: consumable_manager + app_admin
  - 기타: final_manager + app_admin
- **알림 내용**: "🔍 최종 발주 승인 요청" - "{신청자}님의 {카테고리}({발주번호})가 1차 승인되었습니다. 최종 승인이 필요합니다."

### 1-3. 최종 승인 완료 알림 (notify_purchase_status_change)
- **트리거**: UPDATE 시
- **조건**: raw_material_manager_status, consumable_manager_status, final_manager_status 중 하나가 pending → approved
- **알림 대상**: 신청자 개인 FCM 토큰으로 "✅ 발주 승인 완료" 알림

### 1-4. Lead Buyer 구매대기 알림 (notify_lead_buyer_purchase_request)
- **트리거**: INSERT 또는 UPDATE 시
- **조건**: payment_category = '구매 요청' AND is_payment_completed = false AND (progress_type이 '선진행'이거나 ('일반'이고 final_manager_status = 'approved'))
- **알림 대상**: lead buyer 역할 사용자
- **알림 내용**: "🛒 새로운 구매대기 항목" - "{신청자}님의 구매 요청({발주번호})이 구매대기 목록에 추가되었습니다."

## 2. 문의사항 관련 알림 (support_inquires 테이블)

### 2-1. 새 문의사항 등록 알림 (notify_new_inquiry_to_admins)
- **트리거**: INSERT 시
- **알림 대상**: app_admin 역할 사용자 (purchase_role 또는 attendance_role)
- **알림 내용**: "🆕 새로운 문의사항" - "{사용자}님이 새로운 문의사항을 등록했습니다: {제목}"

### 2-2. 문의사항 상태 변경 알림 (notify_inquiry_status_change)
- **트리거**: UPDATE 시
- **조건**: status 필드가 변경된 경우
- **알림 대상**: app_admin 역할 사용자 (purchase_role 또는 attendance_role)
- **알림 내용**: "📝 문의사항 상태 변경" - "{사용자}님의 문의사항이 {새상태} 상태로 변경되었습니다."

## 공통 필터링 조건
- FCM 토큰이 존재하고 비어있지 않아야 함
- app_settings 테이블에서 supabase_url과 supabase_service_role_key가 설정되어 있어야 함
- Edge Function: send_fcm_notification 사용
- 인증: Service Role Key 사용
- 타입: admin (관리자용) 또는 user (개인용)
- 데이터베이스 저장: skip_db_notification: true로 설정하여 중복 저장 방지

## 역할별 사용자 현황
- 일반 사용자 (역할 없음): 23명 (FCM 토큰 22개)
- middle_manager + app_admin + lead buyer: 1명
- final_approver + consumable_manager: 1명
- final_approver + raw_material_manager: 1명
- purchase_manager + lead buyer: 1명
- purchase_manager: 1명
- ceo: 1명
- 기타 팀 매니저들: 4명

## 활성화된 트리거 목록
1. trigger_notify_new_purchase_request (purchase_requests)
2. trigger_notify_lead_buyer_purchase_request (purchase_requests)
3. trigger_notify_purchase_status (purchase_requests)
4. trigger_notify_inquiry_status_change (support_inquires)
5. trigger_notify_new_inquiry (support_inquires)

## ⚠️ **중요: 공통 Edge Function**
- **함수**: `send_fcm_notification`
- **파일**: `supabase/functions/send_fcm_notification/index.ts`
- **용도**: **발주/구매 알림** + **연차/출장 알림** 공통 사용
- **핵심 로직**: `getAdminAndManagerTokens()` 함수에서 역할별 FCM 토큰 수집
- **⚠️ 절대 삭제 금지**: 시스템 재구성 시에도 반드시 보존해야 함

## 재설정 시 적용 방법
이 문서의 로직과 필터를 그대로 적용하여 푸시알림 시스템을 재구성하면 됩니다.
