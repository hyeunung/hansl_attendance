const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

const supabase = createClient(
  config.SUPABASE_URL,
  config.SUPABASE_SERVICE_KEY
);

async function checkKimLeave() {
  try {
    // 1. 김경태님 정보 확인 (모든 컬럼)
    const { data: employee, error: empError } = await supabase
      .from('employees')
      .select('*')
      .eq('email', 'kkt@hansl.com')
      .single();
    
    if (empError) {
      console.log('조회 오류:', empError);
      return;
    }
    
    console.log('=== 김경태님 정보 ===');
    // 연차 관련 컬럼만 출력
    Object.keys(employee).forEach(key => {
      if (key.toLowerCase().includes('leave') || key.toLowerCase().includes('annual')) {
        console.log(`${key}:`, employee[key]);
      }
    });
    
    // 연차 관련 컬럼 찾기
    const grantedLeave = employee.granted_annual_leave || employee.annual_leave_granted || 0;
    const usedLeave = employee.used_annual_leave || employee.annual_leave_used || 0;
    const remainingLeave = employee.remaining_annual_leave || (grantedLeave - usedLeave);
    
    console.log('\n=== 연차 현황 ===');
    console.log('부여된 연차:', grantedLeave);
    console.log('사용한 연차:', usedLeave);
    console.log('남은 연차:', remainingLeave);
    
    // 2. 승인된 연차 확인
    const { data: approvedLeaves } = await supabase
      .from('leave')
      .select('type, start_date, end_date, reason')
      .eq('user_email', 'kkt@hansl.com')
      .eq('status', 'approved')
      .in('type', ['annual', 'half_am', 'half_pm'])
      .order('start_date');
    
    if (approvedLeaves) {
      console.log('\n=== 승인된 연차 목록 ===');
      let totalDays = 0;
      approvedLeaves.forEach(leave => {
        const start = new Date(leave.start_date);
        const end = new Date(leave.end_date);
        const days = Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1;
        const actualDays = leave.type.includes('half') ? 0.5 : days;
        totalDays += actualDays;
        console.log(`- ${leave.start_date} ~ ${leave.end_date}: ${leave.type} (${actualDays}일)`);
      });
      console.log('총 사용 연차 (계산):', totalDays, '일');
    }
    
    // 3. 공가 확인
    const { data: officialLeaves } = await supabase
      .from('leave')
      .select('type, start_date, end_date, reason')
      .eq('user_email', 'kkt@hansl.com')
      .eq('type', 'official')
      .order('start_date');
    
    if (officialLeaves && officialLeaves.length > 0) {
      console.log('\n=== 공가 목록 (연차 차감 안 됨) ===');
      let officialDays = 0;
      officialLeaves.forEach(leave => {
        const start = new Date(leave.start_date);
        const end = new Date(leave.end_date);
        const days = Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1;
        officialDays += days;
        console.log(`- ${leave.start_date} ~ ${leave.end_date}: ${leave.reason} (${days}일)`);
      });
      console.log('총 공가:', officialDays, '일');
    }
    
    console.log('\n=== 예상값 ===');
    console.log('부여 연차: 20일');
    console.log('사용 연차: 7일 (공가 제외)');
    console.log('남은 연차: 13일');
    
  } catch (error) {
    console.error('오류:', error);
  }
}

checkKimLeave();