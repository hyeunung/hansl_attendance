-- 문의 알림 텍스트 중복 제거 수정

CREATE OR REPLACE FUNCTION notify_new_inquiry_to_admins()
RETURNS TRIGGER AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_key TEXT;
  v_title TEXT;
  v_body TEXT;
  v_fcm_tokens TEXT[];
BEGIN
  -- app_settings에서 필요한 값들 가져오기
  SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';
  
  -- 환경변수가 없으면 경고만 하고 진행
  IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
    RAISE WARNING 'Supabase URL or Service Role Key not found in app_settings';
    RETURN NEW;
  END IF;

  -- 알림 내용 설정 (subject에 이미 유형이 포함되어 있으면 그대로, 없으면 추가)
  v_title := '📝 새 문의 접수';
  
  -- subject가 이미 [로 시작하면 그대로 사용, 아니면 유형 추가
  IF LEFT(NEW.subject, 1) = '[' THEN
    v_body := NEW.subject;
  ELSE
    v_body := format('[%s] %s', 
      CASE NEW.inquiry_type 
        WHEN 'bug' THEN '오류'
        WHEN 'other' THEN '기타'
        ELSE NEW.inquiry_type
      END,
      NEW.subject
    );
  END IF;

  -- app_admin 권한을 가진 사용자들의 FCM 토큰 조회
  SELECT array_agg(DISTINCT fcm_token) INTO v_fcm_tokens
  FROM employees
  WHERE 'app_admin' = ANY(purchase_role)
    AND fcm_token IS NOT NULL
    AND fcm_token != '';

  -- FCM 토큰이 있는 경우에만 알림 전송
  IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
    BEGIN
      -- send_fcm_notification 직접 호출 (다른 알림과 동일)
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
            'type', 'inquiry_new',
            'inquiryId', NEW.id::text,
            'screen', 'inquiry_detail',
            'userName', NEW.user_name,
            'inquiryType', NEW.inquiry_type
          ),
          'fcm_tokens', v_fcm_tokens,
          'skip_db_notification', true
        )::jsonb
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '문의 알림 전송 실패: %', SQLERRM;
    END;
  END IF;
  
  RAISE NOTICE '새 문의 알림 전송: inquiry_id=%, user=%, FCM 토큰 수: %', 
    NEW.id, NEW.user_name, COALESCE(array_length(v_fcm_tokens, 1), 0);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;