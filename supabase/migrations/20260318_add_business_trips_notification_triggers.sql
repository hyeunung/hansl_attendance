-- ============================================================
-- Phase 2: business_trips 테이블용 알림 트리거
-- ============================================================

-- 2-1. 신청 알림 트리거 (INSERT)
-- business_trips INSERT 시 → 부서 관리자에게 FCM 알림
CREATE OR REPLACE FUNCTION send_business_trip_notification()
RETURNS TRIGGER AS $$
DECLARE
  requester_name TEXT;
  requester_dept TEXT;
  requester_email TEXT;
BEGIN
  -- 신청자 정보 조회
  SELECT e.name, e.department, e.email
  INTO requester_name, requester_dept, requester_email
  FROM employees e
  WHERE e.id = NEW.requester_id;

  -- send_fcm_notification Edge Function 호출
  PERFORM net.http_post(
    url := (SELECT value FROM app_settings WHERE key = 'supabase_url') || '/functions/v1/send_fcm_notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT value FROM app_settings WHERE key = 'supabase_service_role_key')
    ),
    body := jsonb_build_object(
      'type', 'admin',
      'title', '✈️ 새로운 출장 신청',
      'body', requester_name || '님이 출장을 신청했습니다. (' || NEW.trip_destination || ', ' || NEW.trip_start_date || ' ~ ' || NEW.trip_end_date || ')',
      'data', jsonb_build_object(
        'type', 'business_trip',
        'business_trip_id', NEW.id::text,
        'requester_email', requester_email,
        'requester_name', requester_name
      ),
      'requester_department', requester_dept,
      'requester_email', requester_email
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER business_trip_notification_trigger
  AFTER INSERT ON business_trips
  FOR EACH ROW
  EXECUTE FUNCTION send_business_trip_notification();


-- 2-2. 승인/반려 알림 트리거 (UPDATE)
-- business_trips.approval_status 변경 시 → 신청자에게 FCM 결과 알림
CREATE OR REPLACE FUNCTION send_business_trip_status_change_notification()
RETURNS TRIGGER AS $$
DECLARE
  requester_email TEXT;
  requester_name TEXT;
  status_label TEXT;
  notification_title TEXT;
  notification_body TEXT;
BEGIN
  -- approval_status가 변경된 경우에만 처리
  IF OLD.approval_status = NEW.approval_status THEN
    RETURN NEW;
  END IF;

  -- 신청자 정보 조회
  SELECT e.email, e.name
  INTO requester_email, requester_name
  FROM employees e
  WHERE e.id = NEW.requester_id;

  -- 상태 라벨
  IF NEW.approval_status = 'approved' THEN
    status_label := '승인';
    notification_title := '✅ 출장 신청 승인';
    notification_body := requester_name || '님의 출장 신청(' || NEW.trip_destination || ')이 승인되었습니다.';
  ELSIF NEW.approval_status = 'rejected' THEN
    status_label := '반려';
    notification_title := '❌ 출장 신청 반려';
    notification_body := requester_name || '님의 출장 신청(' || NEW.trip_destination || ')이 반려되었습니다.';
    IF NEW.rejection_reason IS NOT NULL THEN
      notification_body := notification_body || ' 사유: ' || NEW.rejection_reason;
    END IF;
  ELSE
    RETURN NEW;
  END IF;

  -- 신청자에게 결과 알림
  PERFORM net.http_post(
    url := (SELECT value FROM app_settings WHERE key = 'supabase_url') || '/functions/v1/send_fcm_notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT value FROM app_settings WHERE key = 'supabase_service_role_key')
    ),
    body := jsonb_build_object(
      'type', 'user',
      'user_email', requester_email,
      'title', notification_title,
      'body', notification_body,
      'data', jsonb_build_object(
        'type', 'leave_result',
        'business_trip_id', NEW.id::text,
        'status', NEW.approval_status,
        'requester_email', requester_email
      )
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER business_trip_status_change_notification_trigger
  AFTER UPDATE ON business_trips
  FOR EACH ROW
  EXECUTE FUNCTION send_business_trip_status_change_notification();


-- 2-3. 승인 시 동행자 attendance_records 생성 + MAKE 웹훅 이메일 트리거
CREATE OR REPLACE FUNCTION process_business_trip_approval()
RETURNS TRIGGER AS $$
DECLARE
  requester_name TEXT;
  requester_dept TEXT;
  companion JSONB;
  companion_employee RECORD;
  trip_date DATE;
  webhook_url TEXT;
  all_travelers TEXT;
BEGIN
  -- approval_status가 approved로 변경된 경우에만 처리
  IF OLD.approval_status = 'approved' OR NEW.approval_status != 'approved' THEN
    RETURN NEW;
  END IF;

  -- 신청자 정보
  SELECT e.name, e.department
  INTO requester_name, requester_dept
  FROM employees e
  WHERE e.id = NEW.requester_id;

  -- 동행자 attendance_records 생성 (companions jsonb에서)
  IF NEW.companions IS NOT NULL AND jsonb_array_length(NEW.companions) > 0 THEN
    FOR companion IN SELECT * FROM jsonb_array_elements(NEW.companions) LOOP
      -- 동행자 employee 정보 조회
      SELECT * INTO companion_employee
      FROM employees
      WHERE name = companion->>'name'
        AND is_active = true
      LIMIT 1;

      IF companion_employee.id IS NOT NULL THEN
        -- 출장 기간의 각 날짜에 대해 attendance_records 생성
        FOR trip_date IN
          SELECT generate_series(NEW.trip_start_date, NEW.trip_end_date, '1 day'::interval)::date
        LOOP
          -- 주말 제외 (0=일요일, 6=토요일)
          IF EXTRACT(DOW FROM trip_date) NOT IN (0, 6) THEN
            INSERT INTO attendance_records (date, employee_id, employee_name, user_email, status, created_at)
            VALUES (trip_date, companion_employee.id, companion_employee.name, companion_employee.email, '출장', now())
            ON CONFLICT (employee_id, date) DO UPDATE SET status = '출장';
          END IF;
        END LOOP;
      END IF;
    END LOOP;
  END IF;

  -- MAKE 웹훅 호출 (전 직원 이메일 발송)
  SELECT value INTO webhook_url FROM app_settings WHERE key = 'make_webhook_url';

  IF webhook_url IS NOT NULL THEN
    -- 출장자 목록 구성 (신청자 + 동행자)
    all_travelers := requester_name;
    IF NEW.companions IS NOT NULL AND jsonb_array_length(NEW.companions) > 0 THEN
      all_travelers := all_travelers || ', ' || (
        SELECT string_agg(comp->>'name', ', ')
        FROM jsonb_array_elements(NEW.companions) AS comp
      );
    END IF;

    PERFORM net.http_post(
      url := webhook_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := jsonb_build_object(
        'type', 'business_trip_approved',
        'trip_code', NEW.trip_code,
        'requester_name', requester_name,
        'department', requester_dept,
        'destination', NEW.trip_destination,
        'purpose', NEW.trip_purpose,
        'start_date', NEW.trip_start_date::text,
        'end_date', NEW.trip_end_date::text,
        'travelers', all_travelers
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER business_trip_approval_trigger
  AFTER UPDATE ON business_trips
  FOR EACH ROW
  EXECUTE FUNCTION process_business_trip_approval();


-- 2-4. 기존 leave 트리거에서 biztrip 조건 제거
-- (leave_notification_trigger와 leave_status_change_notification_trigger는
--  이미 type='biztrip_migrated'로 변경되어 자동 필터링됨)
-- business_trip_companion_trigger 비활성화
DO $$
BEGIN
  -- business_trip_companion_trigger가 존재하면 비활성화
  IF EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'business_trip_companion_trigger'
  ) THEN
    ALTER TABLE leave DISABLE TRIGGER business_trip_companion_trigger;
    RAISE NOTICE 'business_trip_companion_trigger 비활성화 완료';
  END IF;
END $$;
