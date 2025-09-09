-- 발주/구매 알림 시스템 통합 수정
-- 1. Edge Function 경로 수정
-- 2. 최종 승인자 알림 추가
-- 3. 승인 완료 알림 추가

-- 통합 발주 알림 함수 (신규 요청, 1차 승인 완료, 최종 승인 완료)
CREATE OR REPLACE FUNCTION notify_purchase_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_total_amount numeric;
  v_requester_name text;
  v_payment_category text;
  v_target_roles text[];
  v_notification_title text;
  v_notification_body text;
  v_notification_type text;
  v_user record;
BEGIN
  -- 발주 정보 가져오기
  v_requester_name := NEW.requester_name;
  v_payment_category := NEW.payment_category;
  
  -- 총 금액 계산
  SELECT COALESCE(SUM(amount_value), 0) INTO v_total_amount
  FROM purchase_request_items
  WHERE purchase_order_number = NEW.purchase_order_number;

  -- 상태별 알림 대상 및 내용 설정
  -- Case 1: 신규 발주 요청 (INSERT 시)
  IF TG_OP = 'INSERT' AND NEW.middle_manager_status = 'pending' THEN
    v_target_roles := ARRAY['middle_manager'];
    v_notification_title := '🆕 새 발주 승인 요청';
    v_notification_body := format('%s님이 %s 발주(%s)를 요청했습니다. 금액: %s원',
      v_requester_name, 
      v_payment_category,
      NEW.purchase_order_number,
      to_char(v_total_amount, 'FM999,999,999')
    );
    v_notification_type := 'new_purchase_request';
    
  -- Case 2: 1차 승인 완료 → 최종 승인자에게 알림 (UPDATE 시)
  ELSIF TG_OP = 'UPDATE' AND 
        NEW.middle_manager_status = 'approved' AND 
        OLD.middle_manager_status = 'pending' THEN
    -- payment_category에 따라 대상 역할 결정
    IF v_payment_category = '원자재' THEN
      v_target_roles := ARRAY['raw_material_manager'];
    ELSE
      v_target_roles := ARRAY['consumable_manager'];
    END IF;
    
    v_notification_title := '🔔 최종 승인 요청';
    v_notification_body := format('%s님의 %s %s(%s) 최종 승인이 필요합니다. 금액: %s원',
      v_requester_name,
      v_payment_category,
      CASE WHEN v_payment_category = '원자재' THEN '발주' ELSE '구매' END,
      NEW.purchase_order_number,
      to_char(v_total_amount, 'FM999,999,999')
    );
    v_notification_type := 'final_approval_request';
    
  -- Case 3: 최종 승인 완료 → 신청자에게 알림 (UPDATE 시)
  ELSIF TG_OP = 'UPDATE' AND 
        ((NEW.raw_material_manager_status = 'approved' AND OLD.raw_material_manager_status = 'pending') OR
         (NEW.consumable_manager_status = 'approved' AND OLD.consumable_manager_status = 'pending')) THEN
    
    -- 신청자의 FCM 토큰 조회 후 개별 알림 전송
    SELECT fcm_token INTO v_user.fcm_token
    FROM employees
    WHERE email = NEW.requester_email
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    IF v_user.fcm_token IS NOT NULL THEN
      PERFORM net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
        ),
        body := jsonb_build_object(
          'type', 'user',
          'title', '✅ 발주/구매 승인 완료',
          'body', format('요청하신 %s %s(%s)가 최종 승인되었습니다.',
            v_payment_category,
            CASE WHEN v_payment_category = '원자재' THEN '발주' ELSE '구매' END,
            NEW.purchase_order_number
          ),
          'data', jsonb_build_object(
            'type', 'purchase_approved',
            'purchase_order_number', NEW.purchase_order_number,
            'payment_category', v_payment_category
          ),
          'user_email', NEW.requester_email,  -- 연차/출장과 동일하게 user_email 사용
          'fcm_tokens', ARRAY[v_user.fcm_token]
        )::jsonb
      );
    END IF;
    
    RETURN NEW; -- 신청자 알림 후 종료
  ELSE
    -- 알림이 필요없는 경우
    RETURN NEW;
  END IF;

  -- 대상 역할의 사용자들에게 알림 전송
  FOR v_user IN 
    SELECT fcm_token, name, email
    FROM employees
    WHERE purchase_role && v_target_roles  -- 배열 교집합 연산자
      AND fcm_token IS NOT NULL
      AND fcm_token != ''
  LOOP
    -- send_fcm_notification Edge Function 호출 (연차/출장과 동일한 구조)
    PERFORM net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
      ),
      body := jsonb_build_object(
        'type', 'admin',
        'title', v_notification_title,
        'body', v_notification_body,
        'data', jsonb_build_object(
          'type', v_notification_type,
          'purchase_order_number', NEW.purchase_order_number,
          'requester_name', v_requester_name,
          'payment_category', v_payment_category
        ),
        'requester_email', NEW.requester_email,
        'requester_department', v_payment_category  -- 부서 대신 카테고리 사용
      )::jsonb
    );
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 기존 트리거 삭제
DROP TRIGGER IF EXISTS trigger_notify_new_purchase_request ON purchase_requests;
DROP FUNCTION IF EXISTS notify_new_purchase_request();

-- 새로운 통합 트리거 생성
DROP TRIGGER IF EXISTS trigger_notify_purchase_status ON purchase_requests;
CREATE TRIGGER trigger_notify_purchase_status
  AFTER INSERT OR UPDATE ON purchase_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_purchase_status_change();

-- 권한 설정
GRANT EXECUTE ON FUNCTION notify_purchase_status_change() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_purchase_status_change() TO service_role;

-- 코멘트 추가
COMMENT ON FUNCTION notify_purchase_status_change() IS '발주/구매 요청의 상태 변경 시 관련자들에게 알림을 전송하는 통합 함수';
COMMENT ON TRIGGER trigger_notify_purchase_status ON purchase_requests IS '발주/구매 상태 변경 통합 알림 트리거';