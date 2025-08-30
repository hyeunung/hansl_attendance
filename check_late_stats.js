const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkLateStatistics() {
  try {
    // 모든 employees 확인
    const { data: allEmployees, error: empError } = await supabase
      .from('employees')
      .select('id, email, name, attendance_role')
      .order('created_at', { ascending: false });
    
    console.log('=== All Employees ===');
    console.log('Total employees:', allEmployees?.length || 0);
    if (allEmployees && allEmployees.length > 0) {
      console.log(allEmployees);
    }
    
    // attendance_records 테이블 구조 확인
    const { data: sampleRecords, error: sampleError } = await supabase
      .from('attendance_records')
      .select('*')
      .limit(5);
    
    console.log('\n=== Sample attendance_records ===');
    console.log(sampleRecords);
    
    // 올해 지각 데이터 조회
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    
    const yearStart = `${year}-01-01`;
    const monthStart = `${year}-${String(month).padStart(2, '0')}-01`;
    const monthEnd = `${year}-${String(month).padStart(2, '0')}-31`;
    
    console.log('\nQuerying late records for year:', yearStart);
    console.log('Month range:', monthStart, 'to', monthEnd);
    
    // 전체 지각 레코드 확인
    const { data: allLateRecords, error: lateError } = await supabase
      .from('attendance_records')
      .select('*')
      .eq('status', '지각');
    
    console.log('\n=== All Late Records ===');
    console.log('Total late records:', allLateRecords?.length || 0);
    if (allLateRecords && allLateRecords.length > 0) {
      console.log('Sample late records:', allLateRecords.slice(0, 3));
    }
    
    // employee_id 필드 확인
    const { data: columns } = await supabase.rpc('get_table_columns', {
      table_name: 'attendance_records'
    }).catch(() => ({ data: null }));
    
    if (!columns) {
      // RPC 함수가 없으면 직접 쿼리
      const { data: testRecord } = await supabase
        .from('attendance_records')
        .select('*')
        .limit(1)
        .single();
      
      console.log('\n=== Table columns (from sample) ===');
      console.log(Object.keys(testRecord || {}));
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

checkLateStatistics();