-- 모든 anon_key 사용 문제 해결
-- support_inquires 테이블의 함수들도 service_role_key를 사용하도록 수정

-- 1. notify_inquiry_status_change 함수 수정
CREATE OR REPLACE FUNCTION notify_inquiry_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_supabase_url text;
  v_service_key text;
  v_admin_tokens text[];
  v_inquiry_id text;
  v_user_name text;
  v_title text;
  v_status text;
BEGIN
  -- 상태가 변경된 경우만 처리
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    -- app_settings에서 필요한 값들 가져오기
    SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
    SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';
    
    -- 문의 정보 가져오기
    v_inquiry_id := NEW.id::text;
    v_user_name := NEW.user_name;
    v_title := NEW.title;
    v_status := NEW.status;
    
    -- app_admin 권한을 가진 사용자들의 FCM 토큰 조회
    SELECT ARRAY_AGG(DISTINCT fcm_token) INTO v_admin_tokens
    FROM employees
    WHERE 'app_admin' = ANY(purchase_role) 
       OR 'app_admin' = ANY(attendance_role)
    AND fcm_token IS NOT NULL
    AND fcm_token != '';
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF array_length(v_admin_tokens, 1) > 0 THEN
      PERFORM net.http_post(
        url := v_supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || v_service_key,
          'Content-Type', 'application/json'
        )::jsonb,
        body := jsonb_build_object(
          'type', 'admin',
          'title', '📝 문의사항 상태 변경',
          'body', format('%s님의 문의사항이 %s 상태로 변경되었습니다.', v_user_name, v_status),
          'fcm_tokens', v_admin_tokens,
          'data', jsonb_build_object(
            'type', 'inquiry_status_change',
            'inquiry_id', v_inquiry_id,
            'user_name', v_user_name,
            'title', v_title,
            'status', v_status
          ),
          'skip_db_notification', true
        )::jsonb
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. notify_new_inquiry_to_admins 함수 수정
CREATE OR REPLACE FUNCTION notify_new_inquiry_to_admins()
RETURNS TRIGGER AS $$
DECLARE
  v_supabase_url text;
  v_service_key text;
  v_admin_tokens text[];
  v_inquiry_id text;
  v_user_name text;
  v_title text;
  v_content text;
BEGIN
  -- 신규 문의사항만 처리
  IF TG_OP = 'INSERT' THEN
    -- app_settings에서 필요한 값들 가져오기
    SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
    SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';
    
    -- 문의사항 정보 가져오기
    v_inquiry_id := NEW.id::text;
    v_user_name := NEW.user_name;
    v_title := NEW.title;
    v_content := LEFT(NEW.content, 100); -- 내용은 100자로 제한
    
    -- app_admin 권한을 가진 사용자들의 FCM 토큰 조회
    SELECT ARRAY_AGG(DISTINCT fcm_token) INTO v_admin_tokens
    FROM employees
    WHERE 'app_admin' = ANY(purchase_role) 
       OR 'app_admin' = ANY(attendance_role)
    AND fcm_token IS NOT NULL
    AND fcm_token != '';
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF array_length(v_admin_tokens, 1) > 0 THEN
      PERFORM net.http_post(
        url := v_supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || v_service_key,
          'Content-Type', 'application/json'
        )::jsonb,
        body := jsonb_build_object(
          'type', 'admin',
          'title', '🆕 새로운 문의사항',
          'body', format('%s님이 새로운 문의사항을 등록했습니다: %s', v_user_name, v_title),
          'fcm_tokens', v_admin_tokens,
          'data', jsonb_build_object(
            'type', 'new_inquiry',
            'inquiry_id', v_inquiry_id,
            'user_name', v_user_name,
            'title', v_title,
            'content', v_content
          ),
          'skip_db_notification', true
        )::jsonb
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 권한 설정
GRANT EXECUTE ON FUNCTION notify_inquiry_status_change() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_inquiry_status_change() TO service_role;
GRANT EXECUTE ON FUNCTION notify_new_inquiry_to_admins() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_new_inquiry_to_admins() TO service_role;

-- 4. 모든 http_post를 사용하는 함수 확인
SELECT DISTINCT 
    p.proname as function_name,
    tgrelid::regclass as table_name,
    CASE 
        WHEN pg_get_functiondef(p.oid) LIKE '%v_anon_key%' THEN 'Uses anon_key ❌'
        WHEN pg_get_functiondef(p.oid) LIKE '%v_service_key%' THEN 'Uses service_key ✅'
        WHEN pg_get_functiondef(p.oid) LIKE '%current_setting%' THEN 'Uses current_setting ⚠️'
        ELSE 'Unknown'
    END as auth_type
FROM pg_proc p
LEFT JOIN pg_trigger t ON t.tgfoid = p.oid
WHERE pg_get_functiondef(p.oid) LIKE '%net.http_post%'
AND p.pronamespace = 'public'::regnamespace
ORDER BY p.proname;















