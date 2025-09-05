-- pg_cron extension 활성화 (Supabase에서는 이미 활성화되어 있을 수 있음)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 매년 1월 1일과 12월 1일에 공휴일 동기화 실행
-- 1월 1일: 새해 공휴일 업데이트
-- 12월 1일: 다음 해 공휴일 미리 준비
SELECT cron.schedule(
    'sync-holidays-january',
    '0 0 1 1 *', -- 매년 1월 1일 자정
    $$
    SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/sync-holidays',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_key'),
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

SELECT cron.schedule(
    'sync-holidays-december',
    '0 0 1 12 *', -- 매년 12월 1일 자정
    $$
    SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/sync-holidays',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_key'),
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- 수동으로 공휴일 동기화를 실행할 수 있는 함수
CREATE OR REPLACE FUNCTION sync_holidays_manually()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result jsonb;
BEGIN
    SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/sync-holidays',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_key'),
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    ) INTO result;
    
    RETURN result;
END;
$$;

-- 공휴일인지 확인하는 헬퍼 함수
CREATE OR REPLACE FUNCTION is_holiday(check_date DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.holidays 
        WHERE date = check_date
    );
END;
$$;

-- 주말 또는 공휴일인지 확인하는 함수
CREATE OR REPLACE FUNCTION is_weekend_or_holiday(check_date DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    day_of_week INT;
BEGIN
    day_of_week := EXTRACT(DOW FROM check_date);
    
    -- 0 = 일요일, 6 = 토요일
    IF day_of_week IN (0, 6) THEN
        RETURN TRUE;
    END IF;
    
    -- 공휴일 체크
    RETURN is_holiday(check_date);
END;
$$;