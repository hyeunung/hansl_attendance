-- 간단한 발주 테스트 데이터 추가
DO $$
DECLARE
    v_po_number TEXT;
BEGIN
    -- 발주번호 생성
    v_po_number := 'TEST-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS');
    
    RAISE NOTICE '📋 테스트 발주 생성: %', v_po_number;
    
    -- 1. 새 발주 요청 생성
    INSERT INTO purchase_requests (
        purchase_order_number,
        requester_name,
        requester_email,
        payment_category,
        progress_type,
        middle_manager_status,
        final_manager_status,
        is_payment_completed,
        is_received,
        created_at,
        request_date
    ) VALUES (
        v_po_number,
        '테스트 직원',
        'scott@thefiveforest.com',
        '구매 요청',
        '일반',
        'pending',
        'pending',
        false,
        false,
        NOW(),
        CURRENT_DATE
    );
    
    -- 2. 발주 아이템 추가
    INSERT INTO purchase_request_items (
        purchase_order_number,
        item_name,
        vendor_name,
        quantity,
        unit_price_value,
        amount_value,
        line_number,
        is_payment_completed,
        is_received
    ) VALUES 
    (v_po_number, '노트북', 'IT벤더', 2, 1500000, 3000000, 1, false, false),
    (v_po_number, '모니터', 'IT벤더', 2, 300000, 600000, 2, false, false);
    
    RAISE NOTICE '✅ 발주 생성 완료!';
    RAISE NOTICE '   - 발주번호: %', v_po_number;
    RAISE NOTICE '   - 총액: 3,600,000원';
    RAISE NOTICE '   - 상태: 1차 승인 대기중';
    RAISE NOTICE '';
    RAISE NOTICE '📱 알림 발송 대상:';
    RAISE NOTICE '   - middle_manager 권한자';
    RAISE NOTICE '   - app_admin 권한자';
    
END $$;

-- 생성된 데이터 확인
SELECT 
    purchase_order_number as "발주번호",
    requester_name as "요청자",
    payment_category as "카테고리",
    middle_manager_status as "1차승인",
    final_manager_status as "최종승인",
    created_at as "생성시간"
FROM purchase_requests
WHERE purchase_order_number LIKE 'TEST-%'
ORDER BY created_at DESC
LIMIT 5;
