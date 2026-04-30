-- Fix auto_calc_attendance_status trigger to handle 오전반차 (half-day morning leave)
--
-- Bug: Previously the trigger only used 8:30 (general) or 9:00 (아르바이트) as the
--      late threshold. When a 오전반차 employee clocked in (e.g., at 12:00), the
--      trigger overrode whatever status the client/edge function had set and
--      marked them as '지각' because clock_in > 8:30.
--
-- Fix: Query the `leave` table for an approved 'half_am' leave on the record's
--      date for the employee. If found, use 13:30 as the late threshold instead.

CREATE OR REPLACE FUNCTION public.auto_calc_attendance_status()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_position text;
  v_email text;
  v_late_threshold time;
  v_has_half_am boolean := false;
BEGIN
  -- clock_in이 변경되었거나 clock_out이 변경된 경우만 처리
  IF (NEW.clock_in IS DISTINCT FROM OLD.clock_in) OR (NEW.clock_out IS DISTINCT FROM OLD.clock_out) THEN
    -- clock_in이 있으면 시간 기반 상태 계산
    IF NEW.clock_in IS NOT NULL THEN
      -- 직원 직급 / 이메일 조회
      SELECT position, email INTO v_position, v_email
      FROM employees
      WHERE id = NEW.employee_id;

      -- 해당 일자의 승인된 오전반차(half_am) 여부 조회
      SELECT EXISTS (
        SELECT 1
        FROM leave
        WHERE user_email = v_email
          AND status = 'approved'
          AND type = 'half_am'
          AND start_date <= NEW.date
          AND end_date   >= NEW.date
      ) INTO v_has_half_am;

      -- 임계값 결정: 오전반차 13:30 > 아르바이트 09:00 > 일반 08:30
      IF v_has_half_am THEN
        v_late_threshold := '13:30:00'::time;
      ELSIF v_position = '아르바이트' THEN
        v_late_threshold := '09:00:00'::time;
      ELSE
        v_late_threshold := '08:30:00'::time;
      END IF;

      IF NEW.clock_out IS NOT NULL THEN
        NEW.status := '퇴근';
      ELSIF NEW.clock_in::time <= v_late_threshold THEN
        NEW.status := '정상 출근';
      ELSE
        NEW.status := '지각';
      END IF;
    END IF;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;
