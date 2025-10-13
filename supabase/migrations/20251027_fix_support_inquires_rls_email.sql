-- 20251027_fix_support_inquires_rls_email.sql
-- support_inquires 테이블의 RLS 정책을 email 기반으로 수정
-- 문제: employees.id = auth.uid()로 체크하여 app_admin이 문의를 볼 수 없음
-- 해결: employees.email = auth.email()로 변경

-- 1. 기존 SELECT 정책 삭제
DROP POLICY IF EXISTS select_inquiries_policy ON support_inquires;

-- 2. 수정된 SELECT 정책 생성 (email 기반)
CREATE POLICY select_inquiries_policy ON support_inquires
FOR SELECT USING (
  -- 본인이 작성한 문의
  auth.uid() = user_id 
  -- 또는 requester_id와 일치 (구매 요청 관련 문의)
  OR auth.uid() = requester_id
  -- 또는 app_admin 권한 (email로 확인)
  OR EXISTS (
    SELECT 1 FROM employees 
    WHERE employees.email = auth.email()
      AND 'app_admin' = ANY(employees.purchase_role)
  )
);

-- 3. UPDATE 정책도 동일하게 수정
DROP POLICY IF EXISTS update_inquiries_policy ON support_inquires;

CREATE POLICY update_inquiries_policy ON support_inquires
FOR UPDATE USING (
  -- app_admin만 업데이트 가능 (email 기반)
  EXISTS (
    SELECT 1 FROM employees 
    WHERE employees.email = auth.email()
      AND 'app_admin' = ANY(employees.purchase_role)
  )
);

-- 4. DELETE 정책도 동일하게 수정
DROP POLICY IF EXISTS delete_inquiries_policy ON support_inquires;

CREATE POLICY delete_inquiries_policy ON support_inquires
FOR DELETE USING (
  -- app_admin만 삭제 가능 (email 기반)
  EXISTS (
    SELECT 1 FROM employees 
    WHERE employees.email = auth.email()
      AND 'app_admin' = ANY(employees.purchase_role)
  )
);

-- 5. 정책이 제대로 적용되었는지 확인
-- 실행 후 app_admin 권한을 가진 사용자로 로그인하여 모든 문의가 보이는지 확인 필요