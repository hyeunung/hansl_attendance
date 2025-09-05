-- 오후반차 처리 Cron Job 설정 (매일 오후 12:30 실행)
-- pg_cron extension이 이미 설치되어 있다고 가정

-- 기존 cron job 삭제 (중복 방지)
DO $$
BEGIN
  PERFORM cron.unschedule('update_half_pm_status');
EXCEPTION
  WHEN others THEN
    NULL;
END $$;

-- 새로운 cron job 등록 (매일 12:30 PM KST)
-- KST는 UTC+9이므로, 12:30 PM KST = 03:30 AM UTC
SELECT cron.schedule(
  'update_half_pm_status',
  '30 3 * * *',  -- 매일 UTC 03:30 (KST 12:30)
  $$
    SELECT
      net.http_post(
        url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/update_half_pm_status',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key')
        ),
        body := '{"trigger": "cron"}'::jsonb
      ) AS request_id;
  $$
);

-- Cron job 확인
SELECT * FROM cron.job WHERE jobname = 'update_half_pm_status';