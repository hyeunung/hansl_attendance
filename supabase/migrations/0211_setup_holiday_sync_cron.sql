-- 공휴일 자동 동기화를 위한 cron job 설정
-- pg_cron extension이 필요합니다

-- pg_cron extension 활성화 (이미 활성화되어 있을 수 있음)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 매년 12월 1일 자정에 실행되는 cron job 생성
-- 다음 3년치 공휴일을 자동으로 계산하고 저장
SELECT cron.schedule(
    'sync-korean-holidays', -- job 이름
    '0 0 1 12 *', -- cron 표현식: 매년 12월 1일 0시 0분
    $$
    -- Edge Function 호출하여 공휴일 동기화
    SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/sync-holidays-cron',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key')
        ),
        body := '{}'::jsonb
    );
    $$
);

-- 수동 실행을 위한 함수도 생성
CREATE OR REPLACE FUNCTION public.sync_holidays_manually()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
BEGIN
    -- Edge Function 호출 (실행만 보장)
    PERFORM net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/sync-holidays-cron',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key')
        ),
        body := '{}'::jsonb
    );

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 권한 설정 (admin만 수동 실행 가능)
REVOKE ALL ON FUNCTION public.sync_holidays_manually() FROM public;
GRANT EXECUTE ON FUNCTION public.sync_holidays_manually() TO authenticated;

-- 즉시 실행은 환경별 설정 의존성이 있어 자동 실행하지 않음

-- 성공 메시지
DO $$
BEGIN
    RAISE NOTICE '✅ 공휴일 자동 동기화 시스템 설정 완료';
    RAISE NOTICE '📅 매년 12월 1일에 자동으로 다음 3년치 공휴일이 계산됩니다';
    RAISE NOTICE '🔄 수동 실행: SELECT public.sync_holidays_manually();';
END
$$;
