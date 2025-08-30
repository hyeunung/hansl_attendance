-- 004_add_remaining_annual_leave_column.sql
-- employees 테이블에 남은연차 컬럼 추가

-- 1. 컬럼 추가 (이미 존재하면 스킵)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'employees' AND column_name = 'remaining_annual_leave') THEN
    ALTER TABLE employees ADD COLUMN remaining_annual_leave DECIMAL(4,1) DEFAULT 0;
  END IF;
END $$;

-- 2. 기존 직원들의 남은연차 계산해서 업데이트
-- 남은연차 = 지급연차 - 사용연차
UPDATE employees 
SET remaining_annual_leave = (
  COALESCE(annual_leave_granted_current_year, 0) - 
  COALESCE((
    SELECT SUM(
      CASE 
        WHEN l.type = 'annual' THEN 
          (DATE(l.end_date) - DATE(l.start_date) + 1)
        WHEN l.type IN ('half_am', 'half_pm') THEN 0.5
        ELSE 0
      END
    )
    FROM leave l 
    WHERE l.user_email = employees.email 
    AND l.status = 'approved'
    AND EXTRACT(YEAR FROM l.start_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  ), 0)
);

-- 3. 음수가 나올 경우 0으로 처리
UPDATE employees 
SET remaining_annual_leave = 0 
WHERE remaining_annual_leave < 0;

-- 완료 메시지
SELECT '✅ employees 테이블에 remaining_annual_leave 컬럼이 추가되고 계산되었습니다.' as message; 