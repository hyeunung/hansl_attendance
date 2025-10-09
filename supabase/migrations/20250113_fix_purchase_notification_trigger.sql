-- 기존 023번 트리거를 수정하여 제대로 작동하도록 함
CREATE OR REPLACE FUNCTION notify_new_purchase_request()
RETURNS TRIGGER AS $$
DECLARE
  v_total_amount numeric;
  v_notification_title text;
  v_notification_body text;
BEGIN
  -- 새 발주 요청이 생성될 때만 실행 (middle_manager_status가 'pending'인 경우)
  IF TG_OP = 'INSERT' AND NEW.middle_manager_status = 'pending' THEN
    -- 해당 발주번호의 총 금액 계산
    SELECT COALESCE(SUM(amount_value), 0) INTO v_total_amount
    FROM purchase_request_items
    WHERE purchase_order_number = NEW.purchase_order_number;
    
    -- 알림 메시지 구성
    v_notification_title := '🆕 새 발주 승인 요청';
    v_notification_body := format('%s님이 %s 발주(%s)를 요청했습니다. 금액: %s원',
      NEW.requester_name,
      NEW.payment_category,
      NEW.purchase_order_number,
      TO_CHAR(v_total_amount, 'FM999,999,999')
    );

    -- middle_manager와 app_admin에게 알림 전송 (send_fcm_notification 직접 호출)
    SELECT net.http_post(
      url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg',
        'Content-Type', 'application/json'
      )::jsonb,
      body := jsonb_build_object(
        'type', 'admin',
        'title', v_notification_title,
        'body', v_notification_body,
        'data', jsonb_build_object(
          'type', 'purchase_approval',
          'purchase_order_number', NEW.purchase_order_number,
          'payment_category', NEW.payment_category,
          'requester_name', NEW.requester_name,
          'total_amount', v_total_amount
        ),
        'requester_department', '',
        'requester_email', '',
        'is_manager_request', false
      )::jsonb
    );
    
    -- 알림 내역 저장 (notifications 테이블에)
    INSERT INTO notifications (user_email, title, body, type, data, is_read, created_at)
    SELECT 
      e.email,
      v_notification_title,
      v_notification_body,
      'purchase_approval',
      jsonb_build_object(
        'type', 'purchase_approval',
        'purchase_order_number', NEW.purchase_order_number,
        'payment_category', NEW.payment_category,
        'requester_name', NEW.requester_name,
        'total_amount', v_total_amount
      ),
      false,
      NOW()
    FROM employees e
    WHERE ('middle_manager' = ANY(e.purchase_role) OR 'app_admin' = ANY(e.purchase_role))
      AND e.fcm_token IS NOT NULL
      AND e.fcm_token != '';

    -- 로그 기록
    RAISE NOTICE 'Purchase notification created for order %', NEW.purchase_order_number;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 기존 트리거는 그대로 사용 (이미 존재함)
-- DROP TRIGGER IF EXISTS trigger_notify_new_purchase_request ON purchase_requests;
-- CREATE TRIGGER trigger_notify_new_purchase_request
--   AFTER INSERT ON purchase_requests
--   FOR EACH ROW
--   EXECUTE FUNCTION notify_new_purchase_request();
