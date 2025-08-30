-- 김경태님 공가 처리
-- 1/31: 장인어른 상
-- 2/11~2/13: 할머니 상

-- 기존 데이터 삭제 (중복 방지)
DELETE FROM leave_requests 
WHERE user_email = 'kkt@hansl.com' 
AND start_date IN ('2025-01-31', '2025-02-11');

-- 1/31 장인어른 상 - 공가 등록
INSERT INTO leave_requests (
  user_email,
  type,
  start_date,
  end_date,
  days,
  reason,
  status,
  created_at,
  updated_at
) VALUES (
  'kkt@hansl.com',
  'official',
  '2025-01-31',
  '2025-01-31',
  1,
  '장인어른 상',
  'approved',
  NOW(),
  NOW()
);

-- 2/11~2/13 할머니 상 - 공가 등록
INSERT INTO leave_requests (
  user_email,
  type,
  start_date,
  end_date,
  days,
  reason,
  status,
  created_at,
  updated_at
) VALUES (
  'kkt@hansl.com',
  'official',
  '2025-02-11',
  '2025-02-13',
  3,
  '할머니 상',
  'approved',
  NOW(),
  NOW()
);

-- 연차 사용 기록에서 삭제 (공가는 연차 차감 안 함)
DELETE FROM annual_leave_history
WHERE employee_email = 'kkt@hansl.com'
AND leave_date IN ('2025-01-31', '2025-02-11', '2025-02-12', '2025-02-13');

-- 확인
SELECT * FROM leave_requests 
WHERE user_email = 'kkt@hansl.com' 
AND type = 'official'
ORDER BY start_date;
