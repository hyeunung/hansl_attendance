const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env file');
  process.exit(1);
}

console.log('Using Anon Key to check development team roles...\n');

// Anon key로 클라이언트 생성
const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function checkDevTeamRoles() {
  try {
    console.log('=== 개발팀_manager 권한을 가진 사용자 조회 ===');
    
    // 1. 개발팀_manager 권한을 가진 모든 사용자 찾기
    const { data: managersData, error: managersError } = await supabase
      .from('employees')
      .select('name, email, department, attendance_role, purchase_role')
      .contains('attendance_role', ['개발팀_manager']);
    
    if (managersError) {
      console.error('Manager 조회 에러:', managersError);
    } else {
      console.log(`✅ 개발팀_manager 권한을 가진 사용자: ${managersData?.length || 0}명\n`);
      
      if (managersData && managersData.length > 0) {
        managersData.forEach((user, idx) => {
          console.log(`${idx + 1}. ${user.name} (${user.email})`);
          console.log(`   부서: ${user.department || 'N/A'}`);
          console.log(`   출근권한: ${user.attendance_role ? user.attendance_role.join(', ') : 'None'}`);
          console.log(`   구매권한: ${user.purchase_role ? user.purchase_role.join(', ') : 'None'}\n`);
        });
      }
    }

    console.log('\n=== 개발1팀 부서 소속 사용자 조회 ===');
    
    // 2. 개발1팀 부서의 모든 사용자 찾기
    const { data: dev1TeamData, error: dev1TeamError } = await supabase
      .from('employees')
      .select('name, email, department, attendance_role, purchase_role, position')
      .eq('department', '개발1팀')
      .order('name');
    
    if (dev1TeamError) {
      console.error('개발1팀 조회 에러:', dev1TeamError);
    } else {
      console.log(`✅ 개발1팀 소속 사용자: ${dev1TeamData?.length || 0}명\n`);
      
      if (dev1TeamData && dev1TeamData.length > 0) {
        dev1TeamData.forEach((user, idx) => {
          const hasManagerRole = user.attendance_role && user.attendance_role.includes('개발팀_manager');
          console.log(`${idx + 1}. ${user.name} (${user.email})`);
          console.log(`   직책: ${user.position || 'N/A'}`);
          console.log(`   출근권한: ${user.attendance_role ? user.attendance_role.join(', ') : 'None'}`);
          console.log(`   구매권한: ${user.purchase_role ? user.purchase_role.join(', ') : 'None'}`);
          console.log(`   개발팀_manager 권한: ${hasManagerRole ? '✅ 있음' : '❌ 없음'}\n`);
        });
      }
    }

    console.log('\n=== 분석 결과 ===');
    
    // 3. 분석: 개발1팀에서 매니저 권한이 없는 사람들 찾기
    const dev1WithoutManager = dev1TeamData?.filter(user => 
      !user.attendance_role || !user.attendance_role.includes('개발팀_manager')
    ) || [];
    
    console.log(`개발1팀 중 개발팀_manager 권한이 없는 사용자: ${dev1WithoutManager.length}명`);
    
    if (dev1WithoutManager.length > 0) {
      dev1WithoutManager.forEach((user, idx) => {
        console.log(`  ${idx + 1}. ${user.name} (${user.position || 'N/A'})`);
      });
    }
    
    // 4. 개발팀_manager 권한이 있지만 개발1팀이 아닌 사용자들
    const managersNotInDev1 = managersData?.filter(user => 
      user.department !== '개발1팀'
    ) || [];
    
    console.log(`\n개발팀_manager 권한은 있지만 개발1팀이 아닌 사용자: ${managersNotInDev1.length}명`);
    
    if (managersNotInDev1.length > 0) {
      managersNotInDev1.forEach((user, idx) => {
        console.log(`  ${idx + 1}. ${user.name} - 부서: ${user.department || 'N/A'}`);
      });
    }
    
    // 5. 모든 부서 정보 확인
    console.log('\n=== 전체 부서 정보 ===');
    const { data: allEmployees, error: allError } = await supabase
      .from('employees')
      .select('department')
      .not('department', 'is', null);
    
    if (!allError && allEmployees) {
      const departments = [...new Set(allEmployees.map(emp => emp.department))].sort();
      console.log('등록된 부서들:');
      departments.forEach((dept, idx) => {
        console.log(`  ${idx + 1}. ${dept}`);
      });
    }

  } catch (error) {
    console.error('예상치 못한 에러:', error);
  }
}

checkDevTeamRoles();