-- 자동 지각 처리 cron에 푸시 알림 발송 추가 (매일 08:31 KST)
-- 지각 처리된 직원 각자에게 FCM 푸시 발송 (send_fcm_notification Edge Function 호출)
-- 인증: app_settings 테이블의 supabase_url / supabase_service_role_key 사용 (기존 알림 트리거와 동일 패턴)
--
-- 푸시 문구 (2행):
--   제목: 지각 처리되었습니다
--   내용: 08:30까지 출근 등록이 없어 지각 처리되었습니다.
--         출근 버튼을 눌러 도착 시간을 기록해주세요.

-- 기존 cron job 삭제 후 재등록
DO $$
BEGIN
  PERFORM cron.unschedule('auto_late_mark_daily');
EXCEPTION
  WHEN others THEN
    NULL;
END $$;

-- 매일 08:31 KST = 23:31 UTC (전날)
SELECT cron.schedule(
  'auto_late_mark_daily',
  '31 23 * * *',
  $cmd$
    DO $do$
    DECLARE
      v_url TEXT;
      v_key TEXT;
      rec RECORD;
    BEGIN
      SELECT value INTO v_url FROM public.app_settings WHERE key = 'supabase_url';
      SELECT value INTO v_key FROM public.app_settings WHERE key = 'supabase_service_role_key';

      FOR rec IN
        UPDATE attendance_records
        SET status = '지각',
            updated_at = now()
        WHERE date = (now() AT TIME ZONE 'Asia/Seoul')::date
          AND status = '출근 전'
          AND clock_in IS NULL
        RETURNING user_email
      LOOP
        IF v_url IS NOT NULL AND v_key IS NOT NULL AND rec.user_email IS NOT NULL THEN
          PERFORM net.http_post(
            url := v_url || '/functions/v1/send_fcm_notification',
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'Authorization', 'Bearer ' || v_key
            ),
            body := jsonb_build_object(
              'type', 'attendance_late',
              'targetEmail', rec.user_email,
              'title', '지각 처리되었습니다',
              'body', '08:30까지 출근 등록이 없어 지각 처리되었습니다.' || chr(10) || '출근 버튼을 눌러 도착 시간을 기록해주세요.'
            )
          );
        END IF;
      END LOOP;
    END
    $do$;
  $cmd$
);

-- Cron job 확인
SELECT * FROM cron.job WHERE jobname = 'auto_late_mark_daily';
