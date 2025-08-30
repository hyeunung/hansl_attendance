-- ====================================================================
-- Leave 테이블 RLS 정책 확인 쿼리
-- 이 쿼리를 Supabase Dashboard의 SQL Editor에서 실행하여
-- RLS 정책이 올바르게 설정되었는지 확인할 수 있습니다.
-- ====================================================================

-- 1. 현재 leave 테이블의 모든 RLS 정책 확인
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'leave' 
ORDER BY policyname;

-- 2. 관리자 권한을 가진 직원 확인
SELECT 
    name,
    email,
    department,
    attendance_role
FROM employees 
WHERE 'admin' = ANY(attendance_role) 
   OR '_manager' = ANY(array_to_string(attendance_role, ','));

-- 3. 최근 leave 요청 상태 확인
SELECT 
    id,
    name,
    user_email,
    department,
    type,
    status,
    created_at,
    updated_at
FROM leave 
ORDER BY created_at DESC 
LIMIT 10;