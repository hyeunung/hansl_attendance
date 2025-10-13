-- 문의 알림 트리거 테이블명 수정
-- 잘못된 테이블명: support_inquiries
-- 올바른 테이블명: support_inquires

-- 기존 잘못된 트리거는 테이블이 없어서 삭제 불가 (스킵)

-- support_inquires 테이블의 기존 트리거도 삭제 (중복 방지)
DROP TRIGGER IF EXISTS trigger_notify_new_inquiry ON support_inquires;
DROP TRIGGER IF EXISTS trigger_notify_inquiry_response ON support_inquires;
DROP TRIGGER IF EXISTS trigger_notify_inquiry_status_change ON support_inquires;

-- ============================================
-- 1. 새 문의 생성 시 app_admin에게 알림
-- ============================================

CREATE OR REPLACE FUNCTION notify_new_inquiry_to_admins()
RETURNS TRIGGER AS $$
BEGIN
  -- 새 문의가 생성되면 모든 app_admin에게 알림
  PERFORM net.http_post(
    url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/notify_new_inquiry',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true)
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 올바른 테이블에 트리거 생성
CREATE TRIGGER trigger_notify_new_inquiry
AFTER INSERT ON support_inquires
FOR EACH ROW
EXECUTE FUNCTION notify_new_inquiry_to_admins();

-- ============================================
-- 2. 문의 상태 변경 시 문의자에게 알림
-- ============================================

CREATE OR REPLACE FUNCTION notify_inquiry_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- 상태가 변경되거나 답변이 추가된 경우만 처리
  IF (NEW.status IS DISTINCT FROM OLD.status) OR 
     (NEW.resolution_note IS DISTINCT FROM OLD.resolution_note AND NEW.resolution_note IS NOT NULL) THEN
    
    -- 문의자에게 알림 전송
    PERFORM net.http_post(
      url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/notify_inquiry_response',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true)
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 올바른 테이블에 트리거 생성
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