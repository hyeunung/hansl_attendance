-- ================================================
-- 발주 관련 모든 푸시알림 테스트 (반려 포함)
-- ================================================
-- 테스트 시나리오:
-- 1. 새 구매 요청 → middle_manager + app_admin
-- 2. 1차 승인 (발주) → raw_material_manager + app_admin
-- 3. 1차 승인 (구매요청) → consumable_manager + app_admin
-- 4. 최종 승인 → 요청자 + lead buyer
-- 5. 반려 → 요청자 (※ 반려 마이그레이션 적용 필요)
-- ================================================

DO $$
DECLARE
    v_purchase_1 TEXT; -- 발주 카테고리 (승인)
    v_purchase_2 TEXT; -- 구매요청 카테고리 (승인)
    v_purchase_3 TEXT; -- 선진행 테스트
    v_purchase_4 TEXT; -- 1차 반려 테스트
    v_purchase_5 TEXT; -- 최종 반려 테스트
    v_timestamp TEXT;
BEGIN
    -- 타임스탬프 생성
    v_timestamp := TO_CHAR(NOW(), 'MMDDHHMMSS');
    v_purchase_1 := 'P1-' || v_timestamp;
    v_purchase_2 := 'P2-' || v_timestamp;
    v_purchase_3 := 'P3-' || v_timestamp;
    v_purchase_4 := 'P4-' || v_timestamp;
    v_purchase_5 := 'P5-' || v_timestamp;
    
    RAISE NOTICE '';
    RAISE NOTICE '🚀 발주 관련 모든 푸시알림 완전 테스트!';
    RAISE NOTICE '================================================';
    RAISE NOTICE '⚠️  반려 알림은 20250202_add_purchase_rejection_notification.sql';
    RAISE NOTICE '   마이그레이션 적용 후 작동합니다.';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 1: 발주 카테고리 → 승인
    -- ========================================
    RAISE NOTICE '📋 시나리오 1: 발주(원자재) → 최종 승인';
    RAISE NOTICE '----------------------------------------';
    
    INSERT INTO purchase_requests (
        purchase_order_number, requester_name, requester_email,
        payment_category, progress_type, middle_manager_status, is_payment_completed
    ) VALUES (
        v_purchase_1, '김철수', 'scott@thefiveforest.com',
        '발주', '일반', 'pending', false
    );
    
    INSERT INTO purchase_request_items (
        purchase_order_number, item_name, quantity, unit_price_value, amount_value
    ) VALUES (v_purchase_1, '철강재', 100, 50000, 5000000);
    
    RAISE NOTICE '✅ 생성: %s', v_purchase_1;
    RAISE NOTICE '📱 → middle_manager, app_admin: "🆕 새 발주 승인 요청"';
    PERFORM pg_sleep(3);
    
    UPDATE purchase_requests
    SET middle_manager_status = 'approved', middle_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_1;
    
    RAISE NOTICE '✅ 1차 승인 완료';
    RAISE NOTICE '📱 → raw_material_manager, app_admin: "🔍 최종 발주 승인 요청"';
    PERFORM pg_sleep(3);
    
    UPDATE purchase_requests
    SET raw_material_manager_status = 'approved', raw_material_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_1;
    
    RAISE NOTICE '✅ 최종 승인 완료';
    RAISE NOTICE '📱 → 김철수: "✅ 발주 승인 완료"';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 2: 구매요청 → 승인
    -- ========================================
    PERFORM pg_sleep(2);
    RAISE NOTICE '📋 시나리오 2: 구매요청 → 최종 승인';
    RAISE NOTICE '----------------------------------------';
    
    INSERT INTO purchase_requests (
        purchase_order_number, requester_name, requester_email,
        payment_category, progress_type, middle_manager_status, is_payment_completed
    ) VALUES (
        v_purchase_2, '이영희', 'test@example.com',
        '구매 요청', '일반', 'pending', false
    );
    
    INSERT INTO purchase_request_items (
        purchase_order_number, item_name, quantity, unit_price_value, amount_value
    ) VALUES (v_purchase_2, '사무용품', 20, 10000, 200000);
    
    RAISE NOTICE '✅ 생성: %s', v_purchase_2;
    RAISE NOTICE '📱 → middle_manager, app_admin: "🆕 새 발주 승인 요청"';
    PERFORM pg_sleep(3);
    
    UPDATE purchase_requests
    SET middle_manager_status = 'approved', middle_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_2;
    
    RAISE NOTICE '✅ 1차 승인 완료';
    RAISE NOTICE '📱 → consumable_manager, app_admin: "🔍 최종 발주 승인 요청"';
    PERFORM pg_sleep(3);
    
    UPDATE purchase_requests
    SET consumable_manager_status = 'approved', consumable_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_2;
    
    RAISE NOTICE '✅ 최종 승인 완료';
    RAISE NOTICE '📱 → 이영희: "✅ 발주 승인 완료"';
    RAISE NOTICE '📱 → lead buyer: "🛒 새로운 구매대기 항목"';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 3: 선진행 구매요청
    -- ========================================
    PERFORM pg_sleep(2);
    RAISE NOTICE '📋 시나리오 3: 선진행 구매요청';
    RAISE NOTICE '----------------------------------------';
    
    INSERT INTO purchase_requests (
        purchase_order_number, requester_name, requester_email,
        payment_category, progress_type, middle_manager_status, is_payment_completed
    ) VALUES (
        v_purchase_3, '박민수', 'test2@example.com',
        '구매 요청', '선진행', 'pending', false
    );
    
    INSERT INTO purchase_request_items (
        purchase_order_number, item_name, quantity, unit_price_value, amount_value
    ) VALUES (v_purchase_3, '긴급 부품', 1, 1000000, 1000000);
    
    RAISE NOTICE '✅ 생성: %s', v_purchase_3;
    RAISE NOTICE '📱 → middle_manager, app_admin: "🆕 [선진행] 새 발주 승인 요청"';
    RAISE NOTICE '📱 → lead buyer, app_admin: "🛒 [선진행] 새로운 구매대기 항목"';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 4: 1차 반려
    -- ========================================
    PERFORM pg_sleep(2);
    RAISE NOTICE '📋 시나리오 4: 1차 승인에서 반려';
    RAISE NOTICE '----------------------------------------';
    
    INSERT INTO purchase_requests (
        purchase_order_number, requester_name, requester_email,
        payment_category, progress_type, middle_manager_status, is_payment_completed
    ) VALUES (
        v_purchase_4, '최민정', 'test3@example.com',
        '구매 요청', '일반', 'pending', false
    );
    
    INSERT INTO purchase_request_items (
        purchase_order_number, item_name, quantity, unit_price_value, amount_value
    ) VALUES (v_purchase_4, '고가 장비', 1, 10000000, 10000000);
    
    RAISE NOTICE '✅ 생성: %s', v_purchase_4;
    RAISE NOTICE '📱 → middle_manager, app_admin: "🆕 새 발주 승인 요청"';
    PERFORM pg_sleep(3);
    
    UPDATE purchase_requests
    SET 
        middle_manager_status = 'rejected',
        middle_manager_comment = '예산 초과로 인한 반려',
        middle_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_4;
    
    RAISE NOTICE '❌ 1차 반려 처리';
    RAISE NOTICE '📱 → 최민정: "❌ 발주 반려" (예산 초과로 인한 반려)';
    RAISE NOTICE '';
    
    -- ========================================
    -- 시나리오 5: 최종 단계에서 반려
    -- ========================================
    PERFORM pg_sleep(2);
    RAISE NOTICE '📋 시나리오 5: 최종 승인에서 반려';
    RAISE NOTICE '----------------------------------------';
    
    INSERT INTO purchase_requests (
        purchase_order_number, requester_name, requester_email,
        payment_category, progress_type, middle_manager_status, is_payment_completed
    ) VALUES (
        v_purchase_5, '정수진', 'test4@example.com',
        '구매 요청', '일반', 'pending', false
    );
    
    INSERT INTO purchase_request_items (
        purchase_order_number, item_name, quantity, unit_price_value, amount_value
    ) VALUES (v_purchase_5, '특수 장비', 2, 3000000, 6000000);
    
    RAISE NOTICE '✅ 생성: %s', v_purchase_5;
    RAISE NOTICE '📱 → middle_manager, app_admin: "🆕 새 발주 승인 요청"';
    PERFORM pg_sleep(3);
    
    UPDATE purchase_requests
    SET middle_manager_status = 'approved', middle_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_5;
    
    RAISE NOTICE '✅ 1차 승인 완료';
    RAISE NOTICE '📱 → consumable_manager, app_admin: "🔍 최종 발주 승인 요청"';
    PERFORM pg_sleep(3);
    
    UPDATE purchase_requests
    SET 
        consumable_manager_status = 'rejected',
        consumable_manager_rejection_reason = '대체 제품 구매 권장',
        consumable_manager_approved_at = NOW()
    WHERE purchase_order_number = v_purchase_5;
    
    RAISE NOTICE '❌ 최종 반려 처리';
    RAISE NOTICE '📱 → 정수진: "❌ 발주 최종 반려" (대체 제품 구매 권장)';
    RAISE NOTICE '';
    
    -- ========================================
    -- 결과 요약
    -- ========================================
    RAISE NOTICE '================================================';
    RAISE NOTICE '✨ 테스트 완료! 예상 알림 수:';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    RAISE NOTICE '👤 역할별:';
    RAISE NOTICE '   • middle_manager: 5건 (새 요청)';
    RAISE NOTICE '   • raw_material_manager: 1건 (발주 최종승인)';
    RAISE NOTICE '   • consumable_manager: 2건 (구매요청 최종승인)';
    RAISE NOTICE '   • lead buyer: 2건 (구매대기 + 선진행)';
    RAISE NOTICE '   • app_admin: 10건 (모든 알림)';
    RAISE NOTICE '';
    RAISE NOTICE '📧 개인별:';
    RAISE NOTICE '   • 김철수: 1건 (승인완료)';
    RAISE NOTICE '   • 이영희: 1건 (승인완료)';
    RAISE NOTICE '   • 최민정: 1건 (1차 반려) ⚠️';
    RAISE NOTICE '   • 정수진: 1건 (최종 반려) ⚠️';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 발주번호:';
    RAISE NOTICE '   %s (발주-승인)', v_purchase_1;
    RAISE NOTICE '   %s (구매요청-승인)', v_purchase_2;
    RAISE NOTICE '   %s (선진행)', v_purchase_3;
    RAISE NOTICE '   %s (1차 반려) ⚠️', v_purchase_4;
    RAISE NOTICE '   %s (최종 반려) ⚠️', v_purchase_5;
    
END $$;

-- 생성된 데이터 확인
SELECT 
    purchase_order_number as "발주번호",
    requester_name as "요청자",
    payment_category as "카테고리",
    progress_type as "타입",
    middle_manager_status as "1차",
    COALESCE(
        raw_material_manager_status,
        consumable_manager_status,
        final_manager_status
    ) as "최종",
    CASE 
        WHEN middle_manager_status = 'rejected' THEN middle_manager_comment
        WHEN raw_material_manager_status = 'rejected' THEN raw_material_manager_rejection_reason
        WHEN consumable_manager_status = 'rejected' THEN consumable_manager_rejection_reason
        ELSE NULL
    END as "반려사유",
    TO_CHAR(created_at, 'HH24:MI:SS') as "생성시간"
FROM purchase_requests
WHERE purchase_order_number LIKE 'P_-%'
  AND created_at > NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC;
