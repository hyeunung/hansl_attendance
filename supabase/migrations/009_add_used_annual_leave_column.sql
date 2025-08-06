-- 009_add_used_annual_leave_column.sql
-- employees 테이블에 사용연차 컬럼 추가

-- 1. 사용연차 컬럼 추가
ALTER TABLE employees ADD COLUMN used_annual_leave_current_year DECIMAL(4,1) DEFAULT 0;

-- 2. 기존 직원들의 사용연차 계산해서 업데이트
UPDATE employees 
SET used_annual_leave_current_year = (
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

-- 3. 잔여연차 재계산 (지급연차 - 사용연차)
UPDATE employees 
SET remaining_annual_leave = (
  COALESCE(annual_leave_granted_current_year, 0) - 
  COALESCE(used_annual_leave_current_year, 0)
);

-- 4. 음수가 나올 경우 0으로 처리
UPDATE employees 
SET remaining_annual_leave = 0 
WHERE remaining_annual_leave < 0;

-- 5. 확인용 쿼리
SELECT 
  email,
  name,
  annual_leave_granted_current_year as granted,
  used_annual_leave_current_year as used,
  remaining_annual_leave as remaining
FROM employees 
WHERE email IS NOT NULL
ORDER BY name;

-- 완료 메시지
SELECT '✅ employees 테이블에 used_annual_leave_current_year 컬럼이 추가되고 계산되었습니다.' as message;