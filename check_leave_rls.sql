-- leave 테이블의 RLS 정책 확인
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

-- leave 테이블의 RLS 활성화 상태 확인
SELECT 
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'leave';

-- 현재 사용자 권한 확인
SELECT current_user, session_user;

-- leave 테이블에 DELETE 정책 추가 (필요한 경우)
-- 1. 본인의 pending 상태 삭제 허용
CREATE POLICY "Users can delete their own pending leaves" ON leave
FOR DELETE
TO authenticated
USING (
    auth.jwt() ->> 'email' = user_email 
    AND status = 'pending'
);

-- 2. 관리자는 모든 leave 삭제 가능
CREATE POLICY "Admins can delete any leave" ON leave
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM employees
        WHERE email = auth.jwt() ->> 'email'
        AND (
            'superadmin' = ANY(attendance_role)
            OR 'admin' = ANY(attendance_role)
        )
    )
);

-- 기존 정책이 있다면 먼저 삭제
-- DROP POLICY IF EXISTS "Users can delete their own pending leaves" ON leave;
-- DROP POLICY IF EXISTS "Admins can delete any leave" ON leave;