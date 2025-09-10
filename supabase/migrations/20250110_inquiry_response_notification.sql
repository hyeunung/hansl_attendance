-- 문의 답변 시 자동 푸시 알림 전송 트리거

-- 1. 트리거 함수 생성
CREATE OR REPLACE FUNCTION notify_inquiry_response()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id uuid;
  v_status text;
  v_resolution_note text;
BEGIN
  -- 답변이 추가되거나 상태가 변경된 경우만 처리
  IF (NEW.resolution_note IS DISTINCT FROM OLD.resolution_note AND NEW.resolution_note IS NOT NULL) 
     OR (NEW.status IS DISTINCT FROM OLD.status) THEN
    
    v_user_id := NEW.user_id;
    v_status := NEW.status;
    v_resolution_note := NEW.resolution_note;
    
    -- Edge Function 호출하여 푸시 알림 전송
    -- 비동기로 처리하여 트리거가 블로킹되지 않도록 함
    PERFORM net.http_post(
      url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/notify_inquiry_response',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true)
      ),
      body := jsonb_build_object(
        'inquiryId', NEW.id,
        'userId', v_user_id,
        'status', v_status,
        'resolutionNote', v_resolution_note
      )
    );
    
    -- 로그 기록 (디버깅용)
    RAISE NOTICE '문의 답변 알림 전송: inquiry_id=%, user_id=%, status=%', 
                 NEW.id, v_user_id, v_status;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 기존 트리거 삭제 (있을 경우)
DROP TRIGGER IF EXISTS trigger_notify_inquiry_response ON support_inquiries;

-- 3. 새 트리거 생성
CREATE TRIGGER trigger_notify_inquiry_response
AFTER UPDATE ON support_inquiries
FOR EACH ROW
EXECUTE FUNCTION notify_inquiry_response();

-- 4. 트리거 설명 추가
COMMENT ON TRIGGER trigger_notify_inquiry_response ON support_inquiries IS 
'문의에 답변이 추가되거나 상태가 변경될 때 사용자에게 푸시 알림을 전송합니다.';