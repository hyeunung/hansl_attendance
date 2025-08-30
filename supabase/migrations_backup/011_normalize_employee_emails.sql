-- ====================================================================
-- employees 테이블의 이메일 정규화 및 auth.users와의 매칭 개선
-- ====================================================================

-- 1. 진단: auth.users와 employees 매칭 현황 확인
-- ====================================================================
SELECT 
  '=== 매칭 현황 분석 ===' as message,
  COUNT(DISTINCT au.email) as total_auth_users,
  COUNT(DISTINCT e.email) as total_employees,
  COUNT(DISTINCT CASE WHEN e.email IS NOT NULL THEN au.email END) as matched_users,
  COUNT(DISTINCT CASE WHEN e.email IS NULL THEN au.email END) as unmatched_users
FROM auth.users au
LEFT JOIN employees e ON LOWER(TRIM(au.email)) = LOWER(TRIM(e.email))
WHERE au.email LIKE '%@hansl.com';

-- 매칭 안 되는 케이스 상세 보기
SELECT 
  au.email as auth_email,
  au.created_at as signup_date,
  '❌ employees 테이블에 없음' as status
FROM auth.users au
WHERE NOT EXISTS (
  SELECT 1 FROM employees e 
  WHERE LOWER(TRIM(e.email)) = LOWER(TRIM(au.email))
)
AND au.email LIKE '%@hansl.com'
ORDER BY au.created_at DESC;

-- 2. employees 테이블 이메일 정규화 (소문자 변환 + 공백 제거)
-- ====================================================================
UPDATE employees 
SET email = LOWER(TRIM(email))
WHERE email != LOWER(TRIM(email))
  AND email LIKE '%@hansl.com';

-- 3. 중복 이메일 확인 (정규화 후)
-- ====================================================================
SELECT 
  email, 
  COUNT(*) as duplicate_count,
  STRING_AGG(name, ', ') as names
FROM employees
WHERE email LIKE '%@hansl.com'
GROUP BY email
HAVING COUNT(*) > 1;

-- 4. auth.users에 중복 가입된 이메일 확인
-- ====================================================================
SELECT 
  email,
  COUNT(*) as signup_count,
  MIN(created_at) as first_signup,
  MAX(created_at) as last_signup
FROM auth.users
WHERE email LIKE '%@hansl.com'
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

-- 5. 최종 매칭 상태 확인
-- ====================================================================
SELECT 
  '=== 정규화 후 최종 매칭 결과 ===' as message,
  COUNT(DISTINCT au.email) as total_auth_users,
  COUNT(DISTINCT e.email) as total_employees,
  COUNT(DISTINCT CASE WHEN e.email IS NOT NULL THEN au.email END) as matched_users,
  COUNT(DISTINCT CASE WHEN e.email IS NULL THEN au.email END) as still_unmatched
FROM auth.users au
LEFT JOIN employees e ON au.email = e.email
WHERE au.email LIKE '%@hansl.com';

-- 6. 여전히 매칭 안 되는 사용자 목록
-- ====================================================================
SELECT 
  au.email as auth_email,
  au.raw_user_meta_data->>'display_name' as display_name,
  au.created_at,
  '⚠️ employees 테이블에 추가 필요' as action_required
FROM auth.users au
LEFT JOIN employees e ON au.email = e.email
WHERE au.email LIKE '%@hansl.com'
  AND e.email IS NULL
ORDER BY au.created_at DESC;

-- 완료 메시지
SELECT '✅ 이메일 정규화 완료. 위 결과를 확인하고 필요시 추가 조치를 취하세요.' as message;