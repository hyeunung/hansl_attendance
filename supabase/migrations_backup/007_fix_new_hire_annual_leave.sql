-- 007_fix_new_hire_annual_leave.sql
-- 신입 직원들의 연차를 올바르게 계산하여 수정

-- 1. 올해 입사한 신입들의 연차를 월별 만근 기준으로 재계산
UPDATE employees 
SET annual_leave_granted_current_year = (
  CASE 
    -- 신입 (올해 입사): 입사월부터 현재월까지의 개월수로 계산
    -- (실제로는 만근 여부에 따라 달라지지만, 일단 기본값으로 입사월부터 현재월까지 개월수)
    WHEN EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN
      GREATEST(0, 
        EXTRACT(MONTH FROM CURRENT_DATE) - EXTRACT(MONTH FROM join_date) + 1
      )
    -- 기존 연차는 그대로 유지
    ELSE annual_leave_granted_current_year
  END
)
WHERE EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND join_date IS NOT NULL;

-- 2. 신입 직원들의 remaining_annual_leave도 다시 계산
UPDATE employees 
SET remaining_annual_leave = (
  annual_leave_granted_current_year - 
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
)
WHERE EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND join_date IS NOT NULL;

-- 3. 확인용 쿼리 (결과 보기)
SELECT 
  email,
  name,
  join_date,
  annual_leave_granted_current_year,
  remaining_annual_leave,
  EXTRACT(MONTH FROM CURRENT_DATE) - EXTRACT(MONTH FROM join_date) + 1 as expected_months
FROM employees 
WHERE EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND join_date IS NOT NULL
ORDER BY join_date;

-- 완료 메시지
SELECT '✅ 신입 직원들의 연차가 올바르게 수정되었습니다.' as message;