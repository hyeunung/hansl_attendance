-- ========================================
-- 발주 관련 모든 푸시알림 테스트 스크립트
-- ========================================
-- 테스트 시나리오:
-- 1. 새 구매 요청 → middle_manager + app_admin
-- 2. 1차 승인 (발주) → raw_material_manager + app_admin
-- 3. 1차 승인 (구매요청) → consumable_manager + app_admin
-- 4. 최종 승인 → 요청자 + lead buyer
-- 5. 반려 → 요청자
-- ========================================

DO $$
DECLARE
    v_purchase_1 TEXT; -- 발주 카테고리
    v_purchase_2 TEXT; -- 구매요청 카테고리
    v_purchase_3 TEXT; -- 반려 테스트용
    v_timestamp TEXT;
BEGIN
    -- 타임스탬프 생성
    v_timestamp := TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS');
    v_purchase_1 := 'TEST-RAW-' || v_timestamp;
    v_purchase_2 := 'TEST-BUY-' || v_timestamp;
    v_purchase_3 := 'TEST-REJ-' || v_timestamp;
    
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '🚀 발주 관련 모든 푸시알림 테스트 시작';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 1: 발주 카테고리 (원자재)
    -- ========================================
    RAISE NOTICE '📋 시나리오 1: 발주 카테고리 테스트';
    RAISE NOTICE '----------------------------------------';
    
    -- 1-1. 새 발주 요청 생성
    RAISE NOTICE '1️⃣ 새 발주 요청 생성 (발주번호: %)', v_purchase_1;
    
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
        v_purchase_1,
        '김철수',
        'scott@thefiveforest.com', -- 실제 이메일로 변경
        '발주', -- 원자재 카테고리
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
    (v_purchase_1, '철강재', 100, 50000, 5000000),
    (v_purchase_1, '알루미늄', 50, 30000, 1500000);
    
    RAISE NOTICE '   ✅ 생성 완료 (총액: 6,500,000원)';
    RAISE NOTICE '   📱 알림 발송: middle_manager + app_admin';
    RAISE NOTICE '   💬 "🆕 새 발주 승인 요청"';
    RAISE NOTICE '';
    
    -- 3초 대기
    PERFORM pg_sleep(3);
    
    -- 1-2. 1차 승인 처리
    RAISE NOTICE '2️⃣ 1차 승인 처리 (발주 카테고리)';
    
    UPDATE purchase_requests
    SET 
        middle_manager_status = 'approved',
        middle_manager_approved_at = NOW(),
        middle_manager_comment = '1차 승인 완료'
    WHERE purchase_order_number = v_purchase_1;
    
    RAISE NOTICE '   ✅ 1차 승인 완료';
    RAISE NOTICE '   📱 알림 발송: raw_material_manager + app_admin';
    RAISE NOTICE '   💬 "🔍 최종 발주 승인 요청"';
    RAISE NOTICE '';
    
    -- 3초 대기
    PERFORM pg_sleep(3);
    
    -- 1-3. 최종 승인 처리
    RAISE NOTICE '3️⃣ 최종 승인 처리 (raw_material_manager)';
    
    UPDATE purchase_requests
    SET 
        raw_material_manager_status = 'approved',
        raw_material_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_1;
    
    RAISE NOTICE '   ✅ 최종 승인 완료';
    RAISE NOTICE '   📱 알림 발송: 요청자(김철수)';
    RAISE NOTICE '   💬 "✅ 발주 승인 완료"';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 2: 구매요청 카테고리
    -- ========================================
    RAISE NOTICE '';
    RAISE NOTICE '📋 시나리오 2: 구매요청 카테고리 테스트';
    RAISE NOTICE '----------------------------------------';
    
    -- 2-1. 새 구매 요청 생성
    RAISE NOTICE '1️⃣ 새 구매 요청 생성 (발주번호: %)', v_purchase_2;
    
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
        v_purchase_2,
        '이영희',
        'test2@example.com',
        '구매 요청', -- 구매요청 카테고리
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
    (v_purchase_2, '사무용품', 20, 10000, 200000),
    (v_purchase_2, '프린터 토너', 5, 50000, 250000);
    
    RAISE NOTICE '   ✅ 생성 완료 (총액: 450,000원)';
    RAISE NOTICE '   📱 알림 발송: middle_manager + app_admin';
    RAISE NOTICE '   💬 "🆕 새 발주 승인 요청"';
    RAISE NOTICE '';
    
    -- 3초 대기
    PERFORM pg_sleep(3);
    
    -- 2-2. 1차 승인 처리
    RAISE NOTICE '2️⃣ 1차 승인 처리 (구매요청 카테고리)';
    
    UPDATE purchase_requests
    SET 
        middle_manager_status = 'approved',
        middle_manager_approved_at = NOW(),
        middle_manager_comment = '1차 승인 완료'
    WHERE purchase_order_number = v_purchase_2;
    
    RAISE NOTICE '   ✅ 1차 승인 완료';
    RAISE NOTICE '   📱 알림 발송: consumable_manager + app_admin';
    RAISE NOTICE '   💬 "🔍 최종 발주 승인 요청"';
    RAISE NOTICE '';
    
    -- 3초 대기
    PERFORM pg_sleep(3);
    
    -- 2-3. 최종 승인 처리
    RAISE NOTICE '3️⃣ 최종 승인 처리 (consumable_manager)';
    
    UPDATE purchase_requests
    SET 
        consumable_manager_status = 'approved',
        consumable_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_2;
    
    RAISE NOTICE '   ✅ 최종 승인 완료';
    RAISE NOTICE '   📱 알림 발송:';
    RAISE NOTICE '      - 요청자(이영희): "✅ 발주 승인 완료"';
    RAISE NOTICE '      - lead buyer: "🛒 새로운 구매대기 항목"';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 3: 반려 케이스
    -- ========================================
    RAISE NOTICE '';
    RAISE NOTICE '📋 시나리오 3: 반려 테스트';
    RAISE NOTICE '----------------------------------------';
    
    -- 3-1. 새 구매 요청 생성
    RAISE NOTICE '1️⃣ 새 구매 요청 생성 (발주번호: %)', v_purchase_3;
    
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
        v_purchase_3,
        '박민수',
        'test3@example.com',
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
    (v_purchase_3, '고가 장비', 1, 10000000, 10000000);
    
    RAISE NOTICE '   ✅ 생성 완료 (총액: 10,000,000원)';
    RAISE NOTICE '   📱 알림 발송: middle_manager + app_admin';
    RAISE NOTICE '';
    
    -- 3초 대기
    PERFORM pg_sleep(3);
    
    -- 3-2. 1차 반려 처리
    RAISE NOTICE '2️⃣ 1차 승인자가 반려 처리';
    
    UPDATE purchase_requests
    SET 
        middle_manager_status = 'rejected',
        middle_manager_approved_at = NOW(),
        middle_manager_comment = '예산 초과로 반려'
    WHERE purchase_order_number = v_purchase_3;
    
    RAISE NOTICE '   ✅ 반려 처리 완료';
    RAISE NOTICE '   📱 알림 발송: 요청자(박민수)';
    RAISE NOTICE '   💬 "❌ 발주 반려" (예산 초과로 반려)';
    RAISE NOTICE '';
    
    -- ========================================
    -- 결과 요약
    -- ========================================
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '✨ 테스트 완료!';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📱 예상 알림 수신자:';
    RAISE NOTICE '';
    RAISE NOTICE '1. middle_manager 권한:';
    RAISE NOTICE '   - 새 발주 요청 3건';
    RAISE NOTICE '';
    RAISE NOTICE '2. raw_material_manager 권한:';
    RAISE NOTICE '   - 최종 승인 요청 1건 (발주)';
    RAISE NOTICE '';
    RAISE NOTICE '3. consumable_manager 권한:';
    RAISE NOTICE '   - 최종 승인 요청 1건 (구매요청)';
    RAISE NOTICE '';
    RAISE NOTICE '4. lead buyer 권한:';
    RAISE NOTICE '   - 구매대기 항목 1건';
    RAISE NOTICE '';
    RAISE NOTICE '5. app_admin 권한:';
    RAISE NOTICE '   - 모든 알림 (총 5건)';
    RAISE NOTICE '';
    RAISE NOTICE '6. 요청자들:';
    RAISE NOTICE '   - 김철수: 승인 완료 1건';
    RAISE NOTICE '   - 이영희: 승인 완료 1건';
    RAISE NOTICE '   - 박민수: 반려 1건';
    RAISE NOTICE '';
    RAISE NOTICE '생성된 발주번호:';
    RAISE NOTICE '   - 발주(승인): %', v_purchase_1;
    RAISE NOTICE '   - 구매요청(승인): %', v_purchase_2;
    RAISE NOTICE '   - 구매요청(반려): %', v_purchase_3;
    
END $$;

-- 테스트 데이터 확인
SELECT 
    purchase_order_number,
    requester_name,
    payment_category,
    middle_manager_status,
    raw_material_manager_status,
    consumable_manager_status,
    created_at
FROM purchase_requests
WHERE purchase_order_number LIKE 'TEST-%'
ORDER BY created_at DESC
LIMIT 10;
