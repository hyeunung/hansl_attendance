-- ================================================
-- 발주 관련 모든 푸시알림 테스트 스크립트
-- ================================================
-- 현재 구현된 알림:
-- 1. 새 구매 요청 → middle_manager + app_admin
-- 2. 1차 승인 (발주) → raw_material_manager + app_admin
-- 3. 1차 승인 (구매요청) → consumable_manager + app_admin
-- 4. 최종 승인 → 요청자 + lead buyer
-- 
-- ⚠️ 주의: 반려 알림은 현재 구현되어 있지 않음
-- ================================================

DO $$
DECLARE
    v_purchase_1 TEXT; -- 발주 카테고리
    v_purchase_2 TEXT; -- 구매요청 카테고리
    v_purchase_3 TEXT; -- 선진행 테스트용
    v_timestamp TEXT;
BEGIN
    -- 타임스탬프 생성
    v_timestamp := TO_CHAR(NOW(), 'HHMMSS');
    v_purchase_1 := 'RAW-' || v_timestamp;
    v_purchase_2 := 'BUY-' || v_timestamp;
    v_purchase_3 := 'ADV-' || v_timestamp;
    
    RAISE NOTICE '';
    RAISE NOTICE '🚀 발주 관련 모든 푸시알림 테스트 시작!';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 1: 발주 카테고리 (원자재)
    -- ========================================
    RAISE NOTICE '📋 시나리오 1: 발주 카테고리 (원자재) 테스트';
    RAISE NOTICE '----------------------------------------';
    
    -- 1-1. 새 발주 요청 생성
    RAISE NOTICE '1️⃣ 새 발주 요청 생성 [%]', v_purchase_1;
    
    INSERT INTO purchase_requests (
        purchase_order_number,
        requester_name,
        requester_email,
        payment_category,
        progress_type,
        middle_manager_status,
        is_payment_completed
    ) VALUES (
        v_purchase_1,
        '김철수',
        'scott@thefiveforest.com', -- 실제 이메일로 변경
        '발주', -- 원자재 카테고리
        '일반',
        'pending',
        false
    );
    
    -- 발주 아이템 추가
    INSERT INTO purchase_request_items (
        purchase_order_number,
        item_name,
        quantity,
        unit_price_value,
        amount_value
    ) VALUES 
    (v_purchase_1, '철강재', 100, 50000, 5000000),
    (v_purchase_1, '알루미늄', 50, 30000, 1500000);
    
    RAISE NOTICE '   ✅ 생성 완료 (총액: 6,500,000원)';
    RAISE NOTICE '   📱 예상 알림:';
    RAISE NOTICE '      → middle_manager: "🆕 새 발주 승인 요청"';
    RAISE NOTICE '      → app_admin: "🆕 새 발주 승인 요청"';
    RAISE NOTICE '';
    
    -- 5초 대기
    PERFORM pg_sleep(5);
    
    -- 1-2. 1차 승인 처리
    RAISE NOTICE '2️⃣ 1차 승인 처리 중...';
    
    UPDATE purchase_requests
    SET 
        middle_manager_status = 'approved',
        middle_manager_approved_at = NOW(),
        middle_manager_comment = '1차 승인 완료'
    WHERE purchase_order_number = v_purchase_1;
    
    RAISE NOTICE '   ✅ 1차 승인 완료';
    RAISE NOTICE '   📱 예상 알림:';
    RAISE NOTICE '      → raw_material_manager: "🔍 최종 발주 승인 요청"';
    RAISE NOTICE '      → app_admin: "🔍 최종 발주 승인 요청"';
    RAISE NOTICE '';
    
    -- 5초 대기
    PERFORM pg_sleep(5);
    
    -- 1-3. 최종 승인 처리
    RAISE NOTICE '3️⃣ 최종 승인 처리 중...';
    
    UPDATE purchase_requests
    SET 
        raw_material_manager_status = 'approved',
        raw_material_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_1;
    
    RAISE NOTICE '   ✅ 최종 승인 완료';
    RAISE NOTICE '   📱 예상 알림:';
    RAISE NOTICE '      → 김철수: "✅ 발주 승인 완료"';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 2: 구매요청 카테고리
    -- ========================================
    PERFORM pg_sleep(3);
    RAISE NOTICE '';
    RAISE NOTICE '📋 시나리오 2: 구매요청 카테고리 테스트';
    RAISE NOTICE '----------------------------------------';
    
    -- 2-1. 새 구매 요청 생성
    RAISE NOTICE '1️⃣ 새 구매 요청 생성 [%]', v_purchase_2;
    
    INSERT INTO purchase_requests (
        purchase_order_number,
        requester_name,
        requester_email,
        payment_category,
        progress_type,
        middle_manager_status,
        is_payment_completed
    ) VALUES (
        v_purchase_2,
        '이영희',
        'test@example.com',
        '구매 요청', -- 구매요청 카테고리
        '일반',
        'pending',
        false
    );
    
    -- 발주 아이템 추가
    INSERT INTO purchase_request_items (
        purchase_order_number,
        item_name,
        quantity,
        unit_price_value,
        amount_value
    ) VALUES 
    (v_purchase_2, '사무용품', 20, 10000, 200000),
    (v_purchase_2, '프린터 토너', 5, 50000, 250000);
    
    RAISE NOTICE '   ✅ 생성 완료 (총액: 450,000원)';
    RAISE NOTICE '   📱 예상 알림:';
    RAISE NOTICE '      → middle_manager: "🆕 새 발주 승인 요청"';
    RAISE NOTICE '      → app_admin: "🆕 새 발주 승인 요청"';
    RAISE NOTICE '';
    
    -- 5초 대기
    PERFORM pg_sleep(5);
    
    -- 2-2. 1차 승인 처리
    RAISE NOTICE '2️⃣ 1차 승인 처리 중...';
    
    UPDATE purchase_requests
    SET 
        middle_manager_status = 'approved',
        middle_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_2;
    
    RAISE NOTICE '   ✅ 1차 승인 완료';
    RAISE NOTICE '   📱 예상 알림:';
    RAISE NOTICE '      → consumable_manager: "🔍 최종 발주 승인 요청"';
    RAISE NOTICE '      → app_admin: "🔍 최종 발주 승인 요청"';
    RAISE NOTICE '';
    
    -- 5초 대기
    PERFORM pg_sleep(5);
    
    -- 2-3. 최종 승인 처리
    RAISE NOTICE '3️⃣ 최종 승인 처리 중...';
    
    UPDATE purchase_requests
    SET 
        consumable_manager_status = 'approved',
        consumable_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_2;
    
    RAISE NOTICE '   ✅ 최종 승인 완료';
    RAISE NOTICE '   📱 예상 알림:';
    RAISE NOTICE '      → 이영희: "✅ 발주 승인 완료"';
    RAISE NOTICE '      → lead buyer: "🛒 새로운 구매대기 항목"';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 3: 선진행 구매요청
    -- ========================================
    PERFORM pg_sleep(3);
    RAISE NOTICE '';
    RAISE NOTICE '📋 시나리오 3: 선진행 구매요청 테스트';
    RAISE NOTICE '----------------------------------------';
    
    -- 3-1. 선진행 구매 요청 생성
    RAISE NOTICE '1️⃣ 선진행 구매 요청 생성 [%]', v_purchase_3;
    
    INSERT INTO purchase_requests (
        purchase_order_number,
        requester_name,
        requester_email,
        payment_category,
        progress_type,
        middle_manager_status,
        is_payment_completed
    ) VALUES (
        v_purchase_3,
        '박민수',
        'test2@example.com',
        '구매 요청',
        '선진행', -- 선진행!
        'pending',
        false
    );
    
    -- 발주 아이템 추가
    INSERT INTO purchase_request_items (
        purchase_order_number,
        item_name,
        quantity,
        unit_price_value,
        amount_value
    ) VALUES 
    (v_purchase_3, '긴급 부품', 1, 1000000, 1000000);
    
    RAISE NOTICE '   ✅ 생성 완료 (총액: 1,000,000원)';
    RAISE NOTICE '   📱 예상 알림:';
    RAISE NOTICE '      → middle_manager: "🆕 [선진행] 새 발주 승인 요청"';
    RAISE NOTICE '      → lead buyer: "🛒 [선진행] 새로운 구매대기 항목"';
    RAISE NOTICE '      → app_admin: 위 두 알림 모두';
    RAISE NOTICE '';
    
    -- ========================================
    -- 결과 요약
    -- ========================================
    PERFORM pg_sleep(3);
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '✨ 테스트 완료!';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 총 발송된 알림 수:';
    RAISE NOTICE '';
    RAISE NOTICE '👤 역할별 알림:';
    RAISE NOTICE '   • middle_manager: 3건 (새 요청)';
    RAISE NOTICE '   • raw_material_manager: 1건 (발주 최종승인)';
    RAISE NOTICE '   • consumable_manager: 1건 (구매요청 최종승인)';
    RAISE NOTICE '   • lead buyer: 2건 (구매대기 + 선진행)';
    RAISE NOTICE '   • app_admin: 7건 (모든 알림)';
    RAISE NOTICE '';
    RAISE NOTICE '📧 개인 알림:';
    RAISE NOTICE '   • 김철수: 1건 (승인완료)';
    RAISE NOTICE '   • 이영희: 1건 (승인완료)';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 생성된 발주번호:';
    RAISE NOTICE '   • 발주: %', v_purchase_1;
    RAISE NOTICE '   • 구매요청: %', v_purchase_2;
    RAISE NOTICE '   • 선진행: %', v_purchase_3;
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  참고: 반려 알림은 현재 미구현 상태입니다.';
    
END $$;

-- 테스트 결과 확인 쿼리
RAISE NOTICE '';
RAISE NOTICE '-- 아래 쿼리로 생성된 데이터를 확인할 수 있습니다 --';

SELECT 
    purchase_order_number as "발주번호",
    requester_name as "요청자",
    payment_category as "카테고리",
    progress_type as "진행타입",
    middle_manager_status as "1차승인",
    COALESCE(raw_material_manager_status, consumable_manager_status) as "최종승인",
    created_at as "생성시간"
FROM purchase_requests
WHERE created_at > NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC;
