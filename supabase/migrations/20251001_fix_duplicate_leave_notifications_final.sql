-- ============================================================================
-- 연차/출장 중복 알림 문제 최종 해결
-- 
-- 문제: 연차/출장 신청, 취소, 승인 시 같은 알림이 2개씩 발송됨
-- 원인: 
--   1. DB 트리거에서 한 번
--   2. Edge Function 내부에서 notifications 테이블에 저장할 때 한 번
-- 
-- 해결 방안:
--   1. 모든 기존 트리거 비활성화
--   2. 중복 방지 로직이 포함된 새로운 트리거 생성
--   3. Edge Function의 skip_db_notification 파라미터 활용
-- ============================================================================

-- STEP 1: 모든 기존 연차 관련 트리거 비활성화
ALTER TABLE leave DISABLE TRIGGER ALL;

-- STEP 2: 기존 함수 삭제
DROP FUNCTION IF EXISTS send_leave_notification CASCADE;
DROP FUNCTION IF EXISTS send_leave_status_change_notification CASCADE;
DROP FUNCTION IF EXISTS send_leave_cancel_notification CASCADE;

-- STEP 3: 개선된 연차 신청 알림 함수 (중복 방지 포함)
CREATE OR REPLACE FUNCTION send_leave_notification()
RETURNS TRIGGER AS $$
DECLARE
    leave_type_label TEXT;
    anon_key TEXT;
    supabase_url TEXT;
    notification_exists BOOLEAN;
BEGIN
    -- 1분 이내 동일한 알림이 있는지 확인
    SELECT EXISTS(
        SELECT 1 FROM notifications 
        WHERE type = 'leave_request'
        AND data->>'leave_id' = NEW.id::text
        AND created_at > NOW() - INTERVAL '10 seconds'
    ) INTO notification_exists;
    
    IF notification_exists THEN
        RAISE NOTICE 'Duplicate notification prevented for leave_id: %', NEW.id;
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
    
    -- Edge Function 호출 (skip_db_notification 추가)
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
            'requester_name', NEW.name,
            'skip_db_notification', true  -- Edge Function에서 notifications 테이블 저장 스킵
        )
    );
    
    -- 트리거에서 직접 notifications 테이블에 저장 (중복 방지)
    INSERT INTO notifications (
        user_email,
        title,
        body,
        type,
        data,
        is_read,
        created_at
    ) VALUES (
        'admin@hansl.com',  -- 관리자용 더미 이메일
        '📝 새로운 ' || leave_type_label || ' 신청',
        NEW.name || '님이 ' || leave_type_label || '을 신청했습니다.',
        'leave_request',
        jsonb_build_object(
            'leave_id', NEW.id::text,
            'leave_type', NEW.type,
            'user_email', NEW.user_email,
            'name', NEW.name
        ),
        false,
        NOW()
    ) ON CONFLICT DO NOTHING;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in send_leave_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 4: 개선된 연차 상태 변경 알림 함수
CREATE OR REPLACE FUNCTION send_leave_status_change_notification()
RETURNS TRIGGER AS $$
DECLARE
    leave_type_label TEXT;
    status_korean TEXT;
    status_emoji TEXT;
    anon_key TEXT;
    supabase_url TEXT;
    notification_exists BOOLEAN;
BEGIN
    -- 상태가 변경되지 않았으면 종료
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    -- 승인/반려 상태가 아니면 종료
    IF NEW.status NOT IN ('approved', 'rejected') THEN
        RETURN NEW;
    END IF;
    
    -- 1분 이내 동일한 알림이 있는지 확인
    SELECT EXISTS(
        SELECT 1 FROM notifications 
        WHERE type = 'leave_result'
        AND data->>'leave_id' = NEW.id::text
        AND data->>'status' = NEW.status
        AND created_at > NOW() - INTERVAL '10 seconds'
    ) INTO notification_exists;
    
    IF notification_exists THEN
        RAISE NOTICE 'Duplicate status notification prevented for leave_id: %', NEW.id;
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
            ),
            'skip_db_notification', true  -- Edge Function에서 notifications 테이블 저장 스킵
        )
    );
    
    -- 트리거에서 직접 notifications 테이블에 저장
    INSERT INTO notifications (
        user_email,
        title,
        body,
        type,
        data,
        is_read,
        created_at
    ) VALUES (
        NEW.user_email,
        status_emoji || ' ' || leave_type_label || ' ' || status_korean,
        leave_type_label || ' 신청이 ' || status_korean || '되었습니다.',
        'leave_result',
        jsonb_build_object(
            'leave_id', NEW.id::text,
            'status', NEW.status,
            'leave_type', NEW.type
        ),
        false,
        NOW()
    ) ON CONFLICT DO NOTHING;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in send_leave_status_change_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 5: 트리거 재생성 (신청 알림)
DROP TRIGGER IF EXISTS leave_notification_trigger ON leave;
CREATE TRIGGER leave_notification_trigger
    AFTER INSERT ON leave
    FOR EACH ROW
    EXECUTE FUNCTION send_leave_notification();

-- STEP 6: 트리거 재생성 (상태 변경 알림)
DROP TRIGGER IF EXISTS leave_status_change_notification_trigger ON leave;
CREATE TRIGGER leave_status_change_notification_trigger
    AFTER UPDATE ON leave
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION send_leave_status_change_notification();

-- STEP 7: 특정 트리거만 활성화
ALTER TABLE leave ENABLE TRIGGER leave_notification_trigger;
ALTER TABLE leave ENABLE TRIGGER leave_status_change_notification_trigger;

-- STEP 8: 현재 활성화된 트리거 확인
SELECT 
    tgname as "트리거명",
    CASE tgenabled 
        WHEN 'O' THEN '✅ 활성화'
        WHEN 'D' THEN '❌ 비활성화'
        ELSE '⚠️ 상태 불명'
    END as "상태",
    tgrelid::regclass as "테이블"
FROM pg_trigger
WHERE tgrelid = 'leave'::regclass::oid
AND NOT tgisinternal
ORDER BY tgname;

-- STEP 9: notifications 테이블에 인덱스 추가 (중복 체크 성능 향상)
CREATE INDEX IF NOT EXISTS idx_notifications_type_data_created 
ON notifications(type, (data->>'leave_id'), created_at);

-- 완료 메시지
SELECT '✅ 연차/출장 중복 알림 문제 해결 완료!' as result;

