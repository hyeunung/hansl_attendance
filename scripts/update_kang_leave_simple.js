const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function updateKangLeave() {
  try {
    // 강영은님의 2025년 8월 18일 연차를 오후반차로 수정
    const { data, error } = await supabase
      .from('leave')
      .update({ 
        type: 'half_afternoon'
      })
      .eq('id', 441)  // ID로 직접 지정
      .select();

    if (error) {
      console.error('Error updating leave:', error);
    } else {
      console.log('Successfully updated Kang Young-eun\'s leave:', data);
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

updateKangLeave();