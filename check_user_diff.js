const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

async function checkUserDifferences() {
  try {
    // 1. test@hansl.com 정보
    const { data: testUser, error: testError } = await supabase
      .from('employees')
      .select('*')
      .eq('email', 'test@hansl.com')
      .single();
    
    // 2. hyun-woong.jeong@hansl.com 정보
    const { data: hyunUser, error: hyunError } = await supabase
      .from('employees')
      .select('*')
      .eq('email', 'hyun-woong.jeong@hansl.com')
      .single();
    
    console.log('=== 계정 비교 ===\n');
    
    console.log('test@hansl.com:');
    if (testUser) {
      console.log('  ID:', testUser.id);
      console.log('  이름:', testUser.name);
      console.log('  부서:', testUser.department);
      console.log('  role:', testUser.role);
      console.log('  is_admin:', testUser.is_admin);
      console.log('  attendance_role:', testUser.attendance_role);
      console.log('  created_at:', testUser.created_at);
    } else {
      console.log('  계정을 찾을 수 없습니다');
    }
    
    console.log('\nhyun-woong.jeong@hansl.com:');
    if (hyunUser) {
      console.log('  ID:', hyunUser.id);
      console.log('  이름:', hyunUser.name);
      console.log('  부서:', hyunUser.department);
      console.log('  role:', hyunUser.role);
      console.log('  is_admin:', hyunUser.is_admin);
      console.log('  attendance_role:', hyunUser.attendance_role);
      console.log('  created_at:', hyunUser.created_at);
    } else {
      console.log('  계정을 찾을 수 없습니다');
    }
    
    // 3. leave 테이블 접근 권한 테스트
    console.log('\n=== Leave 테이블 접근 테스트 ===');
    
    // Auth 없이 직접 쿼리
    const { data: leaves, error: leaveError } = await supabase
      .from('leave')
      .select('id, user_email, status, type')
      .limit(5);
    
    if (leaveError) {
      console.log('Leave 테이블 조회 오류:', leaveError.message);
    } else {
      console.log('Leave 테이블 조회 성공 - 데이터 개수:', leaves?.length || 0);
    }
    
  } catch (error) {
    console.error('오류 발생:', error);
  }
}

checkUserDifferences();