-- 008_correct_new_hire_calculation.sql
-- 신입 직원 연차 계산 공식 수정 (연도 바뀜 고려)

-- 1. 올해 입사한 신입들의 연차를 올바르게 계산
UPDATE employees 
SET annual_leave_granted_current_year = (
  CASE 
    WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= EXTRACT(MONTH FROM join_date) THEN
      -- 같은 연도 내에서의 계산 (예: 3월 입사 → 6월 현재 = 4개월)
      EXTRACT(MONTH FROM CURRENT_DATE) - EXTRACT(MONTH FROM join_date) + 1
    ELSE
      -- 연도가 바뀐 경우의 계산 (예: 3월 입사 → 다음해 1월 = 11개월)
      (12 - EXTRACT(MONTH FROM join_date) + 1) + EXTRACT(MONTH FROM CURRENT_DATE)
  END
)
WHERE EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND join_date IS NOT NULL;

-- 2. 남은 연차도 재계산
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

-- 3. 계산 확인용 쿼리
SELECT 
  email,
  name,
  join_date,
  EXTRACT(MONTH FROM join_date) as join_month,
  EXTRACT(MONTH FROM CURRENT_DATE) as current_month,
  CASE 
    WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= EXTRACT(MONTH FROM join_date) THEN
      EXTRACT(MONTH FROM CURRENT_DATE) - EXTRACT(MONTH FROM join_date) + 1
    ELSE
      (12 - EXTRACT(MONTH FROM join_date) + 1) + EXTRACT(MONTH FROM CURRENT_DATE)
  END as calculated_months,
  annual_leave_granted_current_year,
  remaining_annual_leave
FROM employees 
WHERE EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND join_date IS NOT NULL
ORDER BY join_date;

-- 완료 메시지
SELECT '✅ 신입 직원 연차 계산이 올바르게 수정되었습니다.' as message;