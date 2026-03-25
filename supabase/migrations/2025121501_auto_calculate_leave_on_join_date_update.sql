-- ====================================================================
-- 입사일(join_date) 변경 시 연차 자동 계산 트리거
-- ====================================================================
-- 목적: employees 테이블의 join_date가 변경되거나 설정될 때
--      신규 직원의 연차를 자동으로 계산하여 업데이트

-- 1. join_date 변경 시 연차 자동 계산 함수
-- ====================================================================
ALTER TABLE public.employees
ADD COLUMN IF NOT EXISTS join_date DATE;

UPDATE public.employees
SET join_date = hire_date
WHERE join_date IS NULL
  AND hire_date IS NOT NULL;

CREATE OR REPLACE FUNCTION public.calculate_annual_leave_on_join_date_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_year INTEGER;
  v_join_year INTEGER;
  v_join_month INTEGER;
  v_remaining_months INTEGER;
  v_calculated_leave INTEGER;
  v_service_years INTEGER;
BEGIN
  -- join_date가 NULL이거나 변경되지 않은 경우 처리하지 않음
  IF NEW.join_date IS NULL THEN
    -- join_date가 NULL이면 연차를 0으로 설정
    NEW.annual_leave_granted_current_year := 0;
    NEW.remaining_annual_leave := 0;
    RETURN NEW;
  END IF;

  -- 현재 연도 계산 (한국 시간 기준)
  v_current_year := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'Asia/Seoul'));
  
  -- 입사년도와 입사월 계산
  v_join_year := EXTRACT(YEAR FROM NEW.join_date);
  v_join_month := EXTRACT(MONTH FROM NEW.join_date);
  
  -- 근속년수 계산
  v_service_years := v_current_year - v_join_year;

  -- 연차 계산 로직
  IF v_service_years = 0 THEN
    -- 신입 직원: 입사월 기준 비례 계산
    -- 입사월부터 연말까지 남은 개월 수
    v_remaining_months := 13 - v_join_month;
    -- 15일 기준으로 비례 계산
    v_calculated_leave := FLOOR((15.0 * v_remaining_months) / 12.0);
  ELSIF v_service_years = 1 OR v_service_years = 2 THEN
    -- 1~2년차: 15일 고정
    v_calculated_leave := 15;
  ELSIF v_service_years >= 3 THEN
    -- 3년차 이상: 법정연차 (2년마다 1개씩 추가, 최대 25개)
    v_calculated_leave := LEAST(25, 15 + FLOOR((v_service_years - 1) / 2.0));
  ELSE
    -- 음수인 경우 (미래 입사일) 연차 0
    v_calculated_leave := 0;
  END IF;

  -- 연차가 변경된 경우에만 업데이트
  -- (join_date가 새로 설정되거나 변경된 경우)
  IF OLD.join_date IS NULL OR OLD.join_date IS DISTINCT FROM NEW.join_date THEN
    NEW.annual_leave_granted_current_year := v_calculated_leave;
    
    -- 잔여연차도 업데이트 (사용연차가 0인 경우)
    IF COALESCE(NEW.used_annual_leave, 0) = 0 THEN
      NEW.remaining_annual_leave := v_calculated_leave;
    ELSE
      -- 사용연차가 있으면 잔여연차 재계산
      NEW.remaining_annual_leave := GREATEST(0, v_calculated_leave - COALESCE(NEW.used_annual_leave, 0));
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 2. 트리거 생성 (BEFORE UPDATE)
-- ====================================================================
DROP TRIGGER IF EXISTS trigger_calculate_leave_on_join_date_update ON employees;
CREATE TRIGGER trigger_calculate_leave_on_join_date_update
  BEFORE UPDATE OF join_date ON employees
  FOR EACH ROW
  WHEN (OLD.join_date IS DISTINCT FROM NEW.join_date)
  EXECUTE FUNCTION public.calculate_annual_leave_on_join_date_change();

-- 3. INSERT 시에도 동작하도록 트리거 추가
-- ====================================================================
DROP TRIGGER IF EXISTS trigger_calculate_leave_on_join_date_insert ON employees;
CREATE TRIGGER trigger_calculate_leave_on_join_date_insert
  BEFORE INSERT ON employees
  FOR EACH ROW
  WHEN (NEW.join_date IS NOT NULL)
  EXECUTE FUNCTION public.calculate_annual_leave_on_join_date_change();

-- 4. 권한 설정
-- ====================================================================
GRANT EXECUTE ON FUNCTION public.calculate_annual_leave_on_join_date_change() TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_annual_leave_on_join_date_change() TO service_role;

-- 5. 코멘트 추가
-- ====================================================================
COMMENT ON FUNCTION public.calculate_annual_leave_on_join_date_change() IS '입사일(join_date) 변경 시 신규 직원의 연차를 자동으로 계산하는 함수';
COMMENT ON TRIGGER trigger_calculate_leave_on_join_date_update ON employees IS '입사일 변경 시 연차 자동 계산 트리거 (UPDATE)';
COMMENT ON TRIGGER trigger_calculate_leave_on_join_date_insert ON employees IS '입사일 설정 시 연차 자동 계산 트리거 (INSERT)';
