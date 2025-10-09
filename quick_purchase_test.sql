-- 빠른 발주 알림 테스트
-- Supabase SQL Editor에 복사해서 실행하세요

-- 1. 새 발주 요청 생성 (middle_manager에게 알림)
INSERT INTO purchase_requests (
    purchase_order_number,
    requester_name,
    requester_email,
    payment_category,
    progress_type,
    middle_manager_status,
    is_payment_completed
) VALUES (
    'QUICK-TEST-' || TO_CHAR(NOW(), 'HHMISS'),
    '테스트사용자',
    'scott@thefiveforest.com',  -- 실제 이메일로 변경
    '구매 요청',
    '일반',
    'pending',
    false
);

-- 발주 아이템도 함께 추가
INSERT INTO purchase_request_items (
    purchase_order_number,
    item_name,
    quantity,
    unit_price_value,
    amount_value
)
SELECT 
    purchase_order_number,
    '테스트 물품',
    1,
    100000,
    100000
FROM purchase_requests
WHERE purchase_order_number LIKE 'QUICK-TEST-%'
ORDER BY created_at DESC
LIMIT 1;
