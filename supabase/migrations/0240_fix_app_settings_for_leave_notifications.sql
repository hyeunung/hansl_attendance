-- =======================================================================
-- 연차/출장 알림 수정: app_settings 테이블 올바른 값 설정
-- 
-- 문제: 구 프로젝트 URL과 키가 설정되어 있어서 트리거가 작동하지 않음
-- 해결: 현재 프로젝트(qvhbigvdfyvhoegkhvef)에 맞는 값들로 업데이트
-- =======================================================================

-- 1. app_settings 테이블이 없으면 생성
CREATE TABLE IF NOT EXISTS app_settings (
  key text PRIMARY KEY,
  value text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE app_settings
ADD COLUMN IF NOT EXISTS description text;

-- 2. 현재 프로젝트에 맞는 supabase_url 설정
INSERT INTO app_settings (key, value)
VALUES ('supabase_url', 'https://qvhbigvdfyvhoegkhvef.supabase.co')
ON CONFLICT (key) DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = now();

-- 3. 현재 프로젝트에 맞는 supabase_anon_key 설정
INSERT INTO app_settings (key, value)
VALUES ('supabase_anon_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjQ4MDUwMzQsImV4cCI6MjA0MDM4MTAzNH0.nSUIyJL6XkA8KUIBdnXhG6rOagNKl-s4MJ2xYMV2kNY')
ON CONFLICT (key) DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = now();

-- 4. RLS 정책 설정 (app_settings는 서비스에서만 접근 가능하도록)
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제
DROP POLICY IF EXISTS "Service role can manage app_settings" ON app_settings;

-- 서비스 롤만 접근 가능
CREATE POLICY "Service role can manage app_settings" ON app_settings
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 5. 설정값 확인
SELECT 
  key,
  CASE 
    WHEN key = 'supabase_anon_key' THEN 
      CASE 
        WHEN value LIKE '%qvhbigvdfyvhoegkhvef%' THEN '✅ 올바른 프로젝트 키'
        ELSE '❌ 잘못된 프로젝트 키'
      END
    WHEN key = 'supabase_url' THEN
      CASE 
        WHEN value = 'https://qvhbigvdfyvhoegkhvef.supabase.co' THEN '✅ 올바른 프로젝트 URL'
        ELSE '❌ 잘못된 프로젝트 URL'
      END
    ELSE '기타 설정'
  END as status,
  LEFT(value, 50) || '...' as value_preview,
  updated_at
FROM app_settings 
WHERE key IN ('supabase_url', 'supabase_anon_key')
ORDER BY key;

-- 완료 메시지
SELECT '✅ 연차/출장 알림 수정을 위한 app_settings 업데이트 완료!' as result;
