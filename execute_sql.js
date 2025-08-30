const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// Service key 사용
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function executeSql() {
  try {
    console.log('SQL 실행 시작...\n');
    
    // 1. 김경태님 공가 처리
    console.log('1. 김경태님 공가 처리 중...');
    
    // 기존 데이터 삭제
    const { error: deleteError } = await supabase
      .from('leave_requests')
      .delete()
      .eq('user_email', 'kkt@hansl.com')
      .in('start_date', ['2025-01-31', '2025-02-11']);
    
    if (deleteError) {
      console.log('기존 데이터 삭제 오류:', deleteError);
    }
    
    // 1/31 장인어른 상 등록
    const { data: jan31, error: jan31Error } = await supabase
      .from('leave_requests')
      .insert({
        user_email: 'kkt@hansl.com',
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
      console.log('1/31 공가 등록 오류:', jan31Error);
    } else {
      console.log('✅ 1/31 장인어른 상 공가 등록 완료');
    }
    
    // 2/11~2/13 할머니 상 등록
    const { data: feb, error: febError } = await supabase
      .from('leave_requests')
      .insert({
        user_email: 'kkt@hansl.com',
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
    
    if (febError) {
      console.log('2/11~2/13 공가 등록 오류:', febError);
    } else {
      console.log('✅ 2/11~2/13 할머니 상 공가 등록 완료');
    }
    
    // annual_leave_history에서 삭제
    await supabase
      .from('annual_leave_history')
      .delete()
      .eq('employee_email', 'kkt@hansl.com')
      .in('leave_date', ['2025-01-31', '2025-02-11', '2025-02-12', '2025-02-13']);
    
    console.log('✅ 연차 사용 기록 정리 완료');
    
    // 결과 확인
    const { data: result } = await supabase
      .from('leave_requests')
      .select('*')
      .eq('user_email', 'kkt@hansl.com')
      .eq('type', 'official')
      .order('start_date');
    
    if (result && result.length > 0) {
      console.log('\n등록된 공가:');
      result.forEach(r => {
        console.log(`- ${r.start_date} ~ ${r.end_date}: ${r.reason}`);
      });
    }
    
    console.log('\n✅ 김경태님 공가 처리 완료\!\n');
    
  } catch (error) {
    console.error('오류:', error);
  }
}

executeSql();
