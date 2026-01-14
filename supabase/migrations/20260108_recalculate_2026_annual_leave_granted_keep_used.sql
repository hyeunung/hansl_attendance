-- 2026년도 지급연차(annual_leave_granted_current_year) 재계산/일괄 업데이트
-- 요구사항:
-- - "지급연차 로직"으로 2026년도 값을 다시 계산해 employees에 반영
-- - used_annual_leave(사용연차)는 절대 변경하지 않음
--
-- 구현:
-- - public.run_annual_year_update(target_year, reset_usage) 를 사용
-- - reset_usage=false => used_annual_leave 유지 + remaining_annual_leave = max(0, granted - used) 재산출
--
-- 선행조건:
-- - public.run_annual_year_update(integer, boolean) 함수가 이미 존재해야 함

DO $$
BEGIN
  IF to_regprocedure('public.run_annual_year_update(integer, boolean)') IS NULL THEN
    RAISE EXCEPTION
      'Missing function public.run_annual_year_update(integer, boolean). Apply annual_year_update function migration first.';
  END IF;

  PERFORM public.run_annual_year_update(2026, false);
END;
$$;

