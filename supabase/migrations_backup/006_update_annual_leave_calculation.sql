-- 006_update_annual_leave_calculation.sql
-- 새로운 연차 시스템에 맞게 연차 계산 로직 수정

-- 1. 기존 연차 계산 로직을 새로운 시스템으로 업데이트
UPDATE employees 
SET annual_leave_granted_current_year = (
  CASE 
    -- 신입 (입사년도 = 현재년도): 개별 입사 기념일 기준으로 처리
    -- 임시로 15개 설정 (실제로는 Edge Function에서 개별 처리)
    WHEN EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN
      15
    
    -- 1년차 (입사년도 = 현재년도 - 1): 15개 고정
    WHEN EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM join_date) = 1 THEN
      15
    
    -- 2년차 (입사년도 = 현재년도 - 2): 15개 고정
    WHEN EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM join_date) = 2 THEN
      15
    
    -- 3년차 이상: 법정연차 적용 (2년마다 1개씩 추가, 최대 25개)
    ELSE
      LEAST(25, 15 + FLOOR((EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM join_date) - 1) / 2))
  END
)
WHERE join_date IS NOT NULL;

-- 2. join_date가 없는 직원은 기본값 15로 설정
UPDATE employees 
SET annual_leave_granted_current_year = 15
WHERE join_date IS NULL;

-- 3. 신입 직원들을 위한 초기 monthly_attendance 레코드 생성
-- (현재년도 입사자들 대상)
INSERT INTO monthly_attendance (employee_id, year, month, is_full_attendance, earned_leave_days, work_days, attendance_days)
SELECT 
  e.id,
  EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER as year,
  generate_series(
    EXTRACT(MONTH FROM e.join_date)::INTEGER, 
    EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER
  ) as month,
  false as is_full_attendance, -- 초기값 false (나중에 Edge Function에서 계산)
  0 as earned_leave_days,
  0 as work_days,
  0 as attendance_days
FROM employees e
WHERE EXTRACT(YEAR FROM e.join_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND e.join_date IS NOT NULL
ON CONFLICT (employee_id, year, month) DO NOTHING; -- 중복 방지

-- 4. 연차별 계산 확인을 위한 뷰 생성
CREATE OR REPLACE VIEW v_employee_annual_leave_status AS
SELECT 
  e.id,
  e.email,
  e.name,
  e.join_date,
  EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM e.join_date) as service_years,
  CASE 
    WHEN EXTRACT(YEAR FROM e.join_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN '신입'
    WHEN EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM e.join_date) = 1 THEN '1년차'
    WHEN EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM e.join_date) = 2 THEN '2년차'
    ELSE CONCAT(EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM e.join_date), '년차')
  END as service_level,
  e.annual_leave_granted_current_year,
  e.remaining_annual_leave,
  -- 신입 직원의 경우 월별 만근 기록 표시
  CASE 
    WHEN EXTRACT(YEAR FROM e.join_date) = EXTRACT(YEAR FROM CURRENT_DATE) THEN
      (
        SELECT COUNT(*) 
        FROM monthly_attendance ma 
        WHERE ma.employee_id = e.id 
        AND ma.year = EXTRACT(YEAR FROM CURRENT_DATE)
        AND ma.is_full_attendance = true
      )
    ELSE NULL
  END as full_attendance_months
FROM employees e
WHERE e.join_date IS NOT NULL
ORDER BY e.join_date DESC;

-- 완료 메시지
SELECT '✅ 새로운 연차 계산 로직이 적용되었습니다.' as message;