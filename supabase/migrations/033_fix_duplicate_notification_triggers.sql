-- 중복 알림 트리거 정리
-- 작성일: 2025-01-17
-- 목적: 최종승인 대기 알림 등 중복 발생하는 트리거 제거

-- 1. 중복 트리거 확인 (실행 전 확인용)
-- SELECT 
--     tgname as trigger_name,
--     tgrelid::regclass as table_name,
--     proname as function_name
-- FROM pg_trigger t
-- JOIN pg_proc p ON t.tgfoid = p.oid
-- WHERE tgrelid::regclass::text = 'purchase_requests'
-- ORDER BY tgname;

-- 2. Lead Buyer 알림 관련 중복 트리거 제거
-- (025_fix_purchase_notification_system.sql의 통합 트리거를 사용하므로 이 트리거들은 불필요)
DROP TRIGGER IF EXISTS purchase_request_lead_buyer_notification_trigger ON purchase_requests;
DROP TRIGGER IF EXISTS purchase_request_lead_buyer_notification_update_trigger ON purchase_requests;
DROP FUNCTION IF EXISTS send_purchase_request_to_lead_buyer_notification();

-- 3. 기타 중복 가능한 트리거 제거
DROP TRIGGER IF EXISTS trigger_notify_new_purchase_request ON purchase_requests;
DROP FUNCTION IF EXISTS notify_new_purchase_request();

-- 4. 통합 트리거 확인 및 재생성
-- trigger_notify_purchase_status가 모든 알림을 처리하도록 수정
DROP TRIGGER IF EXISTS trigger_notify_purchase_status ON purchase_requests;

-- 통합 알림 함수 수정 (Lead Buyer 알림 포함)
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
  v_fcm_tokens text[];
BEGIN
  -- 발주 정보 가져오기
  v_requester_name := NEW.requester_name;
  v_payment_category := NEW.payment_category;
  
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
    v_notification_type := 'new_purchase_request';
    
  -- Case 2: 1차 승인 완료 → 최종 승인자에게 알림
  ELSIF TG_OP = 'UPDATE' AND 
        NEW.middle_manager_status = 'approved' AND 
        OLD.middle_manager_status = 'pending' THEN
    -- payment_category에 따라 대상 역할 결정
    IF v_payment_category = '발주' THEN
      v_target_roles := ARRAY['final_approver'];
    ELSIF v_payment_category = '원자재' THEN
      v_target_roles := ARRAY['raw_material_manager'];
    ELSE -- 구매 요청
      v_target_roles := ARRAY['consumable_manager'];
    END IF;
    
    v_notification_title := '🔔 최종 승인 대기 중';
    v_notification_body := format('%s님의 %s(%s) 최종 승인이 필요합니다. 금액: %s원',
      v_requester_name,
      v_payment_category,
      NEW.purchase_order_number,
      to_char(v_total_amount, 'FM999,999,999')
    );
    v_notification_type := 'final_approval_request';
    
  -- Case 3: 최종 승인 완료 시 알림들
  ELSIF TG_OP = 'UPDATE' AND 
        NEW.final_manager_status = 'approved' AND 
        OLD.final_manager_status IN ('pending', NULL) THEN
    
    -- 3-1: 신청자에게 승인 완료 알림
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
          'body', format('요청하신 %s(%s)가 최종 승인되었습니다.',
            v_payment_category,
            NEW.purchase_order_number
          ),
          'data', jsonb_build_object(
            'type', 'purchase_approved',
            'purchase_order_number', NEW.purchase_order_number,
            'payment_category', v_payment_category
          ),
          'fcm_tokens', ARRAY[v_user.fcm_token]
        )::jsonb
      );
    END IF;
    
    -- 3-2: 구매 요청인 경우 Lead Buyer에게 알림
    IF v_payment_category = '구매 요청' AND NEW.is_payment_completed = false THEN
      -- Lead Buyer들의 FCM 토큰 수집
      SELECT array_agg(fcm_token) INTO v_fcm_tokens
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
            'title', '🛒 새로운 구매대기 항목',
            'body', format('%s님의 구매 요청(%s)이 구매대기 목록에 추가되었습니다.',
              v_requester_name,
              NEW.purchase_order_number
            ),
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
        v_payment_category = '구매 요청' AND 
        NEW.is_payment_completed = false AND
        NEW.progress_type ILIKE '%선진행%' THEN
    
    -- Lead Buyer들의 FCM 토큰 수집
    SELECT array_agg(fcm_token) INTO v_fcm_tokens
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
    -- 하지만 선진행은 Lead Buyer 알림도 동시에 필요하므로 계속 진행
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
    -- 해당 역할을 가진 사용자들의 FCM 토큰 수집
    SELECT array_agg(fcm_token) INTO v_fcm_tokens
    FROM employees
    WHERE purchase_role && v_target_roles
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

-- 통합 트리거 재생성 (유일한 알림 트리거)
CREATE TRIGGER trigger_notify_purchase_status
  AFTER INSERT OR UPDATE ON purchase_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_purchase_status_change();

-- 권한 설정
GRANT EXECUTE ON FUNCTION notify_purchase_status_change() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_purchase_status_change() TO service_role;

-- 설명 추가
COMMENT ON FUNCTION notify_purchase_status_change() IS '발주/구매 요청의 모든 상태 변경 알림을 처리하는 통합 함수 (중복 제거됨)';
COMMENT ON TRIGGER trigger_notify_purchase_status ON purchase_requests IS '발주/구매 상태 변경 통합 알림 트리거 (유일한 트리거)';

-- 현재 활성화된 트리거 확인
-- SELECT 
--     tgname as trigger_name,
--     tgrelid::regclass as table_name,
--     proname as function_name
-- FROM pg_trigger t
-- JOIN pg_proc p ON t.tgfoid = p.oid
-- WHERE tgrelid::regclass::text = 'purchase_requests'
--   AND tgname NOT LIKE 'RI_ConstraintTrigger%'  -- 외래키 제약 트리거 제외
-- ORDER BY tgname;