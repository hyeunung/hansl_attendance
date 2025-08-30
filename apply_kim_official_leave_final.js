const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

const supabase = createClient(
  config.SUPABASE_URL,
  config.SUPABASE_SERVICE_KEY
);

async function applyOfficialLeave() {
  try {
    console.log('김경태님 공가 처리 시작...\n');
    
    // 기존 데이터 삭제
    const { error: deleteError } = await supabase
      .from('leave')
      .delete()
      .eq('user_email', 'kkt@hansl.com')
      .in('start_date', ['2025-01-31', '2025-02-11']);
    
    if (deleteError) {
      console.log('기존 데이터 삭제 오류:', deleteError);
    } else {
      console.log('✅ 기존 데이터 삭제 완료');
    }
    
    // 1/31 장인어른 상 공가 등록
    const { data: jan31, error: jan31Error } = await supabase
      .from('leave')
      .insert({
        user_email: 'kkt@hansl.com',
        type: 'official',
        start_date: '2025-01-31',
        end_date: '2025-01-31',
        days: 1,
        reason: '장인어른 상',
        status: 'approved',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select();
    
    if (jan31Error) {
      console.log('1/31 공가 등록 오류:', jan31Error);
    } else {
      console.log('✅ 1/31 장인어른 상 공가 등록 완료');
      if (jan31 && jan31[0]) {
        console.log('   등록 ID:', jan31[0].id);
      }
    }
    
    // 2/11~2/13 할머니 상 공가 등록
    const { data: feb, error: febError } = await supabase
      .from('leave')
      .insert({
        user_email: 'kkt@hansl.com',
        type: 'official',
        start_date: '2025-02-11',
        end_date: '2025-02-13',
        days: 3,
        reason: '할머니 상',
        status: 'approved',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select();
    
    if (febError) {
      console.log('2/11~2/13 공가 등록 오류:', febError);
    } else {
      console.log('✅ 2/11~2/13 할머니 상 공가 등록 완료');
      if (feb && feb[0]) {
        console.log('   등록 ID:', feb[0].id);
      }
    }
    
    // annual_leave_history에서 삭제 (공가는 연차 차감 안 함)
    const { error: historyError } = await supabase
      .from('annual_leave_history')
      .delete()
      .eq('employee_email', 'kkt@hansl.com')
      .in('leave_date', ['2025-01-31', '2025-02-11', '2025-02-12', '2025-02-13']);
    
    if (historyError) {
      console.log('연차 기록 삭제 오류:', historyError);
    } else {
      console.log('✅ 연차 사용 기록 정리 완료');
    }
    
    console.log('\n✅ 김경태님 공가 처리가 모두 완료되었습니다!\n');
    
    // 결과 확인
    const { data: result, error: resultError } = await supabase
      .from('leave')
      .select('*')
      .eq('user_email', 'kkt@hansl.com')
      .eq('type', 'official')
      .order('start_date');
    
    if (resultError) {
      console.log('결과 조회 오류:', resultError);
    } else if (result && result.length > 0) {
      console.log('등록된 공가:');
      result.forEach(r => {
        console.log(`- ${r.start_date} ~ ${r.end_date}: ${r.reason} (${r.days}일)`);
      });
    } else {
      console.log('등록된 공가가 없습니다.');
    }
    
  } catch (error) {
    console.error('오류:', error);
  }
}

// RLS 정책 업데이트를 위한 SQL
async function showRLSUpdateSQL() {
  console.log('\n=== RLS 정책 업데이트 SQL ===');
  console.log('Supabase SQL Editor에서 다음 SQL을 실행해주세요:\n');
  
  const sql = `
-- 기존 정책 삭제
DROP POLICY IF EXISTS "authenticated_users_can_view_approved_leaves" ON leave;
DROP POLICY IF EXISTS "users_can_view_own_leaves" ON leave;  
DROP POLICY IF EXISTS "admins_can_view_all_leaves" ON leave;

-- 1. 모든 인증된 사용자가 승인된 연차/출장/공가를 볼 수 있음
CREATE POLICY "All employees can view approved leaves" 
ON leave 
FOR SELECT 
USING (
  auth.role() = 'authenticated' 
  AND status = 'approved'
);

-- 2. 자신의 모든 연차는 상태와 관계없이 볼 수 있음
CREATE POLICY "Users can view own leaves" 
ON leave 
FOR SELECT 
USING (
  auth.role() = 'authenticated' 
  AND user_email = auth.jwt()->>'email'
);

-- 3. 관리자는 모든 연차를 볼 수 있음
CREATE POLICY "Admins can view all leaves" 
ON leave 
FOR SELECT 
USING (
  auth.role() = 'authenticated' 
  AND EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.jwt()->>'email' 
    AND (is_admin = true OR attendance_role ? 'superadmin')
  )
);`;

  console.log(sql);
}

// 실행
async function main() {
  await applyOfficialLeave();
  await showRLSUpdateSQL();
}

main();