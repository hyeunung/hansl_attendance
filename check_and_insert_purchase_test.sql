-- 테이블 존재 여부 확인 후 테스트 데이터 추가

-- 1. 먼저 테이블이 있는지 확인
DO $$
DECLARE
    v_table_exists BOOLEAN;
    v_po_number TEXT;
BEGIN
    -- purchase_requests 테이블 존재 확인
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'purchase_requests'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '❌ purchase_requests 테이블이 없습니다!';
        RAISE NOTICE '   create_purchase_tables.sql을 먼저 실행하세요.';
        RETURN;
    END IF;
    
    -- 테이블이 있으면 테스트 데이터 추가
    v_po_number := 'TEST-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS');
    
    RAISE NOTICE '✅ 테이블이 존재합니다. 테스트 데이터를 추가합니다.';
    RAISE NOTICE '📋 발주번호: %', v_po_number;
    
    -- purchase_requests에 데이터 추가
    INSERT INTO purchase_requests (
        purchase_order_number,
        requester_name,
        requester_email,
        payment_category,
        progress_type,
        vendor_name,
        item_name,
        quantity,
        unit_price_value,
        amount_value,
        middle_manager_status,
        final_manager_status,
        is_payment_completed,
        is_received,
        request_date,
        created_at
    ) VALUES (
        v_po_number,
        '테스트 직원',
        'scott@thefiveforest.com',
        '구매 요청',
        '일반',
        'IT벤더',
        '노트북 외 1건',
        3,
        1500000,
        3600000,
        'pending',
        'pending',
        false,
        false,
        CURRENT_DATE,
        NOW()
    );
    
    -- purchase_request_items 테이블이 있으면 아이템도 추가
    IF EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'purchase_request_items'
    ) THEN
        INSERT INTO purchase_request_items (
            purchase_order_number,
            item_name,
            vendor_name,
            quantity,
            unit_price_value,
            amount_value,
            line_number
        ) VALUES 
        (v_po_number, '노트북', 'IT벤더', 2, 1500000, 3000000, 1),
        (v_po_number, '모니터', 'IT벤더', 2, 300000, 600000, 2);
        
        RAISE NOTICE '✅ 아이템 2개 추가 완료';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📱 발주 승인 알림이 다음 대상에게 발송됩니다:';
    RAISE NOTICE '   - middle_manager 권한을 가진 사용자';
    RAISE NOTICE '   - app_admin 권한을 가진 사용자';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ 오류 발생: %', SQLERRM;
END $$;

-- 생성된 데이터 확인
SELECT 
    purchase_order_number as "발주번호",
    requester_name as "요청자",
    payment_category as "카테고리",
    vendor_name as "벤더",
    amount_value as "금액",
    middle_manager_status as "1차승인",
    created_at as "생성시간"
FROM purchase_requests
WHERE purchase_order_number LIKE 'TEST-%'
ORDER BY created_at DESC
LIMIT 5;
