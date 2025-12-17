-- 정현웅 12/8 출근 처리

-- 기존 레코드 확인
SELECT * FROM attendance_records 
WHERE employee_id = 'daa0487b-b7a1-4b8c-ac60-a00caf7f226f' 
  AND date = '2025-12-08';

-- 레코드 삽입 또는 업데이트
INSERT INTO attendance_records (
  employee_id,
  employee_name,
  user_email,
  date,
  clock_in,
  status,
  created_at,
  updated_at
) VALUES (
  'daa0487b-b7a1-4b8c-ac60-a00caf7f226f',
  '정현웅',
  'hyun-woong.jeong@hansl.com',
  '2025-12-08',
  '08:28:00',
  'present',
  NOW(),
  NOW()
)
ON CONFLICT (employee_id, date) 
DO UPDATE SET
  clock_in = '08:28:00',
  status = 'present',
  employee_name = '정현웅',
  user_email = 'hyun-woong.jeong@hansl.com',
  updated_at = NOW();

-- 결과 확인
SELECT 
  employee_name,
  date,
  clock_in,
  clock_out,
  status
FROM attendance_records 
WHERE employee_id = 'daa0487b-b7a1-4b8c-ac60-a00caf7f226f' 
  AND date = '2025-12-08';











