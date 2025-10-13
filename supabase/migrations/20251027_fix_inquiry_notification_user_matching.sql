-- 20251027_fix_inquiry_notification_user_matching.sql
-- 문의 답변 알림이 가지 않는 문제 수정
-- 원인: user_id로 매칭시 employees.id와 일치하지 않음
-- 해결: user_email로 매칭하도록 변경

CREATE OR REPLACE FUNCTION public.notify_inquiry_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
    IF NEW.status = 'resolved' THEN
      v_title := '✅ 문의 답변 완료';
      v_body := LEFT(COALESCE(NEW.resolution_note, '답변이 등록되었습니다. 확인해주세요.'), 100);
    ELSIF NEW.status = 'closed' THEN
      v_title := '📋 문의 종료';
      v_body := '문의가 종료 처리되었습니다.';
    ELSIF NEW.status = 'in_progress' THEN
      v_title := '🔄 문의 확인중';
      v_body := '담당자가 문의를 확인하고 있습니다.';
    ELSE
      v_title := '📋 문의 상태 변경';
      v_body := format('상태: %s', 
        CASE NEW.status
          WHEN 'open' THEN '대기중'
          ELSE NEW.status
        END
      );
    END IF;
    
    -- 문의자의 FCM 토큰 조회 (email로 매칭하도록 수정)
    SELECT fcm_token INTO v_fcm_token
    FROM employees
    WHERE email = NEW.user_email  -- user_id 대신 email로 매칭
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF v_fcm_token IS NOT NULL THEN
      BEGIN
        -- send_fcm_notification 직접 호출
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
        
        RAISE NOTICE '문의 답변 알림 전송 성공: email=%, token=%, status=%', 
                     NEW.user_email, LEFT(v_fcm_token, 20) || '...', NEW.status;
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '문의 답변 알림 전송 실패: %', SQLERRM;
      END;
    ELSE
      RAISE WARNING '문의 답변 알림: FCM 토큰 없음 (email=%)', NEW.user_email;
    END IF;
    
    RAISE NOTICE '문의 상태 변경 알림: inquiry_id=%, status=%, user_email=%', 
                 NEW.id, NEW.status, NEW.user_email;
  END IF;
  
  RETURN NEW;
END;
$function$;