-- FCM 토큰 칼럼 확인
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'employees' 
  AND column_name = 'fcm_token';

-- 만약 칼럼이 없다면 추가
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employees' 
          AND column_name = 'fcm_token'
    ) THEN
        ALTER TABLE employees 
        ADD COLUMN fcm_token TEXT;
        
        RAISE NOTICE 'fcm_token column added to employees table';
    ELSE
        RAISE NOTICE 'fcm_token column already exists';
    END IF;
END $$;

-- 칼럼 확인
SELECT 
    email,
    name,
    fcm_token IS NOT NULL AS has_token,
    LEFT(fcm_token, 20) AS token_prefix
FROM employees
WHERE email IN ('hyun-woong.jeong@hansl.com', 'test@hansl.com')
ORDER BY email;