const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseKey) {
  console.error('SUPABASE_SERVICE_ROLE_KEY is required');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function fixTriggerAndUpdate() {
  try {
    console.log('Attempting to fix trigger and update...');
    
    // 1. 먼저 트리거 삭제 시도
    const dropTriggerSQL = `DROP TRIGGER IF EXISTS update_leave_updated_at ON leave;`;
    
    // 2. 그다음 업데이트
    const updateSQL = `UPDATE leave SET type = 'half_pm' WHERE id = 441 RETURNING *;`;
    
    // Edge Function 호출로 SQL 실행
    const response = await fetch(`${supabaseUrl}/functions/v1/fix-kang-leave`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        dropTrigger: dropTriggerSQL,
        updateLeave: updateSQL
      })
    });

    const result = await response.json();
    console.log('Result:', result);
    
    // 결과 확인
    const { data: checkData, error: checkError } = await supabase
      .from('leave')
      .select('id, name, type, start_date')
      .eq('id', 441);
    
    if (!checkError && checkData) {
      console.log('Final data:', checkData);
    }
  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

fixTriggerAndUpdate();