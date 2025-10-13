-- 전체 푸시알림 시스템 복구 및 수정
-- 모든 함수가 service_role_key를 사용하도록 통합

-- 1. notify_new_purchase_request 함수 복구 및 수정
CREATE OR REPLACE FUNCTION notify_new_purchase_request()
RETURNS TRIGGER AS $$
DECLARE
  v_requester_name TEXT;
  v_payment_category TEXT;
  v_total_amount NUMERIC;
  v_title TEXT;
  v_body TEXT;
  v_fcm_tokens TEXT[];
  v_supabase_url TEXT;
  v_service_key TEXT;
BEGIN
  -- app_settings에서 필요한 값들 가져오기
  SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';
  
  -- 환경변수가 없으면 경고만 하고 진행
  IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
    RAISE WARNING 'Supabase URL or Service Role Key not found in app_settings';
    RETURN NEW;
  END IF;

  -- 새 발주 요청이 생성될 때만 실행
  IF TG_OP = 'INSERT' THEN
    v_requester_name := NEW.requester_name;
    v_payment_category := NEW.payment_category;
    
    -- 총 금액 계산
    SELECT COALESCE(SUM(amount_value), 0) INTO v_total_amount
    FROM purchase_request_items
    WHERE purchase_order_number = NEW.purchase_order_number;
    
    -- 알림 제목과 내용 설정
    v_title := '🆕 새 발주 승인 요청';
    v_body := format('%s님이 %s 발주(%s)를 요청했습니다. 금액: %s원',
      v_requester_name, 
      v_payment_category,
      NEW.purchase_order_number,
      to_char(COALESCE(v_total_amount, 0), 'FM999,999,999')
    );
    
    -- middle_manager와 app_admin의 FCM 토큰 수집
    SELECT array_agg(DISTINCT fcm_token) INTO v_fcm_tokens
    FROM employees
    WHERE ('middle_manager' = ANY(purchase_role) OR 'app_admin' = ANY(purchase_role))
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
      BEGIN
        -- Edge Function 호출하여 FCM 알림 전송
        PERFORM net.http_post(
          url := v_supabase_url || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_service_key,
            'Content-Type', 'application/json'
          ),
          body := jsonb_build_object(
            'type', 'admin',
            'title', v_title,
            'body', v_body,
            'data', jsonb_build_object(
              'type', 'new_purchase_request',
              'purchase_order_number', NEW.purchase_order_number,
              'requester_name', v_requester_name,
              'payment_category', v_payment_category
            ),
            'fcm_tokens', v_fcm_tokens,
            'skip_db_notification', true
          )::jsonb
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '알림 전송 실패: %', SQLERRM;
      END;
    END IF;
    
    RAISE NOTICE '새 발주 요청 알림 전송: % (발주번호: %), FCM 토큰 수: %', 
      v_requester_name, NEW.purchase_order_number, COALESCE(array_length(v_fcm_tokens, 1), 0);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. notify_lead_buyer_purchase_request 함수 복구 및 수정
CREATE OR REPLACE FUNCTION notify_lead_buyer_purchase_request()
RETURNS TRIGGER AS $$
DECLARE
  v_title TEXT;
  v_body TEXT;
  v_fcm_tokens TEXT[];
  v_supabase_url TEXT;
  v_service_key TEXT;
BEGIN
  -- app_settings에서 필요한 값들 가져오기
  SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';
  
  -- 환경변수가 없으면 경고만 하고 진행
  IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
    RAISE WARNING 'Supabase URL or Service Role Key not found in app_settings';
    RETURN NEW;
  END IF;

  -- 조건 확인: 구매 요청이고, 결제 완료되지 않았고, 선진행이거나 일반진행에서 final_manager 승인된 경우
  IF NEW.payment_category = '구매 요청' AND 
     NEW.is_payment_completed = false AND
     (NEW.progress_type ILIKE '%선진행%' OR 
      (NEW.progress_type ILIKE '%일반%' AND NEW.final_manager_status = 'approved')) THEN
    
    -- INSERT 시
    IF TG_OP = 'INSERT' AND NEW.progress_type ILIKE '%선진행%' THEN
      v_title := '🛒 새로운 구매대기 항목';
      v_body := format('%s님의 구매 요청(%s)이 구매대기 목록에 추가되었습니다.',
        NEW.requester_name, NEW.purchase_order_number);
    
    -- UPDATE 시 - final_manager 승인
    ELSIF TG_OP = 'UPDATE' AND OLD.final_manager_status != 'approved' AND NEW.final_manager_status = 'approved' THEN
      v_title := '🛒 새로운 구매대기 항목';
      v_body := format('%s님의 구매 요청(%s)이 최종 승인되어 구매대기 목록에 추가되었습니다.',
        NEW.requester_name, NEW.purchase_order_number);
    
    ELSE
      RETURN NEW;
    END IF;
    
    -- lead buyer 권한을 가진 사용자들의 FCM 토큰 조회
    SELECT array_agg(DISTINCT fcm_token) INTO v_fcm_tokens
    FROM employees
    WHERE 'lead buyer' = ANY(purchase_role)
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
      BEGIN
        -- Edge Function 호출하여 FCM 알림 전송
        PERFORM net.http_post(
          url := v_supabase_url || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_service_key,
            'Content-Type', 'application/json'
          ),
          body := jsonb_build_object(
            'type', 'admin',
            'title', v_title,
            'body', v_body,
            'data', jsonb_build_object(
              'type', 'purchase_pending',
              'purchase_order_number', NEW.purchase_order_number,
              'requester_name', NEW.requester_name,
              'payment_category', NEW.payment_category
            ),
            'fcm_tokens', v_fcm_tokens,
            'skip_db_notification', true
          )::jsonb
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Lead Buyer 알림 전송 실패: %', SQLERRM;
      END;
    END IF;
    
    RAISE NOTICE 'Lead Buyer 알림 전송: % (발주번호: %), FCM 토큰 수: %', 
      NEW.requester_name, NEW.purchase_order_number, COALESCE(array_length(v_fcm_tokens, 1), 0);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 트리거 생성/재생성
DROP TRIGGER IF EXISTS trigger_notify_new_purchase_request ON purchase_requests;
CREATE TRIGGER trigger_notify_new_purchase_request
  AFTER INSERT ON purchase_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_purchase_request();

DROP TRIGGER IF EXISTS trigger_notify_lead_buyer_purchase_request ON purchase_requests;
CREATE TRIGGER trigger_notify_lead_buyer_purchase_request
  AFTER INSERT OR UPDATE ON purchase_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_lead_buyer_purchase_request();

-- 4. 권한 설정
GRANT EXECUTE ON FUNCTION notify_new_purchase_request() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_new_purchase_request() TO service_role;
GRANT EXECUTE ON FUNCTION notify_lead_buyer_purchase_request() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_lead_buyer_purchase_request() TO service_role;

-- 5. 모든 알림 함수 상태 확인
SELECT 
    p.proname as function_name,
    tgrelid::regclass as table_name,
    tgname as trigger_name,
    tgenabled as is_enabled,
    CASE 
        WHEN pg_get_functiondef(p.oid) LIKE '%v_anon_key%' THEN 'Uses anon_key ❌'
        WHEN pg_get_functiondef(p.oid) LIKE '%v_service_key%' THEN 'Uses service_key ✅'
        WHEN pg_get_functiondef(p.oid) LIKE '%current_setting%' THEN 'Uses current_setting ⚠️'
        ELSE 'Unknown/No http_post'
    END as auth_type
FROM pg_proc p
LEFT JOIN pg_trigger t ON t.tgfoid = p.oid
WHERE p.pronamespace = 'public'::regnamespace
AND (pg_get_functiondef(p.oid) LIKE '%net.http_post%' 
     OR p.proname LIKE '%notify%')
ORDER BY table_name, p.proname;


















