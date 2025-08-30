const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

console.log('Using Service Key to bypass RLS...\n');

// Service key로 클라이언트 생성 (RLS 우회)
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function testDirectQuery() {
  try {
    // 1. leave 테이블 전체 조회 (RLS 우회)
    console.log('=== Leave 테이블 조회 (Service Key) ===');
    const { data: leaveData, error: leaveError, count } = await supabase
      .from('leave')
      .select('*', { count: 'exact' });
    
    if (leaveError) {
      console.error('Leave 조회 에러:', leaveError);
    } else {
      console.log(`✅ Leave 테이블: ${count || leaveData?.length || 0}개 레코드\n`);
      
      if (leaveData && leaveData.length > 0) {
        // 상태별 그룹핑
        const statusGroups = {};
        leaveData.forEach(item => {
          const status = item.status || 'no_status';
          if (!statusGroups[status]) statusGroups[status] = [];
          statusGroups[status].push(item);
        });
        
        console.log('상태별 분류:');
        Object.entries(statusGroups).forEach(([status, items]) => {
          console.log(`  ${status}: ${items.length}건`);
        });
        
        // 타입별 그룹핑
        const typeGroups = {};
        leaveData.forEach(item => {
          const type = item.type || 'no_type';
          if (!typeGroups[type]) typeGroups[type] = 0;
          typeGroups[type]++;
        });
        
        console.log('\n타입별 분류:');
        Object.entries(typeGroups).forEach(([type, count]) => {
          console.log(`  ${type}: ${count}건`);
        });
        
        // 승인된 연차만 필터
        const approvedAnnual = leaveData.filter(item => 
          item.status === 'approved' && 
          (item.type === '연차' || item.type === 'annual' || item.type === '연차휴가')
        );
        
        console.log(`\n승인된 연차: ${approvedAnnual.length}건`);
        
        // 샘플 데이터 출력
        console.log('\n=== 샘플 데이터 (최대 3개) ===');
        leaveData.slice(0, 3).forEach((item, idx) => {
          console.log(`\n${idx + 1}. ${item.name || 'N/A'} (${item.user_email})`);
          console.log(`   타입: ${item.type}, 상태: ${item.status}`);
          console.log(`   기간: ${item.start_date} ~ ${item.end_date}`);
          console.log(`   일수: ${item.days || item.total_days || 'N/A'}`);
        });
      }
    }
    
    // 2. employees 테이블도 확인
    console.log('\n\n=== Employees 테이블 확인 ===');
    const { data: empData, error: empError } = await supabase
      .from('employees')
      .select('name, email, used_annual_leave')
      .gt('used_annual_leave', 0)
      .order('used_annual_leave', { ascending: false })
      .limit(5);
    
    if (!empError && empData) {
      console.log(`사용연차가 있는 직원 Top 5:`);
      empData.forEach(emp => {
        console.log(`  ${emp.name}: ${emp.used_annual_leave}일`);
      });
    }
    
  } catch (error) {
    console.error('예상치 못한 에러:', error);
  }
}

testDirectQuery();