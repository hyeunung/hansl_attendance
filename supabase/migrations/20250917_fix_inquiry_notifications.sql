-- 문의 관련 트리거를 send_fcm_notification을 사용하도록 수정

-- 1. notify_new_inquiry_to_admins 함수 수정
CREATE OR REPLACE FUNCTION public.notify_new_inquiry_to_admins()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- app_admin 권한이 있는 사용자들에게 알림 전송
  PERFORM net.http_post(
    url := (SELECT value FROM app_settings WHERE key = 'supabase_url') || '/functions/v1/send_fcm_notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT value FROM app_settings WHERE key = 'supabase_service_role_key')
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

-- 2. notify_inquiry_status_change 함수 수정
CREATE OR REPLACE FUNCTION public.notify_inquiry_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_email text;
BEGIN
  IF (NEW.status IS DISTINCT FROM OLD.status)
     OR (NEW.resolution_note IS DISTINCT FROM OLD.resolution_note AND NEW.resolution_note IS NOT NULL) THEN
    
    -- 문의를 작성한 사용자의 이메일 가져오기
    SELECT email INTO v_user_email
    FROM employees
    WHERE id = NEW.user_id::uuid;
    
    -- 문의 작성자에게 알림 전송
    PERFORM net.http_post(
      url := (SELECT value FROM app_settings WHERE key = 'supabase_url') || '/functions/v1/send_fcm_notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (SELECT value FROM app_settings WHERE key = 'supabase_service_role_key')
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

-- 3. 중복된 Edge Function 삭제 (나중에 수동으로 삭제)
-- Edge Function들은 Supabase Dashboard에서 수동으로 삭제해야 합니다:
-- - notify_new_inquiry
-- - notify_inquiry_response


