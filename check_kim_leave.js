const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

const supabase = createClient(
  config.SUPABASE_URL,
  config.SUPABASE_SERVICE_KEY
);

async function checkKimLeave() {
  try {
    // 1. 김경태님 현재 연차 정보 확인
    const { data: employee, error: empError } = await supabase
      .from('employees')
      .select('name, email, annual_leave, used_annual_leave')
      .eq('email', 'kkt@hansl.com')
      .single();
    
    if (empError) {
      console.log('조회 오류:', empError);
      return;
    }
    
    console.log('=== 김경태님 연차 현황 ===');
    console.log('부여된 연차:', employee.annual_leave);
    console.log('사용한 연차:', employee.used_annual_leave);
    console.log('남은 연차:', employee.annual_leave - employee.used_annual_leave);
    
    // 2. 승인된 연차 목록 확인
    const { data: approvedLeaves, error: leaveError } = await supabase
      .from('leave')
      .select('type, start_date, end_date, reason')
      .eq('user_email', 'kkt@hansl.com')
      .eq('status', 'approved')
      .in('type', ['annual', 'half_am', 'half_pm'])
      .order('start_date');
    
    if (!leaveError && approvedLeaves) {
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
      console.log('총 사용 연차:', totalDays, '일');
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
      officialLeaves.forEach(leave => {
        console.log(`- ${leave.start_date} ~ ${leave.end_date}: ${leave.reason}`);
      });
    }
    
    // 4. 기대값 확인
    console.log('\n=== 기대값과 비교 ===');
    console.log('예상 사용 연차: 7일');
    console.log('실제 사용 연차:', employee.used_annual_leave, '일');
    console.log('예상 남은 연차: 13일 (20 - 7)');
    console.log('실제 남은 연차:', employee.annual_leave - employee.used_annual_leave, '일');
    
    if (employee.used_annual_leave !== 7) {
      console.log('\n⚠️  사용 연차가 예상과 다릅니다!');
      console.log('update_used_annual_leave 함수를 수동으로 실행해야 할 수 있습니다.');
    }
    
  } catch (error) {
    console.error('오류:', error);
  }
}

checkKimLeave();