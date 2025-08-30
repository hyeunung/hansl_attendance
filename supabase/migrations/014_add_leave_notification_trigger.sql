-- leave 테이블에 새로운 연차/출장 신청이 들어올 때 FCM 알림을 보내는 트리거 생성

-- 1. 알림 전송 함수 생성
CREATE OR REPLACE FUNCTION send_leave_notification()
RETURNS TRIGGER AS $$
DECLARE
    requester_dept TEXT;
    requester_roles TEXT[];
    is_manager_req BOOLEAN := FALSE;
BEGIN
    -- 신청자의 부서와 역할 조회
    SELECT department, attendance_role 
    INTO requester_dept, requester_roles
    FROM employees 
    WHERE email = NEW.user_email;
    
    -- 매니저 역할 체크
    IF requester_roles IS NOT NULL THEN
        is_manager_req := (
            'admin' = ANY(requester_roles) OR 
            'superadmin' = ANY(requester_roles) OR
            '개발3팀_manager' = ANY(requester_roles) OR
            'CAD_manager' = ANY(requester_roles) OR
            '개발팀_manager' = ANY(requester_roles) OR
            '경영지원팀_manager' = ANY(requester_roles) OR
            '연구소_manager' = ANY(requester_roles)
        );
    END IF;
    
    -- FCM 알림 전송 (비동기)
    PERFORM net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
        ),
        body := jsonb_build_object(
            'type', 'admin',
            'title', CASE 
                WHEN NEW.type = 'annual' THEN '연차 신청'
                WHEN NEW.type = 'biztrip' THEN '출장 신청'
                ELSE '휴가 신청'
            END,
            'body', NEW.name || '님이 ' || 
                CASE 
                    WHEN NEW.type = 'annual' THEN '연차를'
                    WHEN NEW.type = 'biztrip' THEN '출장을'
                    ELSE '휴가를'
                END || ' 신청했습니다. (' || NEW.start_date || ' ~ ' || NEW.end_date || ')',
            'data', jsonb_build_object(
                'leave_id', NEW.id::text,
                'user_email', NEW.user_email,
                'type', NEW.type,
                'start_date', NEW.start_date::text,
                'end_date', NEW.end_date::text
            ),
            'requester_department', requester_dept,
            'requester_email', NEW.user_email,
            'is_manager_request', is_manager_req
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 트리거 생성 (INSERT 시에만 실행)
DROP TRIGGER IF EXISTS leave_notification_trigger ON leave;
CREATE TRIGGER leave_notification_trigger
    AFTER INSERT ON leave
    FOR EACH ROW
    EXECUTE FUNCTION send_leave_notification();

-- 3. 필요한 설정 추가 (Supabase URL과 Service Role Key)
-- 이 설정들은 실제 운영 환경에서는 환경변수로 관리됨
-- ALTER DATABASE postgres SET app.supabase_url = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
-- ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key';