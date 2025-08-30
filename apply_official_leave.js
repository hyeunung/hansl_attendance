const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function applyOfficialLeave() {
  try {
    console.log('김경태님 공가 처리 시작...\n');
    
    // 1. 김경태님 정보 확인
    const { data: employee, error: empError } = await supabase
      .from('employees')
      .select('*')
      .eq('name', '김경태')
      .single();
    
    if (empError || !employee) {
      console.log('김경태님을 찾을 수 없습니다.');
      return;
    }
    
    console.log('김경태님 정보:');
    console.log('- 이메일:', employee.email);
    console.log('- 이름:', employee.name);
    console.log('- 부서:', employee.department);
    console.log();
    
    // 2. 기존 연차 확인 및 삭제
    const dates = ['2025-01-31', '2025-02-11', '2025-02-12', '2025-02-13'];
    
    // 기존 연차 조회
    const { data: existingLeaves } = await supabase
      .from('leave_requests')
      .select('*')
      .eq('user_email', employee.email)
      .or(`start_date.in.(${dates.join(',')}),end_date.in.(${dates.join(',')})`);
    
    if (existingLeaves && existingLeaves.length > 0) {
      console.log('기존 연차 신청 내역:');
      existingLeaves.forEach(leave => {
        console.log(`- ${leave.start_date} ~ ${leave.end_date}: ${leave.type} (${leave.status})`);
      });
      
      // 삭제
      const { error: deleteError } = await supabase
        .from('leave_requests')
        .delete()
        .eq('user_email', employee.email)
        .or(`start_date.in.(${dates.join(',')}),end_date.in.(${dates.join(',')})`);
      
      if (!deleteError) {
        console.log('기존 연차 삭제 완료\n');
      }
    }
    
    // 3. 공가 등록
    console.log('공가 등록 시작...');
    
    // 1/31 장인어른 상
    const { error: jan31Error } = await supabase
      .from('leave_requests')
      .insert({
        user_email: employee.email,
        type: 'official',
        start_date: '2025-01-31',
        end_date: '2025-01-31',
        days: 1,
        reason: '장인어른 상',
        status: 'approved',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      });
    
    if (jan31Error) {
      console.log('1/31 공가 처리 실패:', jan31Error.message);
    } else {
      console.log('✅ 1/31 장인어른 상 - 공가 처리 완료');
    }
    
    // 2/11~2/13 할머니 상
    const { error: feb11to13Error } = await supabase
      .from('leave_requests')
      .insert({
        user_email: employee.email,
        type: 'official',
        start_date: '2025-02-11',
        end_date: '2025-02-13',
        days: 3,
        reason: '할머니 상',
        status: 'approved',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      });
    
    if (feb11to13Error) {
      console.log('2/11~2/13 공가 처리 실패:', feb11to13Error.message);
    } else {
      console.log('✅ 2/11~2/13 할머니 상 - 공가 처리 완료');
    }
    
    // 4. annual_leave_history에서 해당 날짜 기록 삭제 (공가는 연차 차감 안 함)
    const { error: historyError } = await supabase
      .from('annual_leave_history')
      .delete()
      .eq('employee_email', employee.email)
      .in('leave_date', dates);
    
    if (!historyError) {
      console.log('✅ 연차 사용 기록 정리 완료');
    }
    
    console.log('\n✅ 공가 처리가 모두 완료되었습니다!');
    
    // 5. 결과 확인
    const { data: finalLeaves } = await supabase
      .from('leave_requests')
      .select('*')
      .eq('user_email', employee.email)
      .eq('type', 'official')
      .order('start_date');
    
    if (finalLeaves && finalLeaves.length > 0) {
      console.log('\n등록된 공가 내역:');
      finalLeaves.forEach(leave => {
        console.log(`- ${leave.start_date} ~ ${leave.end_date}: ${leave.reason}`);
      });
    }
    
  } catch (error) {
    console.error('오류 발생:', error);
  }
}

// RLS 정책 업데이트
async function updateRLSPolicies() {
  try {
    console.log('\n\nRLS 정책 업데이트 시작...');
    
    // SQL 쿼리로 직접 실행
    const { data, error } = await supabase.rpc('exec_sql', {
      sql: `
        -- 기존 정책 삭제
        DROP POLICY IF EXISTS "authenticated_users_can_view_approved_leaves" ON leave_requests;
        DROP POLICY IF EXISTS "users_can_view_own_leaves" ON leave_requests;
        DROP POLICY IF EXISTS "admins_can_view_all_leaves" ON leave_requests;
        
        -- 모든 인증된 사용자가 승인된 연차/출장/공가를 볼 수 있음
        CREATE POLICY "authenticated_users_can_view_approved_leaves" 
        ON leave_requests 
        FOR SELECT 
        USING (
          auth.role() = 'authenticated' 
          AND status = 'approved'
        );
        
        -- 자신의 모든 연차는 상태와 관계없이 볼 수 있음
        CREATE POLICY "users_can_view_own_leaves" 
        ON leave_requests 
        FOR SELECT 
        USING (
          auth.role() = 'authenticated' 
          AND user_email = auth.jwt()->>'email'
        );
        
        -- 관리자는 모든 연차를 볼 수 있음
        CREATE POLICY "admins_can_view_all_leaves" 
        ON leave_requests 
        FOR SELECT 
        USING (
          auth.role() = 'authenticated' 
          AND EXISTS (
            SELECT 1 FROM employees 
            WHERE email = auth.jwt()->>'email' 
            AND is_admin = true
          )
        );
      `
    });
    
    if (error) {
      // exec_sql이 없을 수 있으므로 다른 방법 시도
      console.log('RLS 정책 업데이트는 수동으로 진행해야 합니다.');
      console.log('Supabase 대시보드에서 직접 설정하거나 마이그레이션을 실행해주세요.');
    } else {
      console.log('✅ RLS 정책 업데이트 완료');
      console.log('이제 모든 직원이 달력에서 승인된 연차/출장/공가를 볼 수 있습니다.');
    }
    
  } catch (error) {
    console.error('RLS 업데이트 오류:', error);
  }
}

// 실행
async function main() {
  await applyOfficialLeave();
  await updateRLSPolicies();
}

main();