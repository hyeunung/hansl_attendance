-- app_settings 테이블에 필요한 값들이 있는지 확인하고 추가
-- 발주 알림이 제대로 작동하려면 이 값들이 필요함

-- 1. app_settings 테이블이 없으면 생성
CREATE TABLE IF NOT EXISTS app_settings (
  key text PRIMARY KEY,
  value text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2. supabase_url 설정 (환경에 맞게 수정 필요)
INSERT INTO app_settings (key, value)
VALUES ('supabase_url', 'https://tqyfakmpdijktyowsozw.supabase.co')
ON CONFLICT (key) DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = now();

-- 3. supabase_anon_key 설정 (프로젝트의 실제 anon key로 교체 필요)
INSERT INTO app_settings (key, value)
VALUES ('supabase_anon_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRxeWZha21wZGlqa3R5b3dzb3p3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjU0NjIwNDQsImV4cCI6MjA0MTAzODA0NH0.RJ3z_qHRMlnvl0VHJiQraNmQT-YI0xKN7xXjGvdP9l4')
ON CONFLICT (key) DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = now();

-- 4. supabase_service_role_key 설정 (프로젝트의 실제 service role key로 교체 필요)
-- 주의: 이 키는 보안상 매우 중요하므로 실제 운영환경에서는 환경변수로 관리해야 함
INSERT INTO app_settings (key, value)
VALUES ('supabase_service_role_key', 'YOUR_SERVICE_ROLE_KEY_HERE')
ON CONFLICT (key) DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = now()
WHERE app_settings.value = 'YOUR_SERVICE_ROLE_KEY_HERE'; -- 기본값일 때만 업데이트

-- 5. RLS 정책 설정 (app_settings는 서비스에서만 접근 가능하도록)
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제
DROP POLICY IF EXISTS "Service role can manage app_settings" ON app_settings;

-- 서비스 롤만 접근 가능
CREATE POLICY "Service role can manage app_settings" ON app_settings
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 6. 현재 설정값 확인
-- SELECT * FROM app_settings WHERE key IN ('supabase_url', 'supabase_anon_key', 'supabase_service_role_key');

-- 7. 알림 함수에서 설정값을 가져올 때 오류 처리 개선
CREATE OR REPLACE FUNCTION get_app_setting(p_key text) 
RETURNS text AS $$
DECLARE
  v_value text;
BEGIN
  SELECT value INTO v_value FROM app_settings WHERE key = p_key;
  
  IF v_value IS NULL THEN
    RAISE WARNING 'App setting % not found', p_key;
  END IF;
  
  RETURN v_value;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 사용 예시:
-- SELECT get_app_setting('supabase_url');
-- SELECT get_app_setting('supabase_anon_key');

