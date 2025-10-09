-- 발주 알림 트리거 타이밍 문제 수정
-- BEFORE 트리거를 AFTER 트리거로 변경하여 데이터가 완전히 저장된 후 알림이 발송되도록 함

-- 1. 기존 트리거 삭제
DROP TRIGGER IF EXISTS trigger_notify_purchase_status ON purchase_requests;

-- 2. 최신 통합 알림 함수 (033_fix_duplicate_notification_triggers.sql 기반)
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
BEGIN
  -- 발주 정보 가져오기
  v_requester_name := NEW.requester_name;
  v_payment_category := NEW.payment_category;
  v_requester_email := NEW.requester_email;
  
  -- 총 금액 계산 (AFTER 트리거에서는 이미 아이템이 저장되어 있음)
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
        OLD.middle_manager_status = 'pending' THEN
    -- payment_category에 따라 대상 역할 결정
    IF v_payment_category = '발주' THEN
      v_target_roles := ARRAY['raw_material_manager', 'app_admin'];
    ELSIF v_payment_category IN ('구매 요청', '구매요청') THEN
      v_target_roles := ARRAY['consumable_manager', 'app_admin'];
    ELSE -- 기타
      v_target_roles := ARRAY['final_manager', 'app_admin'];
    END IF;
    
    v_notification_title := '🔍 최종 발주 승인 요청';
    v_notification_body := format('%s님의 %s(%s)가 1차 승인되었습니다. 최종 승인이 필요합니다.',
      v_requester_name,
      v_payment_category,
      NEW.purchase_order_number
    );
    v_notification_type := 'final_approval_request';
    
  -- Case 3: 최종 승인 완료 시 알림들
  ELSIF TG_OP = 'UPDATE' AND 
        ((v_payment_category = '발주' AND NEW.raw_material_manager_status = 'approved' AND OLD.raw_material_manager_status IN ('pending', NULL)) OR
         (v_payment_category IN ('구매 요청', '구매요청') AND NEW.consumable_manager_status = 'approved' AND OLD.consumable_manager_status IN ('pending', NULL)) OR
         (v_payment_category NOT IN ('발주', '구매 요청', '구매요청') AND NEW.final_manager_status = 'approved' AND OLD.final_manager_status IN ('pending', NULL))) THEN
    
    -- 3-1: 신청자에게 승인 완료 알림
    IF v_requester_email IS NOT NULL THEN
      SELECT fcm_token INTO v_user.fcm_token
      FROM employees
      WHERE email = v_requester_email
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
      
      IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
        PERFORM net.http_post(
          url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
          ),
          body := jsonb_build_object(
            'type', 'custom',
            'title', v_notification_title,
            'body', v_notification_body,
            'data', jsonb_build_object(
              'type', 'purchase_request',
              'purchase_order_number', NEW.purchase_order_number,
              'payment_category', v_payment_category,
              'requester_name', v_requester_name
            ),
            'fcm_tokens', v_fcm_tokens
          )::jsonb
        );
      END IF;
    END IF;
    
    RETURN NEW; -- 완료
    
  -- Case 4: 선진행 구매 요청 생성 시 Lead Buyer에게 즉시 알림
  ELSIF TG_OP = 'INSERT' AND 
        v_payment_category IN ('구매 요청', '구매요청') AND 
        NEW.is_payment_completed = false AND
        NEW.progress_type ILIKE '%선진행%' THEN
    
    -- Lead Buyer들의 FCM 토큰 수집
    SELECT ARRAY_AGG(fcm_token) INTO v_fcm_tokens
    FROM employees
    WHERE 'lead buyer' = ANY(purchase_role)
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
      PERFORM net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
        ),
        body := jsonb_build_object(
          'type', 'custom',
          'title', '🛒 [선진행] 새로운 구매대기 항목',
          'body', format('%s님의 선진행 구매 요청(%s)이 구매대기 목록에 추가되었습니다.',
            v_requester_name,
            NEW.purchase_order_number
          ),
          'data', jsonb_build_object(
            'type', 'purchase_request',
            'purchase_order_number', NEW.purchase_order_number,
            'payment_category', v_payment_category,
            'requester_name', v_requester_name,
            'progress_type', NEW.progress_type
          ),
          'fcm_tokens', v_fcm_tokens
        )::jsonb
      );
    END IF;
    
    -- 선진행도 1차 승인자에게는 알림 (이미 Case 1에서 처리됨)
    v_target_roles := ARRAY['middle_manager'];
    v_notification_title := '🆕 [선진행] 새 발주 승인 요청';
    v_notification_body := format('%s님이 선진행 %s(%s)를 요청했습니다. 금액: %s원',
      v_requester_name, 
      v_payment_category,
      NEW.purchase_order_number,
      to_char(v_total_amount, 'FM999,999,999')
    );
    v_notification_type := 'new_purchase_request';
    
  ELSE
    -- 알림이 필요없는 경우
    RETURN NEW;
  END IF;

  -- 대상 역할이 설정된 경우 알림 전송
  IF v_target_roles IS NOT NULL THEN
    -- 대상 역할의 사용자들 FCM 토큰 수집
    SELECT ARRAY_AGG(fcm_token) INTO v_fcm_tokens
    FROM employees e
    WHERE e.purchase_role && v_target_roles
      AND e.fcm_token IS NOT NULL
      AND e.fcm_token != '';
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
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
          'fcm_tokens', v_fcm_tokens
        )::jsonb
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. AFTER 트리거로 재생성 (데이터가 완전히 저장된 후 실행)
CREATE TRIGGER trigger_notify_purchase_status
  AFTER INSERT OR UPDATE ON purchase_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_purchase_status_change();

-- 4. 권한 설정
GRANT EXECUTE ON FUNCTION notify_purchase_status_change() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_purchase_status_change() TO service_role;

-- 5. 설명 추가
COMMENT ON FUNCTION notify_purchase_status_change() IS '발주/구매 요청의 모든 상태 변경 알림을 처리하는 통합 함수 (AFTER 트리거로 수정됨)';
COMMENT ON TRIGGER trigger_notify_purchase_status ON purchase_requests IS '발주/구매 상태 변경 통합 알림 트리거 (AFTER 트리거)';

-- 6. 현재 활성화된 트리거 확인용 쿼리
-- SELECT 
--     tgname as trigger_name,
--     tgrelid::regclass as table_name,
--     proname as function_name,
--     CASE 
--         WHEN (tgtype & 2) = 2 THEN 'BEFORE'
--         WHEN (tgtype & 2) = 0 THEN 'AFTER'
--     END as trigger_timing
-- FROM pg_trigger t
-- JOIN pg_proc p ON t.tgfoid = p.oid
-- WHERE tgrelid::regclass::text = 'purchase_requests'
--   AND tgname NOT LIKE 'RI_ConstraintTrigger%'
-- ORDER BY tgname;

