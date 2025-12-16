-- 자동 퇴근 처리 Cron Job 설정 (매일 23:59 실행)
-- 출근했지만 퇴근 처리를 하지 않은 직원들을 18:00 퇴근으로 자동 처리

-- pg_cron extension 활성화 (이미 활성화되어 있을 수 있음)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 기존 cron job 삭제 (중복 방지)
DO $$
BEGIN
  PERFORM cron.unschedule('auto_clock_out_daily');
EXCEPTION
  WHEN others THEN
    NULL;
END $$;

-- 새로운 cron job 등록 (매일 23:59 KST)
-- KST는 UTC+9이므로, 23:59 KST = 14:59 UTC
SELECT cron.schedule(
  'auto_clock_out_daily',
  '59 14 * * *',  -- 매일 UTC 14:59 (KST 23:59)
  $$
    SELECT
      net.http_post(
        url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/auto_clock_out',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key')
        ),
        body := '{"trigger": "cron"}'::jsonb
      ) AS request_id;
  $$
);

-- 수동 실행을 위한 함수 생성
CREATE OR REPLACE FUNCTION public.run_auto_clock_out_manually()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result jsonb;
BEGIN
    -- Edge Function 호출
    SELECT content::jsonb INTO result
    FROM net.http_post(
        url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/auto_clock_out',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key')
        ),
        body := '{"trigger": "manual"}'::jsonb
    );
    
    RETURN result;
END;
$$;

-- 권한 설정 (admin만 수동 실행 가능)
REVOKE ALL ON FUNCTION public.run_auto_clock_out_manually() FROM public;
GRANT EXECUTE ON FUNCTION public.run_auto_clock_out_manually() TO authenticated;

-- attendance_records 테이블에 remarks 컬럼이 없다면 추가
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'attendance_records' 
        AND column_name = 'remarks'
    ) THEN
        ALTER TABLE attendance_records 
        ADD COLUMN remarks TEXT;
    END IF;
END $$;

-- Cron job 확인
SELECT * FROM cron.job WHERE jobname = 'auto_clock_out_daily';

-- 성공 메시지
DO $$
BEGIN
    RAISE NOTICE '✅ 자동 퇴근 처리 시스템 설정 완료';
    RAISE NOTICE '⏰ 매일 23:59에 퇴근 미처리 직원들이 18:00 퇴근으로 자동 처리됩니다';
    RAISE NOTICE '📌 수동 실행: SELECT public.run_auto_clock_out_manually();';
END $$;


