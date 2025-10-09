-- ============================================================================
-- 구매/발주 알림 시스템 최종 정리
-- 작성일: 2025-10-02
-- 
-- 목적:
--   1. 중복 트리거 제거
--   2. 통합된 알림 시스템 구축
--   3. Edge Function과의 타입 일치
-- ============================================================================

-- STEP 1: 기존 중복 트리거 제거
DROP TRIGGER IF EXISTS purchase_request_lead_buyer_notification_trigger ON purchase_requests;
DROP TRIGGER IF EXISTS purchase_request_lead_buyer_notification_update_trigger ON purchase_requests;
DROP TRIGGER IF EXISTS trigger_notify_new_purchase_request ON purchase_requests;
DROP TRIGGER IF EXISTS trigger_notify_purchase_status ON purchase_requests;

-- STEP 2: 기존 중복 함수 제거  
DROP FUNCTION IF EXISTS send_purchase_request_to_lead_buyer_notification();
DROP FUNCTION IF EXISTS notify_new_purchase_request();
DROP FUNCTION IF EXISTS notify_purchase_status_change();

-- STEP 3: 구매 요청 알림 트리거 함수 확인 및 재생성
-- (기존 함수가 Edge Function과 올바르게 통신하는지 확인)
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
    
    -- Edge Function 호출 (타입이 purchase_request로 올바르게 설정됨)
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'purchase_request',  -- Edge Function이 인식하는 타입
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

-- STEP 4: 구매 상태 변경 알림 트리거 함수
CREATE OR REPLACE FUNCTION send_purchase_status_notification()
RETURNS TRIGGER AS $$
DECLARE
    anon_key TEXT;
    supabase_url TEXT;
    notification_sent BOOLEAN;
BEGIN
    -- 상태가 실제로 변경되었는지 확인
    IF OLD.final_manager_status = NEW.final_manager_status 
       AND OLD.middle_manager_status = NEW.middle_manager_status THEN
        RETURN NEW;
    END IF;
    
    -- 중복 방지 체크
    SELECT EXISTS(
        SELECT 1 FROM notifications 
        WHERE type LIKE 'purchase_%'
        AND data->>'purchase_order_number' = NEW.purchase_order_number
        AND created_at > NOW() - INTERVAL '10 seconds'
    ) INTO notification_sent;
    
    IF notification_sent THEN
        RAISE NOTICE 'Purchase status notification already sent for: %', NEW.purchase_order_number;
        RETURN NEW;
    END IF;
    
    -- app_settings에서 필요한 값 가져오기
    SELECT value INTO anon_key FROM app_settings WHERE key = 'supabase_anon_key';
    SELECT value INTO supabase_url FROM app_settings WHERE key = 'supabase_url';
    
    IF anon_key IS NULL OR supabase_url IS NULL THEN
        RAISE NOTICE 'Missing app settings for notification';
        RETURN NEW;
    END IF;
    
    -- Edge Function 호출 (타입이 purchase_status_change로 올바르게 설정됨)
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'purchase_status_change',  -- Edge Function이 인식하는 타입
            'purchase_order_number', NEW.purchase_order_number,
            'requester_name', NEW.requester_name,
            'vendor_name', NEW.vendor_name,
            'status', NEW.final_manager_status,
            'middle_manager_status', NEW.middle_manager_status,
            'payment_category', NEW.payment_category,
            'skip_db_notification', false  -- DB에 알림 저장 활성화
        )
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in send_purchase_status_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 5: 트리거 재생성 (활성화 상태 확인)
DROP TRIGGER IF EXISTS purchase_request_notification ON purchase_requests;
CREATE TRIGGER purchase_request_notification
  AFTER INSERT ON purchase_requests
  FOR EACH ROW
  EXECUTE FUNCTION send_purchase_request_notification();

DROP TRIGGER IF EXISTS purchase_status_notification ON purchase_requests;
CREATE TRIGGER purchase_status_notification
  AFTER UPDATE ON purchase_requests
  FOR EACH ROW
  EXECUTE FUNCTION send_purchase_status_notification();

-- STEP 6: 트리거 활성화 확인
ALTER TABLE purchase_requests ENABLE TRIGGER purchase_request_notification;
ALTER TABLE purchase_requests ENABLE TRIGGER purchase_status_notification;

-- STEP 7: 정리 완료 메시지
DO $$
BEGIN
  RAISE NOTICE '✅ 구매/발주 알림 시스템 정리 완료';
  RAISE NOTICE '  - 중복 트리거 제거됨';
  RAISE NOTICE '  - Edge Function 타입 매칭 확인됨';
  RAISE NOTICE '  - 알림 시스템 통합 완료';
END $$;