-- 자동 지각 처리 Cron Job 설정 (매일 08:31 KST 실행)
-- 08:30까지 출근 버튼을 누르지 않은 직원('출근 전' 상태)을 '지각'으로 자동 변경
-- clock_in은 비워두고, 이후 앱의 "지각 출근" 버튼을 누르면 실제 도착 시각이 기록됨
--
-- 예외 처리 (WHERE 조건으로 자연스럽게 제외됨):
--   연차/출장/반차/공가: daily_attendance_seed가 해당 상태로 생성 → '출근 전' 아님
--   주말/공휴일: seed가 status를 NULL로 생성 → '출근 전' 아님
--   아르바이트: seed 대상에서 제외되어 기록 자체가 없음 (지각 기준 9:00은 앱에서 판정)
--   오전반차: status '오전반차' 유지 → 기존 update_half_am_status가 처리

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 기존 cron job 삭제 (중복 방지)
DO $$
BEGIN
  PERFORM cron.unschedule('auto_late_mark_daily');
EXCEPTION
  WHEN others THEN
    NULL;
END $$;

-- 새로운 cron job 등록 (매일 08:31 KST = 23:31 UTC 전날)
-- 앱의 "지각 출근" 버튼 전환 시점(08:31:00, minute > 30)과 동일한 기준
SELECT cron.schedule(
  'auto_late_mark_daily',
  '31 23 * * *',
  $$
    UPDATE attendance_records
    SET status = '지각',
        updated_at = now()
    WHERE date = (now() AT TIME ZONE 'Asia/Seoul')::date
      AND status = '출근 전'
      AND clock_in IS NULL;
  $$
);

-- Cron job 확인
SELECT * FROM cron.job WHERE jobname = 'auto_late_mark_daily';
