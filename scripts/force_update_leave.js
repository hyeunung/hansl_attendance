const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
// Service role key를 사용해 RLS 우회
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

async function forceUpdateLeave() {
  try {
    console.log('Starting update...');
    
    // Service role key로 RLS 우회하여 직접 업데이트
    const { data, error } = await supabase
      .from('leave')
      .update({ 
        type: 'half_pm'
      })
      .eq('id', 441)
      .select();

    if (error) {
      console.error('Update error:', error);
      
      // 오류시 RPC로 시도
      console.log('Trying with RPC...');
      const { error: rpcError } = await supabase.rpc('execute_sql', {
        query: "UPDATE leave SET type = 'half_pm' WHERE id = 441"
      });
      
      if (rpcError) {
        console.error('RPC error:', rpcError);
      }
    } else {
      console.log('Successfully updated:', data);
    }
    
    // 결과 확인
    const { data: result, error: checkError } = await supabase
      .from('leave')
      .select('id, name, type, start_date')
      .eq('id', 441);
    
    if (!checkError && result) {
      console.log('Final result:', result);
    }
  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

forceUpdateLeave();