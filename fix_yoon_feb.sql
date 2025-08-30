-- 윤은호 2월 14일 오후반차 삭제 (엑셀에는 2월 7일만 있음)
BEGIN;

-- 2월 14일 오후반차 삭제
DELETE FROM leave 
WHERE name = '윤은호' 
  AND start_date = '2025-02-14'
  AND type = 'half_pm';

-- 윤은호 사용연차 업데이트 (10.5일로)
UPDATE employees 
SET used_annual_leave = 10.5,
    remaining_annual_leave = annual_leave_granted_current_year - 10.5
WHERE name = '윤은호';

COMMIT;

-- 확인
SELECT 
  name,
  used_annual_leave,
  remaining_annual_leave,
  annual_leave_granted_current_year as granted
FROM employees
WHERE name = '윤은호';