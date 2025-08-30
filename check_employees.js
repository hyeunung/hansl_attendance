const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function checkEmployees() {
  try {
    // employees 테이블 확인
    const { data: employees, error } = await supabase
      .from('employees')
      .select('name, email, department')
      .limit(10);
    
    if (error) {
      console.log('Error:', error.message);
      return;
    }
    
    console.log('직원 수:', employees ? employees.length : 0);
    
    if (employees && employees.length > 0) {
      console.log('\n직원 목록:');
      employees.forEach(emp => {
        console.log(`- ${emp.name} (${emp.email}) - ${emp.department}`);
      });
    }
    
    // 김경태 검색
    const { data: kim } = await supabase
      .from('employees')
      .select('*')
      .or('name.ilike.%김경태%,name.ilike.%경태%')
      .single();
    
    if (kim) {
      console.log('\n김경태님 발견:', kim);
    } else {
      console.log('\n김경태님을 찾을 수 없습니다.');
      
      // 비슷한 이름 검색
      const { data: similar } = await supabase
        .from('employees')
        .select('name, email')
        .or('name.ilike.%김%,name.ilike.%경%,name.ilike.%태%');
      
      if (similar && similar.length > 0) {
        console.log('\n비슷한 이름:');
        similar.forEach(emp => console.log(`- ${emp.name}`));
      }
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

checkEmployees();
