-- 엑셀과 정확히 일치시키기 위한 수정
BEGIN;

-- 강영은: 3월 25일 연차 삭제 (반차 2개만 남김), 6월 18일 연차 삭제 (반차 2개만 남김)
DELETE FROM leave 
WHERE name = '강영은' 
  AND start_date = '2025-03-25'
  AND type = 'annual';

DELETE FROM leave 
WHERE name = '강영은' 
  AND start_date = '2025-06-18'
  AND type = 'annual';

-- 이정화: 2월 24일 오후반차, 26일 연차 삭제
DELETE FROM leave 
WHERE name = '이정화' 
  AND start_date = '2025-02-24'
  AND type = 'half_pm';

DELETE FROM leave 
WHERE name = '이정화' 
  AND start_date = '2025-02-26'
  AND type = 'annual';

-- 김경태: 4월 4일 연차 삭제
DELETE FROM leave 
WHERE name = '김경태' 
  AND start_date = '2025-04-04'
  AND type = 'annual';

-- 나유성: 1월 17일 연차 삭제 (반차 2개만 남김)
DELETE FROM leave 
WHERE name = '나유성' 
  AND start_date = '2025-01-17'
  AND type = 'annual';

-- 이재형: 2월 20일 연차 삭제 (28일만 남김)
DELETE FROM leave 
WHERE name = '이재형' 
  AND start_date = '2025-02-20'
  AND type = 'annual';

-- 이한빈: 4월 2일 연차 삭제 (4일만 남김)
DELETE FROM leave 
WHERE name = '이한빈' 
  AND start_date = '2025-04-02'
  AND type = 'annual';

-- 정현웅: 8월 21일 연차 삭제 (엑셀에 없음)
DELETE FROM leave 
WHERE name = '정현웅' 
  AND start_date = '2025-08-21'
  AND type = 'annual';

-- 백현덕: 4월 1일 오전반차 삭제 (엑셀에 없음)
DELETE FROM leave 
WHERE name = '백현덕' 
  AND start_date = '2025-04-01'
  AND type = 'half_am';

-- 윤은호: 2월 14일 오후반차 추가 (엑셀에 있음)
INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'yeh@hansl.com', 'half_pm', '2025-02-14', '2025-02-14', 'approved', '개인 사유', NOW());

-- 모든 직원의 employees 테이블 업데이트
UPDATE employees e
SET used_annual_leave = COALESCE((
  SELECT SUM(
    CASE 
      WHEN l.type = 'annual' THEN 1
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
      WHEN l.type = 'annual' THEN 1
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
  name,
  SUM(CASE 
    WHEN type = 'annual' THEN 1
    WHEN type IN ('half_am', 'half_pm') THEN 0.5
  END) as total_days
FROM leave
WHERE status = 'approved'
  AND start_date >= '2025-01-01'
  AND start_date <= '2025-08-31'
  AND name IN ('강영은', '이정화', '김경태', '나유성', '이재형', '이한빈', '정현웅', '백현덕', '윤은호')
GROUP BY name
ORDER BY name;