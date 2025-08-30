-- FCM 토큰 칼럼 추가 (이미 존재하면 스킵)
DO $$ 
BEGIN
    -- fcm_token 칼럼이 없는 경우에만 추가
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public'
          AND table_name = 'employees' 
          AND column_name = 'fcm_token'
    ) THEN
        ALTER TABLE public.employees 
        ADD COLUMN fcm_token TEXT;
        
        COMMENT ON COLUMN public.employees.fcm_token IS 'Firebase Cloud Messaging 푸시 알림 토큰';
        
        RAISE NOTICE 'fcm_token column added to employees table';
    ELSE
        RAISE NOTICE 'fcm_token column already exists';
    END IF;
END $$;

-- 인덱스 추가 (빠른 조회를 위해)
CREATE INDEX IF NOT EXISTS idx_employees_fcm_token 
ON public.employees (fcm_token) 
WHERE fcm_token IS NOT NULL;