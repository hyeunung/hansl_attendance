-- 신입 직원 연차 자동 수정 SQL
-- 실행일: 2025년 8월 5일

-- 1. 현재 상태 확인
SELECT 
  '=== 수정 전 현재 상태 ===' as status;

SELECT 
  email,
  name,
  join_date,
  EXTRACT(MONTH FROM join_date) as join_month,
  EXTRACT(MONTH FROM CURRENT_DATE) as current_month,
  annual_leave_granted_current_year as current_leave,
  EXTRACT(MONTH FROM CURRENT_DATE) - EXTRACT(MONTH FROM join_date) - 1 as should_be_months
FROM employees 
WHERE EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND join_date IS NOT NULL
ORDER BY join_date;

-- 2. 연차 수정 (입사월 제외, 지나간 월만 카운팅)
SELECT 
  '=== 연차 수정 실행 ===' as status;

UPDATE employees 
SET annual_leave_granted_current_year = (
  GREATEST(0, 
    EXTRACT(MONTH FROM CURRENT_DATE) - EXTRACT(MONTH FROM join_date) - 1
  )
)
WHERE EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND join_date IS NOT NULL;

-- 3. 남은 연차 재계산
SELECT 
  '=== 남은 연차 재계산 실행 ===' as status;

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

-- 4. 수정 결과 확인
SELECT 
  '=== 수정 후 최종 결과 ===' as status;

SELECT 
  email,
  name,
  join_date,
  annual_leave_granted_current_year,
  remaining_annual_leave,
  CASE 
    WHEN EXTRACT(MONTH FROM join_date) = 3 THEN '3월 입사 → 4개월 지남 → 4개 연차'
    WHEN EXTRACT(MONTH FROM join_date) = 6 THEN '6월 입사 → 1개월 지남 → 1개 연차'
    WHEN EXTRACT(MONTH FROM join_date) = 7 THEN '7월 입사 → 0개월 지남 → 0개 연차'
    ELSE CONCAT(EXTRACT(MONTH FROM join_date), '월 입사')
  END as explanation
FROM employees 
WHERE EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND join_date IS NOT NULL
ORDER BY join_date;

-- 5. 완료 메시지
SELECT 
  '✅ 신입 직원 연차 수정이 완료되었습니다!' as message,
  CURRENT_DATE as execution_date,
  EXTRACT(MONTH FROM CURRENT_DATE) as current_month;