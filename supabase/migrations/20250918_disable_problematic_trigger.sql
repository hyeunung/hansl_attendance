-- requester_email 오류를 일으키는 트리거 비활성화
-- 앱에서 직접 알림을 보내므로 트리거는 필요 없음

-- 1. 문제가 되는 트리거 비활성화
ALTER TABLE purchase_requests DISABLE TRIGGER trigger_notify_purchase_status;

-- 2. 트리거 삭제 (비활성화로 충분하지 않을 경우)
-- DROP TRIGGER IF EXISTS trigger_notify_purchase_status ON purchase_requests;

-- 3. 함수도 삭제 (필요시)
-- DROP FUNCTION IF EXISTS notify_purchase_status_change();

-- 확인용 쿼리
SELECT 
    tgname as trigger_name,
    tgenabled as is_enabled,
    tgrelid::regclass as table_name
FROM pg_trigger
WHERE tgrelid::regclass::text = 'purchase_requests'
AND tgname = 'trigger_notify_purchase_status';


















