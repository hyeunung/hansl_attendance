-- 사용자별 푸시 알림 수신 설정 (카테고리별 on/off)
-- 구조 예시: { "production_teams": { "production_new_row": false, "pcb_stock_completed": false } }
-- 카테고리/키가 없으면 기본값은 수신(on)으로 간주한다.
-- 필터링은 send_fcm_notification Edge Function에서 발송 직전에 수행한다.
ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS notification_preferences jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.employees.notification_preferences IS
  '푸시 알림 수신 설정. { "production_teams": { "<항목키>": false } } 형태로 수신 거부만 저장, 키 없으면 수신';
