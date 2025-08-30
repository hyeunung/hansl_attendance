const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

async function applyOfficialLeave() {
  try {
    console.log('김경태님 공가 처리 시작...\n');
    
    // 김경태님 이메일 직접 사용
    const employeeEmail = 'kkt@hansl.com';
    const employeeName = '김경태';
    
    console.log('처리 대상:');
    console.log('- 이름:', employeeName);
    console.log('- 이메일:', employeeEmail);
    console.log();
    
    // 기존 연차 확인
    const dates = ['2025-01-31', '2025-02-11', '2025-02-12', '2025-02-13'];
    
    // 기존 연차 조회
    const { data: existingLeaves } = await supabase
      .from('leave_requests')
      .select('*')
      .eq('user_email', employeeEmail)
      .gte('start_date', '2025-01-31')
      .lte('start_date', '2025-02-13');
    
    if (existingLeaves && existingLeaves.length > 0) {
      console.log('기존 연차 신청 내역:');
      existingLeaves.forEach(leave => {
        console.log(`- ${leave.start_date} ~ ${leave.end_date}: ${leave.type} (${leave.status}) - ${leave.reason || ''}`);
      });
      
      // 해당 날짜의 기존 연차 삭제
      const { error: deleteError } = await supabase
        .from('leave_requests')
        .delete()
        .eq('user_email', employeeEmail)
        .in('start_date', dates);
      
      if (!deleteError) {
        console.log('기존 연차 삭제 완료\n');
      } else {
        console.log('삭제 오류:', deleteError.message);
      }
    } else {
      console.log('기존 연차 신청 내역이 없습니다.\n');
    }
    
    // 공가 등록
    console.log('공가 등록 시작...');
    
    // 1/31 장인어른 상
    const { data: jan31Data, error: jan31Error } = await supabase
      .from('leave_requests')
      .insert({
        user_email: employeeEmail,
        type: 'official',
        start_date: '2025-01-31',
        end_date: '2025-01-31',
        days: 1,
        reason: '장인어른 상',
        status: 'approved',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select();
    
    if (jan31Error) {
      console.log('1/31 공가 처리 실패:', jan31Error.message);
    } else {
      console.log('✅ 1/31 장인어른 상 - 공가 처리 완료');
      console.log('   등록 ID:', jan31Data[0].id);
    }
    
    // 2/11~2/13 할머니 상
    const { data: feb11Data, error: feb11to13Error } = await supabase
      .from('leave_requests')
      .insert({
        user_email: employeeEmail,
        type: 'official',
        start_date: '2025-02-11',
        end_date: '2025-02-13',
        days: 3,
        reason: '할머니 상',
        status: 'approved',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select();
    
    if (feb11to13Error) {
      console.log('2/11~2/13 공가 처리 실패:', feb11to13Error.message);
    } else {
      console.log('✅ 2/11~2/13 할머니 상 - 공가 처리 완료');
      console.log('   등록 ID:', feb11Data[0].id);
    }
    
    // annual_leave_history에서 해당 날짜 기록 삭제 (공가는 연차 차감 안 함)
    const { error: historyError } = await supabase
      .from('annual_leave_history')
      .delete()
      .eq('employee_email', employeeEmail)
      .in('leave_date', dates);
    
    if (!historyError) {
      console.log('✅ 연차 사용 기록 정리 완료');
    }
    
    console.log('\n✅ 공가 처리가 모두 완료되었습니다!');
    
    // 결과 확인
    const { data: finalLeaves } = await supabase
      .from('leave_requests')
      .select('*')
      .eq('user_email', employeeEmail)
      .eq('type', 'official')
      .order('start_date');
    
    if (finalLeaves && finalLeaves.length > 0) {
      console.log('\n등록된 공가 내역:');
      finalLeaves.forEach(leave => {
        console.log(`- ${leave.start_date} ~ ${leave.end_date}: ${leave.reason} (${leave.days}일)`);
      });
    }
    
  } catch (error) {
    console.error('오류 발생:', error);
  }
}

applyOfficialLeave();