-- 1. 윤은호 잘못 추가된 7월 데이터 삭제 및 전체 직원 업데이트
BEGIN;

-- 윤은호 7월 18, 21-25일 삭제 (병원이라 회사 처리)
DELETE FROM leave 
WHERE name = '윤은호' 
  AND start_date IN ('2025-07-18', '2025-07-21', '2025-07-22', '2025-07-23', '2025-07-24', '2025-07-25')
  AND type = 'annual';

-- 모든 직원의 employees 테이블 업데이트
-- 실제 DB leave 테이블 기준으로 사용연차 재계산
UPDATE employees e
SET used_annual_leave = COALESCE((
  SELECT SUM(
    CASE 
      WHEN l.type = 'annual' THEN 
        CASE 
          WHEN l.start_date = l.end_date THEN 1
          ELSE (l.end_date - l.start_date + 1)
        END
      WHEN l.type IN ('half_am', 'half_pm') THEN 0.5
      ELSE 0
    END
  )
  FROM leave l
  WHERE l.user_email = e.email
    AND l.status = 'approved'
    AND l.start_date >= '2025-01-01'
    AND l.start_date <= '2025-12-31'
), 0),
remaining_annual_leave = annual_leave_granted_current_year - COALESCE((
  SELECT SUM(
    CASE 
      WHEN l.type = 'annual' THEN 
        CASE 
          WHEN l.start_date = l.end_date THEN 1
          ELSE (l.end_date - l.start_date + 1)
        END
      WHEN l.type IN ('half_am', 'half_pm') THEN 0.5
      ELSE 0
    END
  )
  FROM leave l
  WHERE l.user_email = e.email
    AND l.status = 'approved'
    AND l.start_date >= '2025-01-01'
    AND l.start_date <= '2025-12-31'
), 0);

COMMIT;

-- 확인 쿼리
SELECT 
  e.name,
  e.used_annual_leave,
  e.remaining_annual_leave,
  e.annual_leave_granted_current_year as granted,
  (SELECT COUNT(*) FROM leave l WHERE l.user_email = e.email AND l.status = 'approved' AND EXTRACT(YEAR FROM l.start_date) = 2025) as leave_records
FROM employees e
WHERE e.name NOT IN ('권혁진')
ORDER BY e.name;