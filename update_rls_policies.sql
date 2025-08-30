-- RLS 정책 업데이트
-- 모든 직원이 달력에서 승인된 연차/출장/공가를 볼 수 있도록 수정

-- 기존 정책 삭제
DROP POLICY IF EXISTS "authenticated_users_can_view_approved_leaves" ON leave;
DROP POLICY IF EXISTS "users_can_view_own_leaves" ON leave;  
DROP POLICY IF EXISTS "admins_can_view_all_leaves" ON leave;
DROP POLICY IF EXISTS "Employees can view their own leave requests" ON leave;
DROP POLICY IF EXISTS "Admins can view all leave requests" ON leave;

-- 1. 모든 인증된 사용자가 승인된 연차/출장/공가를 볼 수 있음
CREATE POLICY "All employees can view approved leaves" 
ON leave 
FOR SELECT 
USING (
  auth.role() = 'authenticated' 
  AND status = 'approved'
);

-- 2. 자신의 모든 연차는 상태와 관계없이 볼 수 있음
CREATE POLICY "Users can view own leave requests" 
ON leave 
FOR SELECT 
USING (
  auth.role() = 'authenticated' 
  AND user_email = auth.jwt()->>'email'
);

-- 3. 관리자는 모든 연차를 볼 수 있음
CREATE POLICY "Admins can view all leave requests" 
ON leave 
FOR SELECT 
USING (
  auth.role() = 'authenticated' 
  AND EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.jwt()->>'email' 
    AND (is_admin = true OR attendance_role ? 'superadmin')
  )
);

-- 정책 확인
SELECT 
  polname as policy_name,
  polcmd as command,
  polqual::text as using_expression
FROM pg_policy 
WHERE polrelid = 'public.leave'::regclass;