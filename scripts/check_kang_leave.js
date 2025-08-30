const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkKangLeave() {
  try {
    // 강영은님의 2025년 8월 18일 데이터 확인
    const { data, error } = await supabase
      .from('leave')
      .select('*')
      .eq('name', '강영은')
      .eq('start_date', '2025-08-18');

    if (error) {
      console.error('Error checking leave:', error);
    } else {
      console.log('Current Kang Young-eun\'s leave data:', data);
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

checkKangLeave();