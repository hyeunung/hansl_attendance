-- 🚀 빠른 단일 발주 알림 테스트
-- 1개의 발주만 생성해서 빠르게 테스트

-- 새 발주 요청 생성 (middle_manager + app_admin에게 알림)
INSERT INTO purchase_requests (
    purchase_order_number,
    requester_name,
    requester_email,
    payment_category,
    progress_type,
    middle_manager_status,
    is_payment_completed
) VALUES (
    'QUICK-' || TO_CHAR(NOW(), 'HHMMSS'),
    '테스트사용자',
    'scott@thefiveforest.com',  -- 실제 이메일로 변경
    '구매 요청',
    '일반',
    'pending',
    false
) RETURNING purchase_order_number, '✅ 발주 생성 완료' as status;

-- 아이템 추가 (위에서 생성한 발주번호 사용)
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
WHERE purchase_order_number LIKE 'QUICK-%'
ORDER BY created_at DESC
LIMIT 1;

-- 예상 알림:
-- 📱 middle_manager: "🆕 새 발주 승인 요청"
-- 📱 app_admin: "🆕 새 발주 승인 요청"
