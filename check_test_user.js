const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY  // anon key 사용
);

async function checkTestUser() {
  try {
    // 1. test@hansl이 employees에 있는지 확인
    const { data: testUser, error: testError } = await supabase
      .from('employees')
      .select('*')
      .eq('email', 'test@hansl.com')
      .single();
    
    if (testError && testError.code !== 'PGRST116') {
      console.error('test@hansl 조회 오류:', testError);
      return;
    }
    
    if (!testUser) {
      console.log('❌ test@hansl.com이 employees 테이블에 없습니다!');
      console.log('test 계정을 생성해야 합니다.');
    } else {
      console.log('✅ test@hansl.com 계정 정보:');
      console.log('  ID:', testUser.id);
      console.log('  이름:', testUser.name);
      console.log('  부서:', testUser.department);
      console.log('  직책:', testUser.position);
      console.log('  권한:', testUser.role);
      console.log('  attendance_role:', testUser.attendance_role);
    }
    
    // 2. 전체 leave 데이터 확인 (상태별로)
    const { data: allLeaves, error: leaveError } = await supabase
      .from('leave')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (leaveError) {
      console.error('Leave 조회 오류:', leaveError);
      return;
    }
    
    console.log('\n=== 전체 Leave 데이터 (모든 상태) ===');
    console.log('총 개수:', allLeaves?.length || 0);
    
    // 상태별 카운트
    const statusCount = {};
    allLeaves?.forEach(leave => {
      statusCount[leave.status] = (statusCount[leave.status] || 0) + 1;
    });
    console.log('\n상태별 개수:');
    Object.entries(statusCount).forEach(([status, count]) => {
      console.log(`  - ${status}: ${count}개`);
    });
    
    // 최근 5개만 표시
    console.log('\n최근 leave 데이터 (5개):');
    allLeaves?.slice(0, 5).forEach(leave => {
      console.log(`- ${leave.name} (${leave.user_email}): ${leave.type} | ${leave.start_date} ~ ${leave.end_date} | 상태: ${leave.status}`);
    });
    
  } catch (error) {
    console.error('오류 발생:', error);
  }
}

checkTestUser();