-- ====================================================================
-- 관리자 Leave 테이블 UPDATE 권한 수정 (Migration 013)
-- 문제: 관리자가 연차/출장 승인/반려할 때 UPDATE 권한 없음
-- 해결: RLS 정책을 다시 설정하여 관리자 권한 문제 해결
-- ====================================================================

-- 기존 모든 leave 정책 삭제
DROP POLICY IF EXISTS "managers_can_manage_department_leave" ON leave;
DROP POLICY IF EXISTS "admins_can_manage_all_leave" ON leave;
DROP POLICY IF EXISTS "users_can_manage_own_leave" ON leave;
DROP POLICY IF EXISTS "managers_can_update_leave" ON leave;
DROP POLICY IF EXISTS "users_and_managers_can_view_leave" ON leave;
DROP POLICY IF EXISTS "users_can_create_own_leave" ON leave;
DROP POLICY IF EXISTS "users_can_delete_own_leave" ON leave;

-- 1. UPDATE 정책 - 관리자가 leave 상태를 업데이트할 수 있도록
CREATE POLICY "managers_can_update_leave" ON leave
FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND (
      'admin' = ANY(attendance_role)
      OR '개발팀_manager' = ANY(attendance_role)
      OR '기획팀_manager' = ANY(attendance_role)
      OR '영업팀_manager' = ANY(attendance_role)
      OR '경영지원팀_manager' = ANY(attendance_role)
    )
  )
);

-- 2. SELECT 정책 - 사용자 본인과 관리자가 leave를 조회할 수 있도록
CREATE POLICY "users_and_managers_can_view_leave" ON leave
FOR SELECT
USING (
  user_email = auth.email()
  OR EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND (
      'admin' = ANY(attendance_role)
      OR POSITION('_manager' IN ARRAY_TO_STRING(attendance_role, ',')) > 0
    )
  )
);

-- 3. INSERT 정책 - 사용자가 본인의 leave를 생성할 수 있도록
CREATE POLICY "users_can_create_own_leave" ON leave
FOR INSERT
WITH CHECK (user_email = auth.email());

-- 4. DELETE 정책 - 사용자가 pending 상태의 본인 leave를 삭제할 수 있도록
CREATE POLICY "users_can_delete_own_leave" ON leave
FOR DELETE
USING (user_email = auth.email() AND status = 'pending');

-- 완료 메시지
SELECT 'Migration 013: Leave 테이블 RLS 정책이 수정되었습니다.' as message;