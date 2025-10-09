-- 구매 요청이 생성되어 lead_buyer가 처리해야 할 때 알림을 보내는 트리거 함수
CREATE OR REPLACE FUNCTION send_purchase_request_to_lead_buyer_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_notification_title text;
    v_notification_body text;
BEGIN
    -- 구매 요청이면서 결제 미완료이고, 선진행이거나 (일반이면서 최종승인)인 경우
    IF NEW.payment_category = '구매 요청' AND 
       NEW.is_payment_completed = false AND 
       (NEW.progress_type ILIKE '%선진행%' OR 
        (NEW.progress_type ILIKE '%일반%' AND NEW.final_manager_status = 'approved')) THEN
        
        -- 알림 메시지 구성
        v_notification_title := '🛒 새로운 구매대기 항목';
        v_notification_body := format('%s님의 구매 요청(%s)이 구매대기 목록에 추가되었습니다.',
            NEW.requester_name,
            NEW.purchase_order_number
        );

        -- lead_buyer 권한을 가진 사용자들에게 알림 전송 (send_fcm_notification 직접 호출)
        SELECT net.http_post(
            url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification',
            headers := jsonb_build_object(
                'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg',
                'Content-Type', 'application/json'
            )::jsonb,
            body := jsonb_build_object(
                'type', 'custom',
                'title', v_notification_title,
                'body', v_notification_body,
                'data', jsonb_build_object(
                    'type', 'purchase_request',
                    'purchase_order_number', NEW.purchase_order_number,
                    'payment_category', NEW.payment_category,
                    'requester_name', NEW.requester_name
                ),
                'fcm_tokens', (
                    SELECT array_agg(fcm_token)
                    FROM employees
                    WHERE 'lead buyer' = ANY(purchase_role)
                    AND fcm_token IS NOT NULL
                    AND fcm_token != ''
                )
            )::jsonb
        );
        
        -- 알림 내역 저장
        INSERT INTO notifications (user_email, title, body, type, data, is_read, created_at)
        SELECT 
            e.email,
            v_notification_title,
            v_notification_body,
            'purchase_request',
            jsonb_build_object(
                'type', 'purchase_request',
                'purchase_order_number', NEW.purchase_order_number,
                'payment_category', NEW.payment_category,
                'requester_name', NEW.requester_name
            ),
            false,
            NOW()
        FROM employees e
        WHERE 'lead buyer' = ANY(e.purchase_role);

        -- 로그 기록
        RAISE NOTICE 'Lead buyer notification triggered for purchase request %', NEW.purchase_order_number;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 기존 트리거가 있다면 삭제
DROP TRIGGER IF EXISTS purchase_request_lead_buyer_notification_trigger ON purchase_requests;

-- INSERT 시 트리거 생성
CREATE TRIGGER purchase_request_lead_buyer_notification_trigger
AFTER INSERT ON purchase_requests
FOR EACH ROW
EXECUTE FUNCTION send_purchase_request_to_lead_buyer_notification();

-- UPDATE 시 트리거 생성 (final_manager_status가 approved로 변경될 때)
CREATE TRIGGER purchase_request_lead_buyer_notification_update_trigger
AFTER UPDATE ON purchase_requests
FOR EACH ROW
WHEN (OLD.final_manager_status IS DISTINCT FROM NEW.final_manager_status 
      AND NEW.final_manager_status = 'approved'
      AND NEW.payment_category = '구매 요청'
      AND NEW.is_payment_completed = false
      AND NEW.progress_type ILIKE '%일반%')
EXECUTE FUNCTION send_purchase_request_to_lead_buyer_notification();

-- 트리거 활성화
ALTER TABLE purchase_requests ENABLE TRIGGER purchase_request_lead_buyer_notification_trigger;
ALTER TABLE purchase_requests ENABLE TRIGGER purchase_request_lead_buyer_notification_update_trigger;
