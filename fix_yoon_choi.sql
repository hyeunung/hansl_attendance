-- 윤은호, 최창열 초과 연차 삭제
BEGIN;

-- 윤은호 3월 24일 오후반차 삭제 (잘못 들어간 데이터)
DELETE FROM leave 
WHERE name = '윤은호' 
  AND start_date = '2025-03-24'
  AND type = 'half_pm';

-- 최창열 6월 23일 연차 삭제 (잘못 들어간 데이터)  
DELETE FROM leave
WHERE name = '최창열'
  AND start_date = '2025-06-23'
  AND type = 'annual';

-- 윤은호 사용연차 업데이트 (10.5일로)
UPDATE employees 
SET used_annual_leave = 10.5,
    remaining_annual_leave = annual_leave_granted_current_year - 10.5
WHERE name = '윤은호';

-- 최창열 사용연차 업데이트 (10일로)
UPDATE employees 
SET used_annual_leave = 10,
    remaining_annual_leave = annual_leave_granted_current_year - 10
WHERE name = '최창열';

COMMIT;

-- 확인 쿼리
SELECT name, COUNT(*) as records,
  SUM(CASE 
    WHEN type = 'annual' THEN 1 
    WHEN type IN ('half_am', 'half_pm') THEN 0.5 
  END) as total_days
FROM leave 
WHERE name IN ('윤은호', '최창열')
  AND status = 'approved' 
  AND start_date >= '2025-01-01' 
  AND start_date <= '2025-08-31'
GROUP BY name;