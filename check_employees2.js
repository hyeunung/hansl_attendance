const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// ANON KEY 사용
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

async function checkEmployees() {
  try {
    // employees 테이블 확인
    const { data: employees, error } = await supabase
      .from('employees')
      .select('name, email, department')
      .limit(20);
    
    if (error) {
      console.log('Error:', error.message);
      console.log('Error details:', error);
      return;
    }
    
    console.log('직원 수:', employees ? employees.length : 0);
    
    if (employees && employees.length > 0) {
      console.log('\n직원 목록:');
      employees.forEach(emp => {
        console.log(`- ${emp.name} (${emp.email})`);
      });
      
      // 김경태 찾기
      const kimKyungTae = employees.find(emp => 
        emp.name && (emp.name.includes('경태') || emp.name.includes('김경태'))
      );
      
      if (kimKyungTae) {
        console.log('\n✅ 김경태님 발견:', kimKyungTae);
      } else {
        console.log('\n김경태님이 목록에 없습니다.');
      }
    } else {
      console.log('직원 데이터가 없습니다.');
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

checkEmployees();
