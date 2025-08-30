const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

const supabase = createClient(
  config.SUPABASE_URL,
  config.SUPABASE_SERVICE_KEY
);

async function testJoin2() {
  try {
    // 다양한 JOIN 방법 테스트
    
    // 1. inner join 시도
    const { data: join1, error: error1 } = await supabase
      .from('leave')
      .select(`
        *,
        employees!inner (
          name,
          department,
          attendance_role
        )
      `)
      .eq('user_email', 'test@hansl.com');
    
    if (error1) {
      console.log('1. inner join 실패:', error1.message);
    } else {
      console.log('1. inner join 성공! 데이터 수:', join1?.length);
    }
    
    // 2. 컬럼명으로 직접 join
    const { data: join2, error: error2 } = await supabase
      .from('leave')
      .select(`
        *,
        employees!user_email (
          name,
          department,
          attendance_role
        )
      `)
      .eq('user_email', 'test@hansl.com');
    
    if (error2) {
      console.log('2. user_email로 join 실패:', error2.message);
    } else {
      console.log('2. user_email로 join 성공! 데이터 수:', join2?.length);
    }
    
    // 3. 수동 방식 - leave 먼저 가져오고 employees 조회
    const { data: leaves } = await supabase
      .from('leave')
      .select('*')
      .eq('status', 'pending');
    
    console.log('\n=== 수동 조인 방식 ===');
    console.log('Pending leaves:', leaves?.length);
    
    // 각 leave에 대해 employees 정보 추가
    if (leaves && leaves.length > 0) {
      for (const leave of leaves) {
        const { data: emp } = await supabase
          .from('employees')
          .select('name, department, attendance_role')
          .eq('email', leave.user_email)
          .single();
        
        leave.employees = emp;
        if (leave.user_email === 'test@hansl.com') {
          console.log('test@hansl.com의 pending leave:');
          console.log('  - ID:', leave.id);
          console.log('  - employees 정보:', emp ? '있음' : '없음');
          if (emp) {
            console.log('    name:', emp.name);
          }
        }
      }
    }
    
  } catch (error) {
    console.error('오류:', error);
  }
}

testJoin2();