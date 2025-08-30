const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

async function checkTables() {
  try {
    // leave_requests 테이블 확인
    const { data: leaveData, error: leaveError } = await supabase
      .from('leave_requests')
      .select('*')
      .limit(1);
    
    console.log('leave_requests 테이블 접근 가능:', \!leaveError);
    if (leaveError) console.log('leave_requests 오류:', leaveError.message);
    
    // leaves 테이블 확인
    const { data: leavesData, error: leavesError } = await supabase
      .from('leaves')
      .select('*')
      .limit(1);
    
    console.log('leaves 테이블 접근 가능:', \!leavesError);
    if (leavesError) console.log('leaves 오류:', leavesError.message);
    
    // annual_leave_history 테이블 확인
    const { data: historyData, error: historyError } = await supabase
      .from('annual_leave_history')
      .select('*')
      .limit(1);
    
    console.log('annual_leave_history 테이블 접근 가능:', \!historyError);
    if (historyError) console.log('annual_leave_history 오류:', historyError.message);
    
  } catch (error) {
    console.error('오류:', error);
  }
}

checkTables();
