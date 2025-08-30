const fetch = require('node-fetch');
const fs = require('fs');

const ACCESS_TOKEN = 'sbp_2c485a033dfe9b5fcf41ff624f28dca65f82231e';
const PROJECT_REF = 'qvhbigvdfyvhoegkhvef';

async function executeFix() {
  try {
    console.log('윤은호, 최창열 수정 중...');
    
    const sqlContent = fs.readFileSync('fix_yoon_choi.sql', 'utf-8');
    
    const response = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query: sqlContent })
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('Error:', error);
      return;
    }

    const result = await response.json();
    console.log('✅ 수정 완료!');
    
    // 마지막 쿼리 결과 확인
    if (result && result.length > 0) {
      console.log('\n수정 후 결과:');
      result.forEach(emp => {
        console.log(`${emp.name}: ${emp.total_days}일 (${emp.records}건)`);
      });
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

executeFix();