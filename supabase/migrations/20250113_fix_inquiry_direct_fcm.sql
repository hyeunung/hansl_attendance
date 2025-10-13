-- 문의 알림을 다른 알림과 동일한 방식으로 수정
-- send_fcm_notification을 직접 호출

-- 기존 트리거 제거
DROP TRIGGER IF EXISTS trigger_notify_new_inquiry ON support_inquires CASCADE;
DROP TRIGGER IF EXISTS trigger_notify_inquiry_status_change ON support_inquires CASCADE;
DROP FUNCTION IF EXISTS notify_new_inquiry_to_admins CASCADE;
DROP FUNCTION IF EXISTS notify_inquiry_status_change CASCADE;

-- ============================================
-- 1. 새 문의 생성 시 app_admin에게 알림 (다른 알림과 동일한 방식)
-- ============================================

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

  -- 알림 내용 설정
  v_title := '📝 새로운 문의가 접수되었습니다';
  v_body := format('%s님이 문의를 등록했습니다: %s', NEW.user_name, NEW.subject);

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

-- ============================================
-- 2. 문의 상태 변경 시 문의자에게 알림
-- ============================================

CREATE OR REPLACE FUNCTION notify_inquiry_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_key TEXT;
  v_title TEXT;
  v_body TEXT;
  v_fcm_token TEXT;
BEGIN
  -- 상태가 변경되거나 답변이 추가된 경우만 처리
  IF (NEW.status IS DISTINCT FROM OLD.status) OR 
     (NEW.resolution_note IS DISTINCT FROM OLD.resolution_note AND NEW.resolution_note IS NOT NULL) THEN
    
    -- app_settings에서 필요한 값들 가져오기
    SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
    SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';
    
    -- 환경변수가 없으면 경고만 하고 진행
    IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
      RAISE WARNING 'Supabase URL or Service Role Key not found in app_settings';
      RETURN NEW;
    END IF;
    
    -- 상태에 따른 알림 메시지 설정
    IF NEW.status = 'resolved' OR NEW.status = 'closed' THEN
      v_title := '✅ 문의 답변이 도착했습니다';
      v_body := COALESCE(NEW.resolution_note, '문의가 처리되었습니다. 앱에서 확인해주세요.');
    ELSIF NEW.status = 'in_progress' THEN
      v_title := '⏳ 문의 처리가 시작되었습니다';
      v_body := '관리자가 문의를 확인하고 처리를 시작했습니다.';
    ELSE
      v_title := '📋 문의 상태가 변경되었습니다';
      v_body := format('문의 상태: %s', NEW.status);
    END IF;
    
    -- 문의자의 FCM 토큰 조회
    SELECT fcm_token INTO v_fcm_token
    FROM employees
    WHERE id = NEW.user_id
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF v_fcm_token IS NOT NULL THEN
      BEGIN
        -- send_fcm_notification 직접 호출 (다른 알림과 동일)
        PERFORM net.http_post(
          url := v_supabase_url || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_service_key,
            'Content-Type', 'application/json'
          ),
          body := jsonb_build_object(
            'token', v_fcm_token,
            'title', v_title,
            'body', v_body,
            'data', jsonb_build_object(
              'type', 'inquiry_response',
              'inquiryId', NEW.id::text,
              'screen', 'inquiry_detail',
              'status', NEW.status,
              'hasResponse', (NEW.resolution_note IS NOT NULL)::text
            )
          )::jsonb
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '문의 답변 알림 전송 실패: %', SQLERRM;
      END;
    END IF;
    
    RAISE NOTICE '문의 상태 변경 알림: inquiry_id=%, status=%, user_id=%', 
                 NEW.id, NEW.status, NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 생성
CREATE TRIGGER trigger_notify_new_inquiry
AFTER INSERT ON support_inquires
FOR EACH ROW
EXECUTE FUNCTION notify_new_inquiry_to_admins();

CREATE TRIGGER trigger_notify_inquiry_status_change
AFTER UPDATE ON support_inquires
FOR EACH ROW
EXECUTE FUNCTION notify_inquiry_status_change();

-- 권한 설정 (다른 알림과 동일)
GRANT EXECUTE ON FUNCTION notify_new_inquiry_to_admins() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_new_inquiry_to_admins() TO service_role;
GRANT EXECUTE ON FUNCTION notify_inquiry_status_change() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_inquiry_status_change() TO service_role;

-- ============================================
-- 트리거 설명
-- ============================================

COMMENT ON TRIGGER trigger_notify_new_inquiry ON support_inquires IS 
'새 문의가 생성되면 모든 app_admin 권한자에게 푸시 알림을 전송합니다.';

COMMENT ON TRIGGER trigger_notify_inquiry_status_change ON support_inquires IS 
'문의 상태가 변경되거나 답변이 추가되면 문의자에게 푸시 알림을 전송합니다.';