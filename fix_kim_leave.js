const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

const supabase = createClient(
  config.SUPABASE_URL,
  config.SUPABASE_SERVICE_KEY
);

async function fixKimLeave() {
  try {
    console.log('김경태님 연차 재계산 시작...\n');
    
    // 1. 먼저 2/12, 2/13 연차를 삭제 (공가와 중복)
    const { error: deleteError } = await supabase
      .from('leave')
      .delete()
      .eq('user_email', 'kkt@hansl.com')
      .eq('type', 'annual')
      .in('start_date', ['2025-02-12', '2025-02-13']);
    
    if (deleteError) {
      console.log('중복 연차 삭제 오류:', deleteError);
    } else {
      console.log('✅ 2/12, 2/13 중복 연차 삭제 완료');
    }
    
    // 2. 승인된 연차 다시 계산
    const { data: approvedLeaves } = await supabase
      .from('leave')
      .select('type, start_date, end_date')
      .eq('user_email', 'kkt@hansl.com')
      .eq('status', 'approved')
      .in('type', ['annual', 'half_am', 'half_pm']);
    
    let totalUsed = 0;
    if (approvedLeaves) {
      approvedLeaves.forEach(leave => {
        const start = new Date(leave.start_date);
        const end = new Date(leave.end_date);
        const days = Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1;
        const actualDays = leave.type.includes('half') ? 0.5 : days;
        totalUsed += actualDays;
      });
    }
    
    console.log('✅ 실제 사용 연차 계산:', totalUsed, '일');
    
    // 3. employees 테이블 업데이트
    const { error: updateError } = await supabase
      .from('employees')
      .update({
        used_annual_leave: totalUsed,
        remaining_annual_leave: 20 - totalUsed
      })
      .eq('email', 'kkt@hansl.com');
    
    if (updateError) {
      console.log('업데이트 오류:', updateError);
    } else {
      console.log('✅ 연차 정보 업데이트 완료');
      console.log('   - 사용 연차: ' + totalUsed + '일');
      console.log('   - 남은 연차: ' + (20 - totalUsed) + '일');
    }
    
    // 4. 결과 확인
    const { data: result } = await supabase
      .from('employees')
      .select('annual_leave_granted_current_year, used_annual_leave, remaining_annual_leave')
      .eq('email', 'kkt@hansl.com')
      .single();
    
    if (result) {
      console.log('\n=== 최종 연차 현황 ===');
      console.log('부여 연차:', result.annual_leave_granted_current_year);
      console.log('사용 연차:', result.used_annual_leave);
      console.log('남은 연차:', result.remaining_annual_leave);
    }
    
  } catch (error) {
    console.error('오류:', error);
  }
}

fixKimLeave();