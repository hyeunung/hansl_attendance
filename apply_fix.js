const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo';

async function fixLeavePolicies() {
  console.log('🔧 Leave 테이블 RLS 정책 수정 시작...\n');
  console.log('📝 다음 작업을 수행해야 합니다:');
  console.log('1. Supabase Dashboard 접속: https://supabase.com/dashboard/project/qvhbigvdfyvhoegkhvef');
  console.log('2. SQL Editor 탭으로 이동');
  console.log('3. 아래 SQL 복사해서 실행:\n');
  
  const sql = `-- 기존 모든 leave 정책 삭제
DROP POLICY IF EXISTS "managers_can_manage_department_leave" ON leave;
DROP POLICY IF EXISTS "admins_can_manage_all_leave" ON leave;
DROP POLICY IF EXISTS "users_can_manage_own_leave" ON leave;
DROP POLICY IF EXISTS "all_users_can_view_approved_leave_for_calendar" ON leave;

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

-- 2. SELECT 정책 - 모두가 leave를 조회할 수 있도록 (달력 포함)  
CREATE POLICY "all_can_view_leave" ON leave
FOR SELECT
USING (true);

-- 3. INSERT 정책 - 사용자가 본인의 leave를 생성할 수 있도록
CREATE POLICY "users_can_create_own_leave" ON leave
FOR INSERT
WITH CHECK (user_email = auth.email());

-- 4. DELETE 정책 - 사용자가 pending 상태의 본인 leave를 삭제할 수 있도록
CREATE POLICY "users_can_delete_own_leave" ON leave
FOR DELETE
USING (user_email = auth.email() AND status = 'pending');

SELECT 'Leave 테이블 RLS 정책이 수정되었습니다.' as message;`;

  console.log('```sql');
  console.log(sql);
  console.log('```\n');
  console.log('4. "Run" 버튼 클릭하여 실행');
  console.log('5. 성공 메시지 확인\n');
  console.log('✅ 이렇게 하면 관리자가 leave를 업데이트할 수 있게 됩니다\!');
}

fixLeavePolicies();
