-- Fix auto_calc_attendance_status trigger to exempt business trip (출장) employees
--
-- Bug: The trigger only checked the `leave` table for 'half_am' leave before
--      applying the 8:30/9:00 late threshold. Employees on an approved
--      business trip (business_trips table, as requester or companion) who
--      clocked in later in the day (e.g. after returning to the office) had
--      their status overwritten from '출장' to '지각'.
--
-- Fix: Query `business_trips` for an approved/completed trip covering this
--      date where the employee is the requester or a companion. If found,
--      keep the '출장' status instead of applying the late threshold
--      (mark '퇴근' only if clock_out is also present).

CREATE OR REPLACE FUNCTION public.auto_calc_attendance_status()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_position text;
  v_email text;
  v_late_threshold time;
  v_has_half_am boolean := false;
  v_has_biztrip boolean := false;
BEGIN
  -- clock_in이 변경되었거나 clock_out이 변경된 경우만 처리
  IF (NEW.clock_in IS DISTINCT FROM OLD.clock_in) OR (NEW.clock_out IS DISTINCT FROM OLD.clock_out) THEN
    -- clock_in이 있으면 시간 기반 상태 계산
    IF NEW.clock_in IS NOT NULL THEN
      -- 직원 직급 / 이메일 조회
      SELECT position, email INTO v_position, v_email
      FROM employees
      WHERE id = NEW.employee_id;

      -- 해당 일자의 승인된 출장(신청자 또는 동행자) 여부 조회
      SELECT EXISTS (
        SELECT 1
        FROM business_trips bt
        WHERE bt.approval_status IN ('approved', 'completed')
          AND bt.trip_start_date <= NEW.date
          AND bt.trip_end_date   >= NEW.date
          AND (
            bt.requester_id = NEW.employee_id
            OR EXISTS (
              SELECT 1
              FROM jsonb_array_elements(coalesce(bt.companions, '[]'::jsonb)) AS c
              WHERE (c->>'id')::uuid = NEW.employee_id
            )
          )
      ) INTO v_has_biztrip;

      IF v_has_biztrip THEN
        -- 출장자는 지각 판정 대상에서 제외
        IF NEW.clock_out IS NOT NULL THEN
          NEW.status := '퇴근';
        ELSE
          NEW.status := '출장';
        END IF;
      ELSE
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
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;
