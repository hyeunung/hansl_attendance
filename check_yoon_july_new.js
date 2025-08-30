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

async function checkYoonJuly() {
  console.log('=== 윤은호 7월 데이터 확인 ===\n');
  
  // 윤은호 7월 데이터 확인
  const julyData = await runQuery(`
    SELECT 
      type,
      start_date,
      EXTRACT(DAY FROM start_date) as day
    FROM leave
    WHERE name = '윤은호'
      AND status = 'approved'
      AND EXTRACT(MONTH FROM start_date) = 7
      AND EXTRACT(YEAR FROM start_date) = 2025
    ORDER BY start_date
  `);
  
  console.log('윤은호 7월 DB 데이터:');
  let julyTotal = 0;
  julyData.forEach(r => {
    const days = r.type === 'annual' ? 1 : 0.5;
    julyTotal += days;
    console.log(`  ${r.day}일: ${r.type === 'annual' ? '연차' : r.type === 'half_am' ? '오전반차' : '오후반차'} (${days}일)`);
  });
  console.log(`7월 합계: ${julyTotal}일`);
  console.log('\n정답: 14일(1일) + 15일 오후반차(0.5일) = 1.5일만 있어야 함');
  
  // 잘못된 데이터 찾기
  const wrongDates = julyData.filter(r => {
    const day = parseInt(r.day);
    return !(day === 14 || (day === 15 && r.type === 'half_pm'));
  });
  
  if (wrongDates.length > 0) {
    console.log('\n❌ 삭제해야 할 데이터:');
    wrongDates.forEach(r => {
      console.log(`  ${r.day}일 (${r.type})`);
    });
  }
  
  // 전체 합계
  const summary = await runQuery(`
    SELECT 
      SUM(CASE 
        WHEN type = 'annual' THEN 1
        WHEN type IN ('half_am', 'half_pm') THEN 0.5
      END) as total_days
    FROM leave
    WHERE name = '윤은호'
      AND status = 'approved'
      AND start_date >= '2025-01-01'
      AND start_date <= '2025-08-31'
  `);
  
  console.log(`\n윤은호 전체 합계: ${summary[0].total_days}일`);
  console.log('정답: 10.5일이어야 함');
}

checkYoonJuly();