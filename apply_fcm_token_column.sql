-- 프로덕션 데이터베이스에 FCM 토큰 칼럼 추가 (이미 존재하면 스킵)
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
        
        -- 인덱스 추가 (빠른 조회를 위해)
        CREATE INDEX idx_employees_fcm_token 
        ON public.employees (fcm_token) 
        WHERE fcm_token IS NOT NULL;
        
        RAISE NOTICE '✅ fcm_token 칼럼이 성공적으로 추가되었습니다.';
    ELSE
        RAISE NOTICE 'ℹ️ fcm_token 칼럼이 이미 존재합니다.';
    END IF;
END $$;

-- 칼럼 존재 여부 확인
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public'
  AND table_name = 'employees' 
  AND column_name = 'fcm_token';

-- FCM 토큰이 저장된 사용자 수 확인
SELECT 
    COUNT(*) FILTER (WHERE fcm_token IS NOT NULL) AS users_with_token,
    COUNT(*) FILTER (WHERE fcm_token IS NULL) AS users_without_token,
    COUNT(*) AS total_users
FROM public.employees;