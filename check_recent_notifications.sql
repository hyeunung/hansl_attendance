-- 최근 발주 관련 알림 확인
-- notifications 테이블에 저장된 알림 내역 조회

-- 1. 최근 1시간 이내 발주 관련 알림
SELECT 
    created_at,
    user_email,
    title,
    body,
    type,
    data->>'purchase_order_number' as purchase_order_number,
    is_read
FROM notifications
WHERE created_at > NOW() - INTERVAL '1 hour'
  AND (
    type IN ('purchase_request', 'new_purchase_request', 'final_approval_request', 'purchase_approved')
    OR data->>'type' IN ('purchase_request', 'new_purchase_request', 'final_approval_request', 'purchase_approved')
  )
ORDER BY created_at DESC;

-- 2. 특정 발주번호로 검색 (TEST로 시작하는 테스트 발주)
SELECT 
    created_at,
    user_email,
    title,
    body,
    data
FROM notifications
WHERE data->>'purchase_order_number' LIKE 'TEST-%'
   OR data->>'purchase_order_number' LIKE 'QUICK-TEST-%'
   OR data->>'purchase_order_number' LIKE 'ADV-%'
ORDER BY created_at DESC
LIMIT 20;

-- 3. 오늘 생성된 모든 알림 수 (타입별)
SELECT 
    type,
    COUNT(*) as count
FROM notifications
WHERE created_at > CURRENT_DATE
GROUP BY type
ORDER BY count DESC;
