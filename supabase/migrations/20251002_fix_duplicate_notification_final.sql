-- ============================================================================
-- 연차/출장 중복 알림 최종 해결
-- 
-- 문제: 관리자별로 notifications 테이블에 중복 저장
-- 원인: 트리거와 Edge Function 모두에서 저장
-- 해결: 트리거에서는 Edge Function 호출만, 저장은 Edge Function에서만
-- ============================================================================

-- STEP 1: 기존 함수 삭제
DROP FUNCTION IF EXISTS send_leave_notification CASCADE;
DROP FUNCTION IF EXISTS send_leave_status_change_notification CASCADE;
DROP FUNCTION IF EXISTS send_leave_cancel_notification CASCADE;

-- STEP 2: 개선된 연차 신청 알림 함수 (DB 저장 제거)
CREATE OR REPLACE FUNCTION send_leave_notification()
RETURNS TRIGGER AS $$
DECLARE
    leave_type_label TEXT;
    anon_key TEXT;
    supabase_url TEXT;
BEGIN
    -- app_settings에서 필요한 값 가져오기
    SELECT value INTO anon_key FROM app_settings WHERE key = 'supabase_anon_key';
    SELECT value INTO supabase_url FROM app_settings WHERE key = 'supabase_url';
    
    IF anon_key IS NULL OR supabase_url IS NULL THEN
        RAISE NOTICE 'Missing app settings for notification';
        RETURN NEW;
    END IF;
    
    -- 휴가 유형 레이블
    leave_type_label := CASE 
        WHEN NEW.type = 'annual' THEN '연차'
        WHEN NEW.type IN ('business_trip', 'biztrip') THEN '출장'
        WHEN NEW.type = 'half_am' THEN '오전반차'
        WHEN NEW.type = 'half_pm' THEN '오후반차'
        WHEN NEW.type = 'official' THEN '공가'
        ELSE '휴가'
    END;
    
    -- Edge Function 호출 (skip_db_notification 제거 - Edge Function에서 저장하도록)
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'admin',
            'title', '📝 새로운 ' || leave_type_label || ' 신청',
            'body', NEW.name || '님이 ' || leave_type_label || '을 신청했습니다.\n기간: ' || 
                    TO_CHAR(NEW.start_date, 'MM/DD') || ' ~ ' || TO_CHAR(NEW.end_date, 'MM/DD'),
            'data', jsonb_build_object(
                'type', 'leave_request',
                'leave_id', NEW.id::text,
                'leave_type', NEW.type,
                'user_email', NEW.user_email,
                'name', NEW.name
            ),
            'requester_department', (SELECT department FROM employees WHERE email = NEW.user_email),
            'requester_name', NEW.name
            -- skip_db_notification 제거
        )
    );
    
    -- 트리거에서는 notifications 테이블에 저장하지 않음 (Edge Function에서 처리)
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in send_leave_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 3: 개선된 연차 상태 변경 알림 함수 (DB 저장 제거)
CREATE OR REPLACE FUNCTION send_leave_status_change_notification()
RETURNS TRIGGER AS $$
DECLARE
    leave_type_label TEXT;
    status_korean TEXT;
    status_emoji TEXT;
    anon_key TEXT;
    supabase_url TEXT;
BEGIN
    -- 상태가 변경되지 않았으면 종료
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    -- 승인/반려 상태가 아니면 종료
    IF NEW.status NOT IN ('approved', 'rejected') THEN
        RETURN NEW;
    END IF;
    
    -- app_settings에서 필요한 값 가져오기
    SELECT value INTO anon_key FROM app_settings WHERE key = 'supabase_anon_key';
    SELECT value INTO supabase_url FROM app_settings WHERE key = 'supabase_url';
    
    -- 휴가 유형별 레이블
    leave_type_label := CASE 
        WHEN NEW.type = 'annual' THEN '연차'
        WHEN NEW.type IN ('business_trip', 'biztrip') THEN '출장'
        WHEN NEW.type = 'half_am' THEN '오전반차'
        WHEN NEW.type = 'half_pm' THEN '오후반차'
        WHEN NEW.type = 'official' THEN '공가'
        ELSE '휴가'
    END;
    
    -- 상태별 메시지 설정
    IF NEW.status = 'approved' THEN
        status_korean := '승인';
        status_emoji := '✅';
    ELSE
        status_korean := '반려';
        status_emoji := '❌';
    END IF;
    
    -- 신청자에게 알림 전송
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'user',
            'user_email', NEW.user_email,
            'title', status_emoji || ' ' || leave_type_label || ' ' || status_korean,
            'body', leave_type_label || ' 신청이 ' || status_korean || '되었습니다.',
            'data', jsonb_build_object(
                'type', 'leave_result',
                'leave_id', NEW.id::text,
                'status', NEW.status,
                'leave_type', NEW.type
            )
            -- skip_db_notification 제거
        )
    );
    
    -- 트리거에서는 notifications 테이블에 저장하지 않음 (Edge Function에서 처리)
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in send_leave_status_change_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 4: 연차 취소 알림 함수 (DB 저장 제거)
CREATE OR REPLACE FUNCTION send_leave_cancel_notification()
RETURNS TRIGGER AS $$
DECLARE
    leave_type_label TEXT;
    anon_key TEXT;
    supabase_url TEXT;
BEGIN
    -- deleted 상태가 아니면 종료
    IF NEW.status != 'deleted' THEN
        RETURN NEW;
    END IF;
    
    -- app_settings에서 필요한 값 가져오기
    SELECT value INTO anon_key FROM app_settings WHERE key = 'supabase_anon_key';
    SELECT value INTO supabase_url FROM app_settings WHERE key = 'supabase_url';
    
    IF anon_key IS NULL OR supabase_url IS NULL THEN
        RAISE NOTICE 'Missing app settings for notification';
        RETURN NEW;
    END IF;
    
    -- 휴가 유형 레이블
    leave_type_label := CASE 
        WHEN NEW.type = 'annual' THEN '연차'
        WHEN NEW.type IN ('business_trip', 'biztrip') THEN '출장'
        WHEN NEW.type = 'half_am' THEN '오전반차'
        WHEN NEW.type = 'half_pm' THEN '오후반차'
        WHEN NEW.type = 'official' THEN '공가'
        ELSE '휴가'
    END;
    
    -- Edge Function 호출 (관리자에게 알림)
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'admin',
            'title', '❌ ' || leave_type_label || ' 취소',
            'body', NEW.name || '님이 ' || leave_type_label || '을 취소했습니다.',
            'data', jsonb_build_object(
                'type', 'leave_cancel',
                'leave_id', NEW.id::text,
                'leave_type', NEW.type
            ),
            'requester_department', (SELECT department FROM employees WHERE email = NEW.user_email),
            'requester_name', NEW.name
        )
    );
    
    -- 트리거에서는 notifications 테이블에 저장하지 않음 (Edge Function에서 처리)
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in send_leave_cancel_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 5: 기존 트리거 삭제 및 재생성
DROP TRIGGER IF EXISTS leave_notification_trigger ON leave;
DROP TRIGGER IF EXISTS leave_status_change_notification_trigger ON leave;
DROP TRIGGER IF EXISTS leave_delete_notification ON leave;

-- 신청 알림 트리거
CREATE TRIGGER leave_notification_trigger
    AFTER INSERT ON leave
    FOR EACH ROW
    EXECUTE FUNCTION send_leave_notification();

-- 상태 변경 알림 트리거
CREATE TRIGGER leave_status_change_notification_trigger
    AFTER UPDATE ON leave
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION send_leave_status_change_notification();

-- 취소 알림 트리거
CREATE TRIGGER leave_delete_notification
    AFTER UPDATE ON leave
    FOR EACH ROW
    WHEN (OLD.status != 'deleted' AND NEW.status = 'deleted')
    EXECUTE FUNCTION send_leave_cancel_notification();

-- STEP 6: 트리거 활성화
ALTER TABLE leave ENABLE TRIGGER leave_notification_trigger;
ALTER TABLE leave ENABLE TRIGGER leave_status_change_notification_trigger;
ALTER TABLE leave ENABLE TRIGGER leave_delete_notification;

-- 완료 메시지
SELECT '✅ 연차/출장 중복 알림 문제 최종 해결 완료!' as result;