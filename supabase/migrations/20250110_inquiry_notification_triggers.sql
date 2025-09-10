-- 문의 알림 시스템 트리거
-- 1. 새 문의 생성 시 → app_admin에게 알림
-- 2. 문의 상태 변경 시 → 문의자에게 알림

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

-- 기존 트리거 삭제
DROP TRIGGER IF EXISTS trigger_notify_new_inquiry ON support_inquiries;

-- 새 문의 생성 트리거
CREATE TRIGGER trigger_notify_new_inquiry
AFTER INSERT ON support_inquiries
FOR EACH ROW
EXECUTE FUNCTION notify_new_inquiry_to_admins();

-- ============================================
-- 2. 문의 상태 변경 시 문의자에게 알림
-- ============================================

CREATE OR REPLACE FUNCTION notify_inquiry_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- 상태가 변경되거나 답변이 추가된 경우만 처리
  -- 특히 resolved(해결됨) 상태일 때 중점적으로 알림
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

-- 기존 트리거 삭제
DROP TRIGGER IF EXISTS trigger_notify_inquiry_response ON support_inquiries;
DROP TRIGGER IF EXISTS trigger_notify_inquiry_status_change ON support_inquiries;

-- 문의 상태 변경 트리거
CREATE TRIGGER trigger_notify_inquiry_status_change
AFTER UPDATE ON support_inquiries
FOR EACH ROW
EXECUTE FUNCTION notify_inquiry_status_change();

-- ============================================
-- 3. 트리거 설명
-- ============================================

COMMENT ON TRIGGER trigger_notify_new_inquiry ON support_inquiries IS 
'새 문의가 생성되면 모든 app_admin 권한자에게 푸시 알림을 전송합니다.';

COMMENT ON TRIGGER trigger_notify_inquiry_status_change ON support_inquiries IS 
'문의 상태가 변경되거나 답변이 추가되면 문의자에게 푸시 알림을 전송합니다.';

-- ============================================
-- 4. 테스트용 쿼리
-- ============================================

/*
-- 새 문의 생성 테스트
INSERT INTO support_inquiries (
  user_id, user_email, user_name, 
  inquiry_type, subject, message
) VALUES (
  auth.uid(), 'test@example.com', '테스트 사용자',
  'other', '테스트 문의', '테스트 내용입니다'
);

-- 문의 상태 변경 테스트
UPDATE support_inquiries 
SET status = 'resolved', 
    resolution_note = '처리 완료되었습니다',
    handled_by = '관리자'
WHERE id = 1;
*/