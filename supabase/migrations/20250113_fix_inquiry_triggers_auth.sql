-- 문의 알림 트리거 인증 문제 수정
-- service_role_key 설정 및 헤더 수정

-- 기존 트리거 제거
DROP TRIGGER IF EXISTS trigger_notify_new_inquiry ON support_inquires CASCADE;
DROP TRIGGER IF EXISTS trigger_notify_inquiry_status_change ON support_inquires CASCADE;
DROP FUNCTION IF EXISTS notify_new_inquiry_to_admins CASCADE;
DROP FUNCTION IF EXISTS notify_inquiry_status_change CASCADE;

-- ============================================
-- 1. 새 문의 생성 시 app_admin에게 알림 (인증 수정)
-- ============================================

CREATE OR REPLACE FUNCTION notify_new_inquiry_to_admins()
RETURNS TRIGGER AS $$
DECLARE
  service_key TEXT;
BEGIN
  -- service_role_key 가져오기
  SELECT decrypted_secret INTO service_key 
  FROM vault.decrypted_secrets 
  WHERE name = 'service_role_key'
  LIMIT 1;

  -- 새 문의가 생성되면 모든 app_admin에게 알림
  PERFORM net.http_post(
    url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/notify_new_inquiry',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object(
      'inquiryId', NEW.id,
      'userName', NEW.user_name,
      'subject', NEW.subject,
      'inquiryType', NEW.inquiry_type
    )
  );
  
  RAISE NOTICE '새 문의 알림 전송: inquiry_id=%, user=%', NEW.id, NEW.user_name;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- 에러 발생해도 문의 생성은 계속 진행
    RAISE WARNING '알림 전송 실패: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 생성
CREATE TRIGGER trigger_notify_new_inquiry
AFTER INSERT ON support_inquires
FOR EACH ROW
EXECUTE FUNCTION notify_new_inquiry_to_admins();

-- ============================================
-- 2. 문의 상태 변경 시 문의자에게 알림 (인증 수정)
-- ============================================

CREATE OR REPLACE FUNCTION notify_inquiry_status_change()
RETURNS TRIGGER AS $$
DECLARE
  service_key TEXT;
BEGIN
  -- 상태가 변경되거나 답변이 추가된 경우만 처리
  IF (NEW.status IS DISTINCT FROM OLD.status) OR 
     (NEW.resolution_note IS DISTINCT FROM OLD.resolution_note AND NEW.resolution_note IS NOT NULL) THEN
    
    -- service_role_key 가져오기
    SELECT decrypted_secret INTO service_key 
    FROM vault.decrypted_secrets 
    WHERE name = 'service_role_key'
    LIMIT 1;
    
    -- 문의자에게 알림 전송
    PERFORM net.http_post(
      url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/notify_inquiry_response',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key
      ),
      body := jsonb_build_object(
        'inquiryId', NEW.id,
        'userId', NEW.user_id,
        'status', NEW.status,
        'resolutionNote', NEW.resolution_note
      )
    );
    
    RAISE NOTICE '문의 상태 변경 알림: inquiry_id=%, status=%, user_id=%', 
                 NEW.id, NEW.status, NEW.user_id;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- 에러 발생해도 상태 변경은 계속 진행
    RAISE WARNING '알림 전송 실패: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 생성
CREATE TRIGGER trigger_notify_inquiry_status_change
AFTER UPDATE ON support_inquires
FOR EACH ROW
EXECUTE FUNCTION notify_inquiry_status_change();

-- ============================================
-- 트리거 설명
-- ============================================

COMMENT ON TRIGGER trigger_notify_new_inquiry ON support_inquires IS 
'새 문의가 생성되면 모든 app_admin 권한자에게 푸시 알림을 전송합니다.';

COMMENT ON TRIGGER trigger_notify_inquiry_status_change ON support_inquires IS 
'문의 상태가 변경되거나 답변이 추가되면 문의자에게 푸시 알림을 전송합니다.';