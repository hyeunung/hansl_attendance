const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function updateViaRPC() {
  try {
    // RPC 함수 호출
    const { data, error } = await supabase
      .rpc('update_kang_leave_type');

    if (error) {
      console.error('Error calling RPC:', error);
    } else {
      console.log('Successfully called RPC');
      
      // 업데이트 결과 확인
      const { data: checkData, error: checkError } = await supabase
        .from('leave')
        .select('*')
        .eq('id', 441);
        
      if (checkError) {
        console.error('Error checking result:', checkError);
      } else {
        console.log('Updated data:', checkData);
      }
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

updateViaRPC();