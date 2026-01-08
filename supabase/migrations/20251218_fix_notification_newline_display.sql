-- 연차/출장 알림에서 실제 줄바꿈이 되도록 E'\n' 사용

-- STEP 1: 연차/출장 신청 알림 함수 수정
CREATE OR REPLACE FUNCTION send_leave_notification()
RETURNS TRIGGER AS $$
DECLARE
    leave_type_label TEXT;
    supabase_url TEXT;
    anon_key TEXT;
    notification_body TEXT;
BEGIN
    -- 새 신청만 처리
    IF TG_OP != 'INSERT' THEN
        RETURN NEW;
    END IF;
    
    -- 연차 타입 라벨 매핑
    leave_type_label := CASE NEW.type
        WHEN 'annual' THEN '연차'
        WHEN 'half_am' THEN '오전반차'
        WHEN 'half_pm' THEN '오후반차'
        WHEN 'biztrip' THEN '출장'
        ELSE NEW.type
    END;
    
    -- 환경변수에서 URL과 키 가져오기
    supabase_url := current_setting('app.supabase_url', true);
    anon_key := current_setting('app.supabase_anon_key', true);
    
    IF supabase_url IS NULL OR anon_key IS NULL THEN
        RAISE WARNING 'Missing environment variables for notification';
        RETURN NEW;
    END IF;
    
    -- 알림 본문 생성 (E'\n'으로 실제 줄바꿈)
    notification_body := NEW.name || '님이 ' || leave_type_label || '을 신청했습니다.' || E'\n' ||
                         '기간: ' || TO_CHAR(NEW.start_date, 'MM/DD') || ' ~ ' || TO_CHAR(NEW.end_date, 'MM/DD');
    
    -- Edge Function 호출
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'admin',
            'title', '📝 새로운 ' || leave_type_label || ' 신청',
            'body', notification_body,
            'data', jsonb_build_object(
                'type', 'leave_request',
                'leave_id', NEW.id::text,
                'leave_type', NEW.type,
                'user_email', NEW.user_email,
                'name', NEW.name
            ),
            'requester_department', (SELECT department FROM employees WHERE email = NEW.user_email),
            'requester_name', NEW.name
        )
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in send_leave_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 2: 연차 상태 변경 알림 함수 수정
CREATE OR REPLACE FUNCTION send_leave_status_change_notification()
RETURNS TRIGGER AS $$
DECLARE
    leave_type_label TEXT;
    status_label TEXT;
    status_emoji TEXT;
    supabase_url TEXT;
    anon_key TEXT;
    notification_body TEXT;
BEGIN
    -- 상태 변경만 처리 (pending -> approved 또는 pending -> rejected)
    IF TG_OP != 'UPDATE' THEN
        RETURN NEW;
    END IF;
    
    -- 상태가 변경되지 않았으면 무시
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    -- pending에서 approved 또는 rejected로 변경된 경우만 처리
    IF OLD.status != 'pending' OR (NEW.status != 'approved' AND NEW.status != 'rejected') THEN
        RETURN NEW;
    END IF;
    
    -- 연차 타입 라벨 매핑
    leave_type_label := CASE NEW.type
        WHEN 'annual' THEN '연차'
        WHEN 'half_am' THEN '오전반차'
        WHEN 'half_pm' THEN '오후반차'
        WHEN 'biztrip' THEN '출장'
        ELSE NEW.type
    END;
    
    -- 상태 라벨과 이모지 설정
    IF NEW.status = 'approved' THEN
        status_label := '승인';
        status_emoji := '✅';
    ELSE
        status_label := '반려';
        status_emoji := '❌';
    END IF;
    
    -- 환경변수에서 URL과 키 가져오기
    supabase_url := current_setting('app.supabase_url', true);
    anon_key := current_setting('app.supabase_anon_key', true);
    
    IF supabase_url IS NULL OR anon_key IS NULL THEN
        RAISE WARNING 'Missing environment variables for notification';
        RETURN NEW;
    END IF;
    
    -- 알림 본문 생성 (E'\n'으로 실제 줄바꿈)
    notification_body := leave_type_label || ' 신청이 ' || status_label || '되었습니다.' || E'\n' ||
                         '기간: ' || TO_CHAR(NEW.start_date, 'MM/DD') || ' ~ ' || TO_CHAR(NEW.end_date, 'MM/DD');
    
    -- Edge Function 호출 - 요청자에게 알림
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'user',
            'title', status_emoji || ' ' || leave_type_label || ' ' || status_label,
            'body', notification_body,
            'data', jsonb_build_object(
                'type', 'leave_status_change',
                'leave_id', NEW.id::text,
                'leave_type', NEW.type,
                'status', NEW.status,
                'user_email', NEW.user_email,
                'name', NEW.name
            ),
            'user_email', NEW.user_email
        )
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in send_leave_status_change_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 3: 연차 취소 알림 함수 수정
CREATE OR REPLACE FUNCTION send_leave_cancel_notification()
RETURNS TRIGGER AS $$
DECLARE
    leave_type_label TEXT;
    supabase_url TEXT;
    anon_key TEXT;
    notification_body TEXT;
BEGIN
    -- 삭제만 처리
    IF TG_OP != 'DELETE' THEN
        RETURN OLD;
    END IF;
    
    -- 연차 타입 라벨 매핑
    leave_type_label := CASE OLD.type
        WHEN 'annual' THEN '연차'
        WHEN 'half_am' THEN '오전반차'
        WHEN 'half_pm' THEN '오후반차'
        WHEN 'biztrip' THEN '출장'
        ELSE OLD.type
    END;
    
    -- 환경변수에서 URL과 키 가져오기
    supabase_url := current_setting('app.supabase_url', true);
    anon_key := current_setting('app.supabase_anon_key', true);
    
    IF supabase_url IS NULL OR anon_key IS NULL THEN
        RAISE WARNING 'Missing environment variables for notification';
        RETURN OLD;
    END IF;
    
    -- 알림 본문 생성 (E'\n'으로 실제 줄바꿈)
    notification_body := OLD.name || '님이 ' || leave_type_label || ' 신청을 취소했습니다.' || E'\n' ||
                         '기간: ' || TO_CHAR(OLD.start_date, 'MM/DD') || ' ~ ' || TO_CHAR(OLD.end_date, 'MM/DD');
    
    -- Edge Function 호출 - 관리자에게 알림
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'admin',
            'title', '🗑️ ' || leave_type_label || ' 신청 취소',
            'body', notification_body,
            'data', jsonb_build_object(
                'type', 'leave_cancelled',
                'leave_type', OLD.type,
                'user_email', OLD.user_email,
                'name', OLD.name
            ),
            'requester_department', (SELECT department FROM employees WHERE email = OLD.user_email),
            'requester_name', OLD.name
        )
    );
    
    RETURN OLD;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in send_leave_cancel_notification: %', SQLERRM;
        RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
