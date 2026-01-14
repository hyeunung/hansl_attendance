-- 연차(지급연차) 새해 자동 반영: HTTP 호출(GUC) 없이 DB 내부에서 직접 처리
--
-- 배경:
-- - cron에서 net.http_post를 쓰려면 current_setting('app.settings.*') 값이 필요하지만,
--   Supabase 환경에서 ALTER DATABASE ... SET 권한이 없는 경우가 많아 설정이 불가능함.
-- - 따라서 지급연차 계산을 Postgres 함수로 구현하고, pg_cron이 해당 함수를 직접 호출하게 변경.
--
-- 요구사항:
-- - 매년 KST 1/1 00:00(UTC 12/31 15:00)에 자동 실행
-- - 올해(이미 1/1 경과)에는 1회 catch-up을 자동 실행하되 used_annual_leave는 건드리지 않음

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 기존 HTTP 기반 잡/함수 정리 (있으면 제거)
DO $$
BEGIN
  PERFORM cron.unschedule('annual_year_update_catchup_once');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  PERFORM cron.unschedule('annual_year_update_yearly');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DROP FUNCTION IF EXISTS public.run_annual_year_update_catchup_once();
DROP FUNCTION IF EXISTS public.run_annual_year_update_kst(boolean);
DROP FUNCTION IF EXISTS public.run_annual_year_update(integer, boolean);

-- ====================================================================
-- 연차 계산/세팅 (DB 내부)
-- ====================================================================
CREATE FUNCTION public.run_annual_year_update(target_year integer, reset_usage boolean)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  e RECORD;
  v_join_date date;
  join_y int;
  join_m int;
  service_years int;
  completed_months int;
  remaining_months int;
  prorated int;
  additional_by_fiscal int;
  additional_by_months int;
  additional int;
  new_leave int;
  used numeric;
  new_remaining numeric;
BEGIN
  FOR e IN
    SELECT emp.id, emp.email, emp.join_date, COALESCE(emp.used_annual_leave, 0) AS used_annual_leave
    FROM public.employees emp
    WHERE emp.join_date IS NOT NULL
  LOOP
    v_join_date := e.join_date;
    join_y := EXTRACT(YEAR FROM v_join_date)::int;
    join_m := EXTRACT(MONTH FROM v_join_date)::int;
    service_years := target_year - join_y;

    -- 미래 입사일 등 방어
    IF service_years < 0 THEN
      new_leave := 0;
    ELSIF service_years = 0 THEN
      -- 같은 해 입사: 입사월 기준 비례 (15일 기준)
      remaining_months := 13 - join_m;
      prorated := FLOOR((15.0 * remaining_months) / 12.0);
      new_leave := GREATEST(0, LEAST(15, prorated));
    ELSIF service_years = 1 OR service_years = 2 THEN
      -- 1~2년차: 15일 고정
      new_leave := 15;
    ELSE
      -- 3년차 이상: 24개월 정책(추가분을 실제 완료개월 기준으로 제한)
      -- 완료개월: JS diffCompletedMonths(from=join, to=targetYear-01-01)과 동일
      completed_months := (target_year - join_y) * 12 + (1 - join_m);

      additional_by_fiscal := FLOOR((service_years - 1) / 2.0);
      additional_by_months := GREATEST(0, FLOOR(completed_months / 24.0)); -- 24개월→1, 48개월→2...
      additional := LEAST(additional_by_fiscal, additional_by_months);

      new_leave := LEAST(25, 15 + additional);
    END IF;

    used := e.used_annual_leave;
    new_remaining := CASE WHEN reset_usage THEN new_leave ELSE GREATEST(0, new_leave - used) END;

    UPDATE public.employees
    SET annual_leave_granted_current_year = new_leave,
        remaining_annual_leave = new_remaining,
        used_annual_leave = CASE WHEN reset_usage THEN 0 ELSE used_annual_leave END
    WHERE id = e.id;
  END LOOP;

  RETURN format('annual_year_update 완료(36개월 정책) (target_year=%s, reset_usage=%s)', target_year, reset_usage);
END;
$$;

-- KST 기준 연도 계산 래퍼(크론용)
CREATE FUNCTION public.run_annual_year_update_kst(reset_usage boolean)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  y int;
BEGIN
  y := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'Asia/Seoul'))::int;
  RETURN public.run_annual_year_update(y, reset_usage);
END;
$$;

-- ====================================================================
-- A) 매년 KST 1/1 00:00 자동 실행 (reset_usage=true)
-- ====================================================================
SELECT cron.schedule(
  'annual_year_update_yearly',
  '0 15 31 12 *', -- UTC 12/31 15:00 == KST 1/1 00:00
  $$ SELECT public.run_annual_year_update_kst(true); $$
);

-- ====================================================================
-- B) 배포 직후 1회 catch-up (reset_usage=false, used 유지)
-- ====================================================================
CREATE FUNCTION public.run_annual_year_update_catchup_once()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.run_annual_year_update_kst(false);
  PERFORM cron.unschedule('annual_year_update_catchup_once');
  RETURN 'annual_year_update catch-up 실행 완료(used 유지)';
END;
$$;

SELECT cron.schedule(
  'annual_year_update_catchup_once',
  '* * * * *',
  $$ SELECT public.run_annual_year_update_catchup_once(); $$
);

-- 확인용:
-- SELECT jobname, schedule, active FROM cron.job WHERE jobname LIKE 'annual_year_update%';
