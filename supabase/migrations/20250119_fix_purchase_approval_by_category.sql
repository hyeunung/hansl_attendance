-- 1차 승인 완료 시 payment_category에 따라 다른 최종 승인자에게 알림 전송
-- 발주 → raw_material_manager
-- 구매 요청 → consumable_manager
-- 현장 결제 → final_manager

-- 기존 트리거 삭제
DROP TRIGGER IF EXISTS trigger_notify_purchase_status ON purchase_requests;
DROP FUNCTION IF EXISTS notify_purchase_status_change() CASCADE;

-- 수정된 알림 함수 생성
CREATE OR REPLACE FUNCTION notify_purchase_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_total_amount numeric;
  v_requester_name text;
  v_requester_email text;
  v_payment_category text;
  v_target_roles text[];
  v_notification_title text;
  v_notification_body text;
  v_notification_type text;
  v_user record;
  v_fcm_tokens text[];
  v_anon_key text;
  v_supabase_url text;
BEGIN
  -- 발주 정보 가져오기
  v_requester_name := NEW.requester_name;
  v_payment_category := NEW.payment_category;
  
  -- app_settings에서 설정값 가져오기
  SELECT value INTO v_anon_key FROM app_settings WHERE key = 'supabase_anon_key';
  SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
  
  -- requester_name으로 이메일 조회
  SELECT email INTO v_requester_email
  FROM employees
  WHERE name = NEW.requester_name
  LIMIT 1;
  
  -- 총 금액 계산
  SELECT COALESCE(SUM(amount_value), 0) INTO v_total_amount
  FROM purchase_request_items
  WHERE purchase_order_number = NEW.purchase_order_number;

  -- Case 1: 신규 발주 요청 (INSERT 시) - 1차 승인자에게
  IF TG_OP = 'INSERT' AND NEW.middle_manager_status = 'pending' THEN
    v_target_roles := ARRAY['middle_manager'];
    v_notification_title := '🆕 새 발주 승인 요청';
    v_notification_body := format('%s님이 %s 발주(%s)를 요청했습니다. 금액: %s원',
      v_requester_name, 
      v_payment_category,
      NEW.purchase_order_number,
      to_char(v_total_amount, 'FM999,999,999')
    );
    v_notification_type := 'purchase_request';
    
  -- Case 2: 1차 승인 완료 -> payment_category에 따른 최종 승인자에게
  ELSIF TG_OP = 'UPDATE' AND 
        NEW.middle_manager_status = 'approved' AND 
        OLD.middle_manager_status IN ('pending', NULL) THEN
    
    -- payment_category에 따라 다른 역할 지정
    IF v_payment_category = '발주' THEN
      v_target_roles := ARRAY['raw_material_manager', 'app_admin'];
      NEW.raw_material_manager_status := 'pending';
    ELSIF v_payment_category IN ('구매 요청', '구매요청') THEN
      v_target_roles := ARRAY['consumable_manager', 'app_admin'];
      NEW.consumable_manager_status := 'pending';
    ELSE
      v_target_roles := ARRAY['final_manager', 'app_admin'];
      NEW.final_manager_status := 'pending';
    END IF;
    
    v_notification_title := '🔍 최종 발주 승인 요청';
    v_notification_body := format('%s님의 %s(%s)가 1차 승인되었습니다. 최종 승인이 필요합니다.',
      v_requester_name,
      v_payment_category,
      NEW.purchase_order_number
    );
    v_notification_type := 'purchase_final_approval';
    
  -- Case 3: 최종 승인 완료 (각 담당자별)
  ELSIF TG_OP = 'UPDATE' AND 
        ((NEW.raw_material_manager_status = 'approved' AND OLD.raw_material_manager_status = 'pending') OR
         (NEW.consumable_manager_status = 'approved' AND OLD.consumable_manager_status = 'pending') OR
         (NEW.final_manager_status = 'approved' AND OLD.final_manager_status IN ('pending', NULL))) THEN
    
    -- 3-1: 신청자에게 승인 완료 알림
    IF v_requester_email IS NOT NULL THEN
      SELECT fcm_token INTO v_user.fcm_token
      FROM employees
      WHERE email = v_requester_email
        AND fcm_token IS NOT NULL
        AND fcm_token != '';
      
      IF v_user.fcm_token IS NOT NULL THEN
        PERFORM net.http_post(
          url := v_supabase_url || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_anon_key,
            'Content-Type', 'application/json'
          )::jsonb,
          body := jsonb_build_object(
            'type', 'custom',
            'title', '✅ 발주 승인 완료',
            'body', format('발주 요청(%s)이 최종 승인되었습니다.', NEW.purchase_order_number),
            'data', jsonb_build_object(
              'type', 'purchase_approved',
              'purchase_order_number', NEW.purchase_order_number,
              'payment_category', v_payment_category
            ),
            'user_email', v_requester_email,
            'fcm_tokens', ARRAY[v_user.fcm_token],
            'skip_db_notification', true
          )::jsonb
        );
      END IF;
    END IF;
    
    -- 3-2: Lead Buyer에게 구매대기 알림
    IF v_payment_category IN ('구매 요청', '구매요청') AND 
       NEW.is_payment_completed = false AND 
       (NEW.progress_type ILIKE '%선진행%' OR 
        (NEW.progress_type ILIKE '%일반%' AND 
         (NEW.consumable_manager_status = 'approved' OR NEW.final_manager_status = 'approved'))) THEN
        
      v_notification_title := '🛒 새로운 구매대기 항목';
      v_notification_body := format('%s님의 구매 요청(%s)이 구매대기 목록에 추가되었습니다.',
          v_requester_name,
          NEW.purchase_order_number
      );

      SELECT ARRAY_AGG(fcm_token) INTO v_fcm_tokens
      FROM employees
      WHERE 'lead buyer' = ANY(purchase_role)
        AND fcm_token IS NOT NULL
        AND fcm_token != '';

      IF array_length(v_fcm_tokens, 1) > 0 THEN
        PERFORM net.http_post(
          url := v_supabase_url || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_anon_key,
            'Content-Type', 'application/json'
          )::jsonb,
          body := jsonb_build_object(
            'type', 'custom',
            'title', v_notification_title,
            'body', v_notification_body,
            'data', jsonb_build_object(
              'type', 'purchase_pending',
              'purchase_order_number', NEW.purchase_order_number,
              'requester_name', v_requester_name,
              'payment_category', v_payment_category
            ),
            'fcm_tokens', v_fcm_tokens,
            'skip_db_notification', true
          )::jsonb
        );
      END IF;
    END IF;
    
    RETURN NEW;
    
  ELSE
    RETURN NEW;
  END IF;

  -- 대상 역할별 FCM 토큰 수집 및 알림 전송
  FOR v_user IN 
    SELECT DISTINCT e.fcm_token
    FROM employees e
    WHERE e.purchase_role && v_target_roles
    AND e.fcm_token IS NOT NULL
    AND e.fcm_token != ''
  LOOP
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send_fcm_notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_anon_key,
        'Content-Type', 'application/json'
      )::jsonb,
      body := jsonb_build_object(
        'title', v_notification_title,
        'body', v_notification_body,
        'fcm_tokens', ARRAY[v_user.fcm_token],
        'data', jsonb_build_object(
          'type', v_notification_type,
          'purchase_order_number', NEW.purchase_order_number,
          'requester_name', v_requester_name,
          'payment_category', v_payment_category
        ),
        'requester_name', v_requester_name,
        'requester_department', v_payment_category,
        'skip_db_notification', true
      )::jsonb
    );
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 재생성
CREATE TRIGGER trigger_notify_purchase_status
BEFORE INSERT OR UPDATE ON purchase_requests
FOR EACH ROW
EXECUTE FUNCTION notify_purchase_status_change();

-- 권한 설정
GRANT EXECUTE ON FUNCTION notify_purchase_status_change() TO service_role;

-- 코멘트 추가
COMMENT ON FUNCTION notify_purchase_status_change() IS '발주/구매 요청의 상태 변경 시 payment_category에 따른 담당자별 알림 전송';
COMMENT ON TRIGGER trigger_notify_purchase_status ON purchase_requests IS 'payment_category별 발주/구매 상태 변경 알림 트리거';