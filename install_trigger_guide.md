# DB 트리거 설치 가이드

## 문제 상황
- 연차 신청 시 알림이 오지 않음
- DB 트리거가 production DB에 설치되어 있지 않을 가능성

## 해결 방법

### 1. Supabase Studio에서 SQL 실행
1. https://supabase.com/dashboard 접속
2. HANSL 프로젝트 선택
3. 왼쪽 메뉴에서 "SQL Editor" 클릭
4. 아래 SQL을 복사해서 실행:

```sql
-- 기존 트리거 삭제 (있다면)
DROP TRIGGER IF EXISTS leave_notification_trigger ON leave;
DROP FUNCTION IF EXISTS send_leave_notification();

-- 알림 전송 함수 생성
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
        url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78'
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

-- 트리거 생성 (INSERT 시에만 실행)
CREATE TRIGGER leave_notification_trigger
    AFTER INSERT ON leave
    FOR EACH ROW
    EXECUTE FUNCTION send_leave_notification();
```

### 2. 설치 확인
설치 후 아래 SQL로 트리거가 제대로 설치되었는지 확인:

```sql
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger 
WHERE tgrelid = 'public.leave'::regclass;
```

### 3. 테스트
트리거 설치 후 Flutter 앱에서 연차 신청을 해보면 알림이 와야 함.

## 추가로 해결된 문제

### 승인 화면 새로고침 문제
`lib/screens/approval/approval_screen.dart`에서 RefreshIndicator가 잘못된 메서드를 호출하고 있었음:
- ❌ 기존: `fetchMyLeaves()` - 개인 연차만 가져옴
- ✅ 수정: `fetchAllLeaves()` - 모든 연차/출장 신청 가져옴

이제 승인 화면에서 아래로 당겨서 새로고침하면 제대로 동작할 것입니다.