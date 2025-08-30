const fetch = require('node-fetch');
const ACCESS_TOKEN = 'sbp_2c485a033dfe9b5fcf41ff624f28dca65f82231e';
const PROJECT_REF = 'qvhbigvdfyvhoegkhvef';

async function runQuery(query) {
  const response = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${ACCESS_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query })
  });
  if (!response.ok) throw new Error(await response.text());
  return response.json();
}

async function checkYoonAllMonths() {
  console.log('=== 윤은호 전체 월별 데이터 확인 ===\n');
  
  const expectedData = {
    1: { days: 1.5, detail: '10일(1일) + 17일 오후반차(0.5일)' },
    2: { days: 1.5, detail: '7일(1일) + 14일 오후반차(0.5일)' },
    3: { days: 2.5, detail: '17일(1일) + 18일(1일) + 28일 오후반차(0.5일)' },
    4: { days: 1.5, detail: '11일(1일) + 22일 오후반차(0.5일)' },
    5: { days: 1, detail: '22일(1일)' },
    6: { days: 2, detail: '10일 오후반차(0.5일) + 23일 오후반차(0.5일) + 27일(1일)' },
    7: { days: 1.5, detail: '14일(1일) + 15일 오후반차(0.5일)' },
    8: { days: 0, detail: '없음' }
  };
  
  let totalExpected = 0;
  let totalActual = 0;
  
  for (let month = 1; month <= 8; month++) {
    const monthData = await runQuery(`
      SELECT 
        type,
        start_date,
        EXTRACT(DAY FROM start_date) as day
      FROM leave
      WHERE name = '윤은호'
        AND status = 'approved'
        AND EXTRACT(MONTH FROM start_date) = ${month}
        AND EXTRACT(YEAR FROM start_date) = 2025
      ORDER BY start_date
    `);
    
    let monthTotal = 0;
    const details = [];
    
    monthData.forEach(r => {
      const days = r.type === 'annual' ? 1 : 0.5;
      monthTotal += days;
      details.push(`${r.day}일(${r.type === 'annual' ? '연차' : r.type === 'half_pm' ? '오후반차' : '오전반차'})`);
    });
    
    totalExpected += expectedData[month].days;
    totalActual += monthTotal;
    
    console.log(`${month}월:`);
    console.log(`  예상: ${expectedData[month].days}일 - ${expectedData[month].detail}`);
    console.log(`  실제: ${monthTotal}일 - ${details.join(', ') || '없음'}`);
    
    if (Math.abs(monthTotal - expectedData[month].days) > 0.01) {
      console.log(`  ❌ 차이: ${(monthTotal - expectedData[month].days).toFixed(1)}일`);
      
      // 잘못된 데이터 찾기
      if (month === 2) {
        // 2월은 7일과 14일 오후반차만 있어야 함
        const wrongDates = monthData.filter(r => {
          const day = parseInt(r.day);
          return !(day === 7 && r.type === 'annual') && !(day === 14 && r.type === 'half_pm');
        });
        if (wrongDates.length > 0) {
          console.log('     삭제 필요:', wrongDates.map(r => `${r.day}일(${r.type})`).join(', '));
        }
      }
    } else {
      console.log(`  ✅ 일치`);
    }
    console.log('');
  }
  
  console.log('='.repeat(50));
  console.log(`예상 합계: ${totalExpected}일`);
  console.log(`실제 합계: ${totalActual}일`);
  console.log(`차이: ${(totalActual - totalExpected).toFixed(1)}일`);
}

checkYoonAllMonths();