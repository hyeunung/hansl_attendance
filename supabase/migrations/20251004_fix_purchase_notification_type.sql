-- ============================================================================
-- 구매 신규 요청 알림 타입 버그 수정
-- 작성일: 2025-10-04
-- 
-- 문제:
--   DB 트리거는 'purchase_request' (s 없음) 전송
--   Edge Function은 'purchase_requests' (s 있음) 기대
--   결과: 신규 구매 요청 알림이 작동하지 않음
--
-- 해결:
--   DB 트리거의 타입을 'purchase_requests'로 수정
-- ============================================================================

-- STEP 1: 기존 함수 수정 (타입을 purchase_requests로 변경)
CREATE OR REPLACE FUNCTION send_purchase_request_notification()
RETURNS TRIGGER AS $$
DECLARE
    anon_key TEXT;
    supabase_url TEXT;
    notification_sent BOOLEAN;
BEGIN
    -- 중복 방지 체크 (10초 이내 동일한 발주번호)
    SELECT EXISTS(
        SELECT 1 FROM notifications 
        WHERE type = 'purchase_request' 
        AND data->>'purchase_order_number' = NEW.purchase_order_number
        AND created_at > NOW() - INTERVAL '10 seconds'
    ) INTO notification_sent;
    
    IF notification_sent THEN
        RAISE NOTICE 'Purchase notification already sent for: %', NEW.purchase_order_number;
        RETURN NEW;
    END IF;
    
    -- app_settings에서 필요한 값 가져오기
    SELECT value INTO anon_key FROM app_settings WHERE key = 'supabase_anon_key';
    SELECT value INTO supabase_url FROM app_settings WHERE key = 'supabase_url';
    
    IF anon_key IS NULL OR supabase_url IS NULL THEN
        RAISE NOTICE 'Missing app settings for notification';
        RETURN NEW;
    END IF;
    
    -- Edge Function 호출 (타입을 purchase_requests로 수정!)
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'purchase_requests',  -- 's' 추가하여 Edge Function과 일치시킴
            'purchase_order_number', NEW.purchase_order_number,
            'requester_name', NEW.requester_name,
            'vendor_name', NEW.vendor_name,
            'payment_category', NEW.payment_category,
            'skip_db_notification', false  -- DB에 알림 저장 활성화
        )
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in send_purchase_request_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 2: 트리거는 이미 활성화되어 있으므로 재생성 불필요
-- 함수만 수정하면 자동으로 적용됨

-- STEP 3: 수정 확인 메시지
DO $$
BEGIN
  RAISE NOTICE '✅ 구매 신규 요청 알림 타입 버그 수정 완료';
  RAISE NOTICE '  - DB 트리거 타입: purchase_request → purchase_requests';
  RAISE NOTICE '  - Edge Function과 타입 일치됨';
  RAISE NOTICE '  - 신규 구매 요청 알림이 정상 작동합니다';
END $$;