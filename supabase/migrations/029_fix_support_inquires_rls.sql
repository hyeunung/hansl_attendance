-- 029_fix_support_inquires_rls.sql
-- support_inquires 테이블의 RLS 정책 정리 및 수정

-- 1. 기존 중복/잘못된 RLS 정책 제거
DROP POLICY IF EXISTS "app_admin_select_all" ON support_inquires;
DROP POLICY IF EXISTS "support_inquiries_select" ON support_inquires;
DROP POLICY IF EXISTS "support_inquiries_update" ON support_inquires;
DROP POLICY IF EXISTS "support_inquiries_insert" ON support_inquires;

-- 2. 깔끔하게 정리된 RLS 정책 다시 생성

-- 2-1. SELECT 정책 - 사용자는 본인 문의만, app_admin은 모든 문의 조회
CREATE POLICY "Users can view inquiries" ON support_inquires
FOR SELECT
TO public
USING (
    -- 본인이 작성한 문의
    (auth.uid() = user_id)
    OR
    -- app_admin 역할을 가진 사용자
    EXISTS (
        SELECT 1 
        FROM employees e 
        WHERE e.email = auth.jwt() ->> 'email'
        AND 'app_admin' = ANY(e.purchase_role)
    )
);

-- 2-2. INSERT 정책 - 인증된 사용자만 문의 작성 가능 (app_admin 제외)
CREATE POLICY "Authenticated users can create inquiries" ON support_inquires
FOR INSERT
TO authenticated
WITH CHECK (
    -- app_admin이 아닌 사용자만 문의 작성 가능
    NOT EXISTS (
        SELECT 1 
        FROM employees e 
        WHERE e.email = auth.jwt() ->> 'email'
        AND 'app_admin' = ANY(e.purchase_role)
    )
);

-- 2-3. UPDATE 정책 - app_admin만 문의 수정 가능 (답변, 상태 변경)
CREATE POLICY "App admins can update inquiries" ON support_inquires
FOR UPDATE
TO public
USING (
    EXISTS (
        SELECT 1 
        FROM employees e 
        WHERE e.email = auth.jwt() ->> 'email'
        AND 'app_admin' = ANY(e.purchase_role)
    )
);

-- 3. 기존에 남아있던 정책 삭제 (이름이 다른 것들)
DROP POLICY IF EXISTS "Users can view own inquiries" ON support_inquires;
DROP POLICY IF EXISTS "Admins can update inquiries" ON support_inquires;
DROP POLICY IF EXISTS "Users can create inquiries" ON support_inquires;

-- 완료 메시지
DO $$
BEGIN
    RAISE NOTICE 'support_inquires 테이블의 RLS 정책이 정리되었습니다.';
END $$;

