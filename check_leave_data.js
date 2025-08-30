const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function checkLeaveData() {
  try {
    // 1. 전체 leave 데이터 확인
    const { data: allLeaves, error: leaveError } = await supabase
      .from('leave')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (leaveError) {
      console.error('Leave 조회 오류:', leaveError);
      return;
    }
    
    console.log('\n=== 전체 Leave 데이터 ===');
    console.log('총 개수:', allLeaves?.length || 0);
    
    // 2. 승인된 leave만 확인
    const approvedLeaves = allLeaves?.filter(l => l.status === 'approved') || [];
    console.log('승인된 개수:', approvedLeaves.length);
    
    // 3. 최근 승인된 연차/출장 10개 표시
    console.log('\n=== 최근 승인된 연차/출장 (10개) ===');
    approvedLeaves.slice(0, 10).forEach(leave => {
      console.log(`- ${leave.name} (${leave.user_email}): ${leave.type} | ${leave.start_date} ~ ${leave.end_date} | 상태: ${leave.status}`);
    });
    
    // 4. test@hansl의 leave 확인
    const testLeaves = allLeaves?.filter(l => l.user_email === 'test@hansl') || [];
    console.log('\n=== test@hansl의 Leave 데이터 ===');
    console.log('총 개수:', testLeaves.length);
    testLeaves.forEach(leave => {
      console.log(`- ${leave.type} | ${leave.start_date} ~ ${leave.end_date} | 상태: ${leave.status}`);
    });
    
  } catch (error) {
    console.error('오류 발생:', error);
  }
}

checkLeaveData();