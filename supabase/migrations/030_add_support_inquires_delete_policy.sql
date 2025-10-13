-- 030_add_support_inquires_delete_policy.sql
-- support_inquires 테이블에 DELETE 정책 추가

-- 먼저 기존 정책 제거 (있을 경우)
DROP POLICY IF EXISTS "Users can delete their own inquiries" ON support_inquires;

-- DELETE 정책 - 본인이 작성한 문의는 언제든 삭제 가능
-- app_admin은 모든 문의 삭제 가능
CREATE POLICY "Users can delete their own inquiries" ON support_inquires
FOR DELETE
TO public
USING (
    -- 본인이 작성한 문의는 언제든 삭제 가능
    auth.uid() = user_id 
    OR
    -- app_admin 역할을 가진 사용자는 모든 문의 삭제 가능
    EXISTS (
        SELECT 1 
        FROM employees e 
        WHERE e.email = auth.jwt() ->> 'email'
        AND 'app_admin' = ANY(e.purchase_role)
    )
);

-- 완료 메시지
DO $$
BEGIN
    RAISE NOTICE 'support_inquires 테이블에 DELETE 정책이 추가되었습니다.';
END $$;