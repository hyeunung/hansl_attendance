const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function checkTables() {
  try {
    // leaves 테이블 확인
    const { data: leaves, error: leavesError } = await supabase
      .from('leaves')
      .select('*')
      .limit(1);
    
    if (\!leavesError) {
      console.log('✅ leaves 테이블 존재');
      console.log('샘플 데이터:', leaves);
    } else {
      console.log('leaves 테이블 오류:', leavesError);
    }
    
    // leave 테이블 확인
    const { data: leave, error: leaveError } = await supabase
      .from('leave')
      .select('*')
      .limit(1);
    
    if (\!leaveError) {
      console.log('✅ leave 테이블 존재');
      console.log('샘플 데이터:', leave);
    } else {
      console.log('leave 테이블 오류:', leaveError);
    }
    
    // annual_leaves 테이블 확인
    const { data: annual, error: annualError } = await supabase
      .from('annual_leaves')
      .select('*')
      .limit(1);
    
    if (\!annualError) {
      console.log('✅ annual_leaves 테이블 존재');
      console.log('샘플 데이터:', annual);
    } else {
      console.log('annual_leaves 테이블 오류:', annualError);
    }
    
  } catch (error) {
    console.error('오류:', error);
  }
}

checkTables();
