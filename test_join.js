const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

const supabase = createClient(
  config.SUPABASE_URL,
  config.SUPABASE_SERVICE_KEY
);

async function testJoin() {
  try {
    // 1. leave 테이블만 조회
    const { data: leavesOnly } = await supabase
      .from('leave')
      .select('*')
      .eq('user_email', 'test@hansl.com');
    
    console.log('=== test@hansl.com leave 데이터 (JOIN 없이) ===');
    console.log('개수:', leavesOnly?.length || 0);
    if (leavesOnly?.length > 0) {
      leavesOnly.forEach(l => {
        console.log('  - ID:', l.id, 'status:', l.status, 'type:', l.type);
      });
    }
    
    // 2. employees 테이블 확인
    const { data: emp } = await supabase
      .from('employees')
      .select('*')
      .eq('email', 'test@hansl.com')
      .single();
    
    console.log('\n=== test@hansl.com employees 데이터 ===');
    if (emp) {
      console.log('  이름:', emp.name);
      console.log('  부서:', emp.department);
      console.log('  attendance_role:', emp.attendance_role);
    } else {
      console.log('  ❌ employees 테이블에 없음!');
    }
    
    // 3. JOIN 테스트
    const { data: joinedData, error } = await supabase
      .from('leave')
      .select(`
        *,
        employees!leave_user_email_fkey (
          name,
          department,
          attendance_role
        )
      `)
      .eq('user_email', 'test@hansl.com');
    
    if (error) {
      console.log('\n❌ JOIN 오류:', error);
    } else {
      console.log('\n=== test@hansl.com leave 데이터 (JOIN) ===');
      console.log('개수:', joinedData?.length || 0);
      if (joinedData?.length > 0) {
        joinedData.forEach(l => {
          const hasEmp = l.employees ? 'YES' : 'NO';
          console.log('  - ID:', l.id, 'employees 데이터:', hasEmp);
          if (l.employees) {
            console.log('    name:', l.employees.name);
          }
        });
      }
    }
    
  } catch (error) {
    console.error('오류:', error);
  }
}

testJoin();