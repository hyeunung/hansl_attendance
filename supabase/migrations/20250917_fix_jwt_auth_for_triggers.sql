-- DB 트리거에서 Edge Function 호출 시 JWT 인증 문제 해결

-- app_settings에 anon key 추가
INSERT INTO app_settings (key, value)
VALUES ('supabase_anon_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- notify_new_purchase_request 함수 수정 - anon key 사용
CREATE OR REPLACE FUNCTION public.notify_new_purchase_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_requester_name TEXT;
  v_payment_category TEXT;
  v_total_amount NUMERIC;
  v_title TEXT;
  v_body TEXT;
  v_fcm_tokens TEXT[];
  v_supabase_url TEXT;
  v_anon_key TEXT;
BEGIN
  -- 환경변수 가져오기 (app_settings 테이블에서)
  SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_anon_key FROM app_settings WHERE key = 'supabase_anon_key';
  
  -- 환경변수가 없으면 경고만 하고 진행
  IF v_supabase_url IS NULL OR v_anon_key IS NULL THEN
    RAISE WARNING 'Supabase URL or Anon Key not found in app_settings';
    RETURN NEW;
  END IF;

  -- 새 발주 요청이 생성될 때만 실행
  IF TG_OP = 'INSERT' THEN
    v_requester_name := NEW.requester_name;
    v_payment_category := NEW.payment_category;
    
    -- 총 금액 계산
    SELECT SUM(quantity * unit_price_value) INTO v_total_amount
    FROM purchase_request_items
    WHERE purchase_request_id = NEW.id;
    
    -- 알림 제목과 내용 설정
    v_title := '🆕 새 발주 승인 요청';
    v_body := format('%s님이 %s 발주(%s)를 요청했습니다. 금액: %s원',
      v_requester_name, 
      v_payment_category,
      NEW.purchase_order_number,
      to_char(COALESCE(v_total_amount, 0), 'FM999,999,999')
    );
    
    -- middle_manager와 app_admin의 FCM 토큰 수집
    SELECT array_agg(fcm_token) INTO v_fcm_tokens
    FROM employees
    WHERE ('middle_manager' = ANY(purchase_role) OR 'app_admin' = ANY(purchase_role))
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
      BEGIN
        -- Edge Function 호출하여 FCM 알림 전송 (anon key 사용)
        PERFORM net.http_post(
          url := v_supabase_url || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_anon_key,
            'Content-Type', 'application/json'
          ),
          body := jsonb_build_object(
            'type', 'custom',
            'title', v_title,
            'body', v_body,
            'data', jsonb_build_object(
              'type', 'new_purchase_request',
              'purchase_order_number', NEW.purchase_order_number,
              'requester_name', v_requester_name,
              'payment_category', v_payment_category
            ),
            'fcm_tokens', v_fcm_tokens
          )::jsonb
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '알림 전송 실패: %', SQLERRM;
      END;
    END IF;
    
    -- 알림 내역 저장
    INSERT INTO notifications (user_email, title, body, type, data, is_read, created_at)
    SELECT 
      email,
      v_title,
      v_body,
      'purchase_request',
      jsonb_build_object(
        'type', 'new_purchase_request',
        'purchase_order_number', NEW.purchase_order_number,
        'requester_name', v_requester_name,
        'payment_category', v_payment_category
      ),
      false,
      NOW()
    FROM employees
    WHERE ('middle_manager' = ANY(purchase_role) OR 'app_admin' = ANY(purchase_role));
    
    RAISE NOTICE '새 발주 요청 알림 전송: % (발주번호: %), FCM 토큰 수: %', 
      v_requester_name, NEW.purchase_order_number, COALESCE(array_length(v_fcm_tokens, 1), 0);
  END IF;
  
  RETURN NEW;
END;
$$;

-- notify_lead_buyer_purchase_request 함수도 수정
CREATE OR REPLACE FUNCTION public.notify_lead_buyer_purchase_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_title TEXT;
  v_body TEXT;
  v_fcm_tokens TEXT[];
  v_supabase_url TEXT;
  v_anon_key TEXT;
BEGIN
  -- 환경변수 가져오기
  SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_anon_key FROM app_settings WHERE key = 'supabase_anon_key';
  
  IF v_supabase_url IS NULL OR v_anon_key IS NULL THEN
    RAISE WARNING 'Supabase URL or Anon Key not found in app_settings';
    RETURN NEW;
  END IF;

  -- final_manager_status가 final_approved로 변경될 때만 실행
  IF OLD.final_manager_status IS DISTINCT FROM NEW.final_manager_status 
     AND NEW.final_manager_status = 'final_approved' THEN
    
    v_title := '🛒 새로운 구매대기 항목';
    v_body := format('%s 발주가 최종 승인되어 구매대기 상태입니다.',
      NEW.purchase_order_number
    );
    
    -- lead_buyer 역할을 가진 사용자들의 FCM 토큰 수집
    SELECT array_agg(fcm_token) INTO v_fcm_tokens
    FROM employees
    WHERE 'lead_buyer' = ANY(purchase_role)
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
      BEGIN
        -- Edge Function 호출하여 FCM 알림 전송 (anon key 사용)
        PERFORM net.http_post(
          url := v_supabase_url || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_anon_key,
            'Content-Type', 'application/json'
          ),
          body := jsonb_build_object(
            'type', 'custom',
            'title', v_title,
            'body', v_body,
            'data', jsonb_build_object(
              'type', 'purchase_request_lead_buyer',
              'purchase_order_number', NEW.purchase_order_number
            ),
            'fcm_tokens', v_fcm_tokens
          )::jsonb
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '알림 전송 실패: %', SQLERRM;
      END;
    END IF;
    
    -- 알림 내역 저장
    INSERT INTO notifications (user_email, title, body, type, data, is_read, created_at)
    SELECT 
      email,
      v_title,
      v_body,
      'purchase_request',
      jsonb_build_object(
        'type', 'purchase_request_lead_buyer',
        'purchase_order_number', NEW.purchase_order_number
      ),
      false,
      NOW()
    FROM employees
    WHERE 'lead_buyer' = ANY(purchase_role);
    
    RAISE NOTICE 'Lead buyer 알림 전송: 발주번호 %, FCM 토큰 수: %', 
      NEW.purchase_order_number, COALESCE(array_length(v_fcm_tokens, 1), 0);
  END IF;
  
  RETURN NEW;
END;
$$;

-- 문의 관련 함수들도 수정
CREATE OR REPLACE FUNCTION public.notify_new_inquiry_to_admins()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_anon_key TEXT;
  v_supabase_url TEXT;
BEGIN
  -- 환경변수 가져오기
  SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_anon_key FROM app_settings WHERE key = 'supabase_anon_key';
  
  IF v_supabase_url IS NULL OR v_anon_key IS NULL THEN
    RAISE WARNING 'Supabase URL or Anon Key not found in app_settings';
    RETURN NEW;
  END IF;

  -- app_admin 권한이 있는 사용자들에게 알림 전송
  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/send_fcm_notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_anon_key
    ),
    body := jsonb_build_object(
      'type', 'admin',
      'title', '🆕 새로운 문의',
      'body', format('%s님이 문의를 등록했습니다: %s', NEW.user_name, NEW.subject),
      'data', jsonb_build_object(
        'type', 'new_inquiry',
        'inquiry_id', NEW.id::text,
        'user_name', NEW.user_name,
        'subject', NEW.subject,
        'inquiry_type', NEW.inquiry_type
      )
    )
  );
  
  -- notifications 테이블에 기록
  INSERT INTO notifications (user_email, type, title, message, data)
  SELECT 
    e.email,
    'new_inquiry',
    '🆕 새로운 문의',
    format('%s님이 문의를 등록했습니다: %s', NEW.user_name, NEW.subject),
    jsonb_build_object(
      'inquiry_id', NEW.id,
      'user_name', NEW.user_name,
      'subject', NEW.subject,
      'inquiry_type', NEW.inquiry_type
    )
  FROM employees e
  WHERE 'app_admin' = ANY(e.attendance_role);
  
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_inquiry_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_email text;
  v_anon_key TEXT;
  v_supabase_url TEXT;
BEGIN
  -- 환경변수 가져오기
  SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_anon_key FROM app_settings WHERE key = 'supabase_anon_key';
  
  IF v_supabase_url IS NULL OR v_anon_key IS NULL THEN
    RAISE WARNING 'Supabase URL or Anon Key not found in app_settings';
    RETURN NEW;
  END IF;

  IF (NEW.status IS DISTINCT FROM OLD.status)
     OR (NEW.resolution_note IS DISTINCT FROM OLD.resolution_note AND NEW.resolution_note IS NOT NULL) THEN
    
    -- 문의를 작성한 사용자의 이메일 가져오기
    SELECT email INTO v_user_email
    FROM employees
    WHERE id = NEW.user_id::uuid;
    
    -- 문의 작성자에게 알림 전송
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send_fcm_notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_anon_key
      ),
      body := jsonb_build_object(
        'type', 'user',
        'user_email', v_user_email,
        'title', '📬 문의 답변',
        'body', format('문의에 대한 답변이 등록되었습니다: %s', NEW.subject),
        'data', jsonb_build_object(
          'type', 'inquiry_response',
          'inquiry_id', NEW.id::text,
          'status', NEW.status,
          'resolution_note', NEW.resolution_note
        )
      )
    );
    
    -- notifications 테이블에 기록
    INSERT INTO notifications (user_email, type, title, message, data)
    VALUES (
      v_user_email,
      'inquiry_response',
      '📬 문의 답변',
      format('문의에 대한 답변이 등록되었습니다: %s', NEW.subject),
      jsonb_build_object(
        'inquiry_id', NEW.id,
        'status', NEW.status,
        'resolution_note', NEW.resolution_note
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;


