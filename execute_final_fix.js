const fetch = require('node-fetch');
const fs = require('fs');

const ACCESS_TOKEN = 'sbp_2c485a033dfe9b5fcf41ff624f28dca65f82231e';
const PROJECT_REF = 'qvhbigvdfyvhoegkhvef';

async function execute() {
  try {
    console.log('윤은호 수정 및 전체 직원 업데이트 중...');
    
    const sqlContent = fs.readFileSync('fix_yoon_and_update_all.sql', 'utf-8');
    
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
    console.log('✅ 완료!\n');
    
    if (result && result.length > 0) {
      console.log('직원별 연차 현황 (권혁진 제외):');
      console.log('이름\t\t사용\t남은\t부여\t레코드수');
      console.log('='.repeat(60));
      
      let totalUsed = 0;
      let totalRemaining = 0;
      let totalGranted = 0;
      
      result.forEach(emp => {
        totalUsed += parseFloat(emp.used_annual_leave || 0);
        totalRemaining += parseFloat(emp.remaining_annual_leave || 0);
        totalGranted += parseInt(emp.granted || 0);
        
        console.log(
          `${emp.name.padEnd(12)}\t` +
          `${emp.used_annual_leave}\t` +
          `${emp.remaining_annual_leave}\t` +
          `${emp.granted}\t` +
          `${emp.leave_records}`
        );
      });
      
      console.log('='.repeat(60));
      console.log(`총계\t\t${totalUsed.toFixed(1)}\t${totalRemaining.toFixed(1)}\t${totalGranted}`);
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

execute();