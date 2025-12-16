-- =======================================================================
-- 긴급: 연차/출장 알림 수정을 위한 app_settings 업데이트
-- 
-- 문제: 구 프로젝트 URL(tqyfakmpdijktyowsozw)이 설정되어 트리거 실패
-- 해결: 현재 프로젝트(qvhbigvdfyvhoegkhvef) 값으로 업데이트
-- =======================================================================

-- 현재 프로젝트에 맞는 supabase_url 업데이트
UPDATE app_settings 
SET value = 'https://qvhbigvdfyvhoegkhvef.supabase.co',
    updated_at = now()
WHERE key = 'supabase_url';

-- 현재 프로젝트에 맞는 supabase_anon_key 업데이트
UPDATE app_settings 
SET value = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjQ4MDUwMzQsImV4cCI6MjA0MDM4MTAzNH0.nSUIyJL6XkA8KUIBdnXhG6rOagNKl-s4MJ2xYMV2kNY',
    updated_at = now()
WHERE key = 'supabase_anon_key';

-- 업데이트 확인
SELECT 
  key,
  CASE 
    WHEN key = 'supabase_anon_key' THEN 
      CASE 
        WHEN value LIKE '%qvhbigvdfyvhoegkhvef%' THEN '✅ 올바른 프로젝트 키'
        ELSE '❌ 잘못된 프로젝트 키: ' || LEFT(value, 50)
      END
    WHEN key = 'supabase_url' THEN
      CASE 
        WHEN value = 'https://qvhbigvdfyvhoegkhvef.supabase.co' THEN '✅ 올바른 프로젝트 URL'
        ELSE '❌ 잘못된 프로젝트 URL: ' || value
      END
    ELSE '기타 설정'
  END as status,
  updated_at
FROM app_settings 
WHERE key IN ('supabase_url', 'supabase_anon_key')
ORDER BY key;

-- 완료 메시지
SELECT '✅ 연차/출장 알림을 위한 app_settings 긴급 수정 완료!' as result;