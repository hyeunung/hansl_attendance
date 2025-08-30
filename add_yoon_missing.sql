-- 윤은호 누락된 7월 연차 추가
BEGIN;

-- 7월 18일
INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'yeh@hansl.com', 'annual', '2025-07-18', '2025-07-18', 'approved', '개인 사유', NOW());

-- 7월 21일
INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'yeh@hansl.com', 'annual', '2025-07-21', '2025-07-21', 'approved', '개인 사유', NOW());

-- 7월 22일
INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'yeh@hansl.com', 'annual', '2025-07-22', '2025-07-22', 'approved', '개인 사유', NOW());

-- 7월 23일
INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'yeh@hansl.com', 'annual', '2025-07-23', '2025-07-23', 'approved', '개인 사유', NOW());

-- 7월 24일
INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'yeh@hansl.com', 'annual', '2025-07-24', '2025-07-24', 'approved', '개인 사유', NOW());

-- 7월 25일
INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('윤은호', 'yeh@hansl.com', 'annual', '2025-07-25', '2025-07-25', 'approved', '개인 사유', NOW());

-- 윤은호 사용연차 업데이트 (17.5일로)
UPDATE employees 
SET used_annual_leave = 17.5,
    remaining_annual_leave = annual_leave_granted_current_year - 17.5
WHERE name = '윤은호';

COMMIT;

-- 확인
SELECT name, COUNT(*) as records,
  SUM(CASE 
    WHEN type = 'annual' THEN 1 
    WHEN type IN ('half_am', 'half_pm') THEN 0.5 
  END) as total_days
FROM leave 
WHERE name = '윤은호'
  AND status = 'approved' 
  AND start_date >= '2025-01-01' 
  AND start_date <= '2025-08-31'
GROUP BY name;