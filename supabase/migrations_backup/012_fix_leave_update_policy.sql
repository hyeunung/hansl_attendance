-- ====================================================================
-- Leave 테이블 UPDATE 권한 정책 수정
-- 문제: 관리자가 연차/출장 승인/반려할 때 UPDATE 권한 없음
-- 해결: 관리자가 담당 부서 직원의 leave 상태를 업데이트할 수 있도록 정책 수정
-- ====================================================================

-- 기존 정책 삭제 (있을 경우에만)
DROP POLICY IF EXISTS "managers_can_manage_department_leave" ON leave;

-- 새로운 통합 정책 생성 (부서 관리자 권한 강화)
CREATE POLICY "managers_can_manage_department_leave" ON leave
FOR ALL 
USING (
  -- 자신의 leave는 항상 관리 가능
  user_email = auth.email()
  OR
  -- Admin은 모든 leave 관리 가능
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND 'admin' = ANY(attendance_role)
  )
  OR
  -- 부서 관리자는 해당 부서 직원의 leave 관리 가능
  EXISTS (
    SELECT 1 FROM employees e1
    WHERE e1.email = auth.email()  -- 현재 로그인한 사용자 (관리자)
    AND (
      -- 개발팀_manager는 개발1팀, 개발2팀 모두 관리
      ('개발팀_manager' = ANY(e1.attendance_role) AND 
       department IN ('개발1팀', '개발2팀'))
      OR
      -- 기획팀_manager는 기획팀 관리
      ('기획팀_manager' = ANY(e1.attendance_role) AND 
       department = '기획팀')
      OR
      -- 영업팀_manager는 영업팀 관리
      ('영업팀_manager' = ANY(e1.attendance_role) AND 
       department = '영업팀')
      OR
      -- 경영지원팀_manager는 경영지원팀 관리
      ('경영지원팀_manager' = ANY(e1.attendance_role) AND 
       department = '경영지원팀')
      OR
      -- Admin은 모든 부서 관리 가능
      'admin' = ANY(e1.attendance_role)
    )
  )
);

-- 기존 admin 정책도 확인 (중복 방지)
DROP POLICY IF EXISTS "admins_can_manage_all_leave" ON leave;

-- 완료 메시지
SELECT 'Leave 테이블 UPDATE 권한 정책이 수정되었습니다.' as message;