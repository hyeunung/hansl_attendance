-- 새 발주 요청 알림 트리거
CREATE OR REPLACE FUNCTION notify_new_purchase_request()
RETURNS TRIGGER AS $$
DECLARE
  v_total_amount numeric;
  v_requester_name text;
  v_payment_category text;
  v_fcm_token text;
  v_user record;
BEGIN
  -- 새 발주 요청이 생성될 때만 실행 (middle_manager_status가 'pending'인 경우)
  IF TG_OP = 'INSERT' AND NEW.middle_manager_status = 'pending' THEN
    -- 발주 정보 가져오기
    v_requester_name := NEW.requester_name;
    v_payment_category := NEW.payment_category;
    
    -- 해당 발주번호의 총 금액 계산
    SELECT COALESCE(SUM(amount_value), 0) INTO v_total_amount
    FROM purchase_request_items
    WHERE purchase_order_number = NEW.purchase_order_number;
    
    -- middle_manager 역할을 가진 사용자들에게 알림
    FOR v_user IN 
      SELECT fcm_token, name, email
      FROM employees
      WHERE 'middle_manager' = ANY(purchase_role)
        AND fcm_token IS NOT NULL
        AND fcm_token != ''
    LOOP
      -- Edge Function 호출하여 FCM 알림 전송
      PERFORM net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/send-push-notification',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key'),
          'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
          'token', v_user.fcm_token,
          'title', '🆕 새 발주 승인 요청',
          'body', format('%s님이 %s 발주(%s)를 요청했습니다. 금액: %s원',
            v_requester_name, 
            v_payment_category,
            NEW.purchase_order_number,
            to_char(v_total_amount, 'FM999,999,999')
          ),
          'data', jsonb_build_object(
            'type', 'new_purchase_request',
            'purchase_order_number', NEW.purchase_order_number,
            'requester_name', v_requester_name,
            'payment_category', v_payment_category
          )
        )::jsonb
      );
    END LOOP;
    
    -- app_admin 역할을 가진 사용자들에게도 알림
    FOR v_user IN 
      SELECT fcm_token, name, email
      FROM employees
      WHERE 'app_admin' = ANY(purchase_role)
        AND fcm_token IS NOT NULL
        AND fcm_token != ''
    LOOP
      -- Edge Function 호출하여 FCM 알림 전송
      PERFORM net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/send-push-notification',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key'),
          'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
          'token', v_user.fcm_token,
          'title', '🆕 새 발주 승인 요청',
          'body', format('%s님이 %s 발주(%s)를 요청했습니다. 금액: %s원',
            v_requester_name, 
            v_payment_category,
            NEW.purchase_order_number,
            to_char(v_total_amount, 'FM999,999,999')
          ),
          'data', jsonb_build_object(
            'type', 'new_purchase_request',
            'purchase_order_number', NEW.purchase_order_number,
            'requester_name', v_requester_name,
            'payment_category', v_payment_category
          )
        )::jsonb
      );
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 생성
DROP TRIGGER IF EXISTS trigger_notify_new_purchase_request ON purchase_requests;
CREATE TRIGGER trigger_notify_new_purchase_request
  AFTER INSERT ON purchase_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_purchase_request();

-- 권한 설정
GRANT EXECUTE ON FUNCTION notify_new_purchase_request() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_new_purchase_request() TO service_role;

COMMENT ON FUNCTION notify_new_purchase_request() IS '새 발주 요청 시 1차 승인자들에게 알림을 전송하는 함수';
COMMENT ON TRIGGER trigger_notify_new_purchase_request ON purchase_requests IS '새 발주 요청 생성 시 알림 트리거';