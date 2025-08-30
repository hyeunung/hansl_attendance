-- 003_add_annual_leave_granted_column.sql
-- employees 테이블에 현재년도 지급연차 컬럼 추가

-- 1. 컬럼 추가
ALTER TABLE employees ADD COLUMN annual_leave_granted_current_year INTEGER;

-- 2. 기존 직원들의 현재년도 지급연차 계산해서 업데이트
UPDATE employees 
SET annual_leave_granted_current_year = (
  CASE 
    -- 1년차 (입사년도 = 현재년도): 입사월부터 연말까지 월수 (최대 11개)
    WHEN EXTRACT(YEAR FROM hire_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN
      LEAST(11, 12 - EXTRACT(MONTH FROM hire_date) + 1)
    -- 2년차 이상: 15 + ((근속년수-2)/2의 정수부분)
    ELSE
      15 + GREATEST(0, (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM hire_date) + 1 - 2) / 2)::INTEGER
  END
)
WHERE hire_date IS NOT NULL;

-- 3. hire_date가 없는 직원은 기본값 15로 설정
UPDATE employees 
SET annual_leave_granted_current_year = 15
WHERE hire_date IS NULL;

-- 완료 메시지
SELECT '✅ employees 테이블에 annual_leave_granted_current_year 컬럼이 추가되었습니다.' as message; 