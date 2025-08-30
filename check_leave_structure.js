const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

const supabase = createClient(
  config.SUPABASE_URL,
  config.SUPABASE_SERVICE_KEY
);

async function checkStructure() {
  try {
    // leave 테이블의 샘플 데이터 확인
    const { data, error } = await supabase
      .from('leave')
      .select('*')
      .limit(1);
    
    if (error) {
      console.log('오류:', error);
    } else if (data && data.length > 0) {
      console.log('leave 테이블 컬럼:');
      console.log(Object.keys(data[0]));
      console.log('\n샘플 데이터:');
      console.log(data[0]);
    } else {
      console.log('데이터가 없습니다');
    }
    
  } catch (error) {
    console.error('예외:', error);
  }
}

checkStructure();
