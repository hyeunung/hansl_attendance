-- ========================================
-- 한슬 앱 통합 푸시 알림 테스트
-- ========================================
-- 테스트 전 확인사항:
-- 1. scott@thefiveforest.com 계정으로 앱 로그인
-- 2. 알림 권한 허용 확인
-- 3. Supabase SQL Editor에서 실행
-- ========================================

-- 1. 연차 승인 요청 알림 테스트
DO $$
BEGIN
    -- 연차 신청 생성
    INSERT INTO leave_requests (
        user_id,
        email,
        name,
        department,
        type,
        start_date,
        end_date,
        reason,
        status,
        created_at
    ) VALUES (
        (SELECT auth.uid()),
        'scott@thefiveforest.com',
        '김철수',
        '개발팀',
        '연차',
        CURRENT_DATE + INTERVAL '1 day',
        CURRENT_DATE + INTERVAL '1 day',
        '개인 사유',
        'pending',
        NOW()
    );
    
    RAISE NOTICE '✅ 연차 신청 생성 - 승인권자에게 알림 발송됨';
END $$;

-- 2초 대기
SELECT pg_sleep(2);

-- 2. 발주 승인 요청 알림 테스트  
DO $$
DECLARE
    v_po_number TEXT;
BEGIN
    v_po_number := 'TEST-PO-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS');
    
    -- 발주 요청 생성
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
        created_at
    ) VALUES (
        v_po_number,
        '김철수',
        'scott@thefiveforest.com',
        '구매 요청',
        '일반',
        'pending',
        'pending',
        false,
        false,
        NOW()
    );
    
    -- 발주 아이템 추가
    INSERT INTO purchase_request_items (
        purchase_order_number,
        item_name,
        vendor_name,
        quantity,
        unit_price_value,
        amount_value,
        line_number
    ) VALUES 
    (v_po_number, '노트북', 'IT벤더', 1, 2000000, 2000000, 1),
    (v_po_number, '모니터', 'IT벤더', 2, 500000, 1000000, 2);
    
    RAISE NOTICE '✅ 발주 요청 생성 (번호: %) - middle_manager에게 알림 발송됨', v_po_number;
END $$;

-- 2초 대기
SELECT pg_sleep(2);

-- 3. 연차 승인 완료 알림 테스트
UPDATE leave_requests 
SET 
    status = 'approved',
    approved_at = NOW(),
    approver_comment = '승인합니다'
WHERE email = 'scott@thefiveforest.com' 
    AND status = 'pending'
ORDER BY created_at DESC
LIMIT 1;

-- 2초 대기
SELECT pg_sleep(2);

-- 4. 발주 1차 승인 후 최종 승인 요청 알림
UPDATE purchase_requests
SET 
    middle_manager_status = 'approved',
    middle_manager_approved_at = NOW()
WHERE purchase_order_number LIKE 'TEST-PO-%'
    AND middle_manager_status = 'pending'
ORDER BY created_at DESC
LIMIT 1;

-- 2초 대기
SELECT pg_sleep(2);

-- 5. 발주 최종 승인 완료 알림
UPDATE purchase_requests
SET 
    final_manager_status = 'approved',
    final_manager_approved_at = NOW(),
    consumable_manager_status = 'approved',
    consumable_manager_approved_at = NOW()
WHERE purchase_order_number LIKE 'TEST-PO-%'
    AND middle_manager_status = 'approved'
    AND final_manager_status = 'pending'
ORDER BY created_at DESC
LIMIT 1;

-- 결과 확인
SELECT 
    '✅ 테스트 완료!' as status,
    '다음 알림이 발송되었습니다:' as message
UNION ALL
SELECT 
    '1' as status,
    '연차 신청 알림 → 승인권자' as message
UNION ALL
SELECT 
    '2' as status,
    '발주 요청 알림 → middle_manager + app_admin' as message
UNION ALL
SELECT 
    '3' as status,
    '연차 승인 완료 알림 → 신청자' as message
UNION ALL
SELECT 
    '4' as status,
    '발주 1차 승인 후 최종 승인 요청 → final_approver + app_admin' as message
UNION ALL
SELECT 
    '5' as status,
    '발주 최종 승인 완료 → 신청자 + lead buyer' as message;
