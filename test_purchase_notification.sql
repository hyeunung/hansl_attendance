-- 발주/구매대기 푸시알림 테스트 스크립트
-- 실행 방법: Supabase SQL Editor에서 실행

-- 테스트 시작
DO $$
DECLARE
    v_purchase_order_number TEXT;
    v_advance_order_number TEXT;
    v_timestamp BIGINT;
BEGIN
    -- 고유한 발주번호 생성
    v_timestamp := EXTRACT(EPOCH FROM NOW())::BIGINT;
    v_purchase_order_number := 'TEST-' || SUBSTRING(v_timestamp::TEXT FROM 8);
    v_advance_order_number := 'ADV-' || SUBSTRING(v_timestamp::TEXT FROM 8);
    
    RAISE NOTICE '🚀 발주 알림 테스트 시작...';
    RAISE NOTICE '';
    
    -- 1. 새 발주 요청 생성 (일반)
    RAISE NOTICE '1️⃣ 일반 구매 요청 생성 중...';
    RAISE NOTICE '   발주번호: %', v_purchase_order_number;
    
    INSERT INTO purchase_requests (
        purchase_order_number,
        requester_name,
        requester_email,
        payment_category,
        progress_type,
        middle_manager_status,
        is_payment_completed,
        created_at
    ) VALUES (
        v_purchase_order_number,
        '홍길동',
        'scott@thefiveforest.com',  -- 실제 이메일로 변경 필요
        '구매 요청',
        '일반',
        'pending',
        false,
        NOW()
    );
    
    -- 발주 아이템 추가
    INSERT INTO purchase_request_items (
        purchase_order_number,
        item_name,
        quantity,
        unit_price_value,
        amount_value
    ) VALUES 
    (v_purchase_order_number, '노트북', 2, 1500000, 3000000),
    (v_purchase_order_number, '모니터', 4, 300000, 1200000);
    
    RAISE NOTICE '✅ 일반 구매 요청 생성 완료 (총 금액: 4,200,000원)';
    RAISE NOTICE '   → middle_manager에게 "🆕 새 발주 승인 요청" 알림 발송됨';
    RAISE NOTICE '';
    
    -- 3초 대기
    PERFORM pg_sleep(3);
    
    -- 2. 선진행 구매 요청 생성
    RAISE NOTICE '2️⃣ 선진행 구매 요청 생성 중...';
    RAISE NOTICE '   발주번호: %', v_advance_order_number;
    
    INSERT INTO purchase_requests (
        purchase_order_number,
        requester_name,
        requester_email,
        payment_category,
        progress_type,
        middle_manager_status,
        is_payment_completed,
        created_at
    ) VALUES (
        v_advance_order_number,
        '김철수',
        'test@example.com',
        '구매 요청',
        '선진행',
        'pending',
        false,
        NOW()
    );
    
    -- 발주 아이템 추가
    INSERT INTO purchase_request_items (
        purchase_order_number,
        item_name,
        quantity,
        unit_price_value,
        amount_value
    ) VALUES 
    (v_advance_order_number, '긴급 소모품', 10, 50000, 500000);
    
    RAISE NOTICE '✅ 선진행 구매 요청 생성 완료 (총 금액: 500,000원)';
    RAISE NOTICE '   → middle_manager에게 "🆕 [선진행] 새 발주 승인 요청" 알림 발송됨';
    RAISE NOTICE '   → lead buyer에게 "🛒 [선진행] 새로운 구매대기 항목" 알림 발송됨';
    RAISE NOTICE '';
    
    -- 3초 대기
    PERFORM pg_sleep(3);
    
    -- 3. 1차 승인 처리
    RAISE NOTICE '3️⃣ 일반 구매 요청 1차 승인 처리 중...';
    
    UPDATE purchase_requests
    SET 
        middle_manager_status = 'approved',
        middle_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_order_number;
    
    RAISE NOTICE '✅ 1차 승인 완료';
    RAISE NOTICE '   → consumable_manager와 app_admin에게 "🔍 최종 발주 승인 요청" 알림 발송됨';
    RAISE NOTICE '';
    
    -- 3초 대기
    PERFORM pg_sleep(3);
    
    -- 4. 최종 승인 처리
    RAISE NOTICE '4️⃣ 일반 구매 요청 최종 승인 처리 중...';
    
    UPDATE purchase_requests
    SET 
        consumable_manager_status = 'approved',
        consumable_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_order_number;
    
    RAISE NOTICE '✅ 최종 승인 완료';
    RAISE NOTICE '   → 신청자(홍길동)에게 "✅ 발주 승인 완료" 알림 발송됨';
    RAISE NOTICE '   → lead buyer에게 "🛒 새로운 구매대기 항목" 알림 발송됨';
    RAISE NOTICE '';
    
    RAISE NOTICE '✨ 테스트 완료!';
    RAISE NOTICE '';
    RAISE NOTICE '📱 다음 권한을 가진 사용자들의 기기에서 알림을 확인하세요:';
    RAISE NOTICE '   - middle_manager: 새 발주 요청 2건';
    RAISE NOTICE '   - consumable_manager: 최종 승인 요청 1건';
    RAISE NOTICE '   - app_admin: 새 발주 요청 2건 + 최종 승인 요청 1건';
    RAISE NOTICE '   - lead buyer: 선진행 1건 + 일반 승인완료 1건';
    RAISE NOTICE '   - 신청자(홍길동): 승인 완료 1건';
    RAISE NOTICE '';
    RAISE NOTICE '생성된 발주번호:';
    RAISE NOTICE '   - 일반: %', v_purchase_order_number;
    RAISE NOTICE '   - 선진행: %', v_advance_order_number;
    
END $$;

-- 생성된 테스트 데이터 확인
SELECT 
    purchase_order_number,
    requester_name,
    payment_category,
    progress_type,
    middle_manager_status,
    consumable_manager_status,
    created_at
FROM purchase_requests
WHERE purchase_order_number LIKE 'TEST-%' 
   OR purchase_order_number LIKE 'ADV-%'
ORDER BY created_at DESC
LIMIT 5;
