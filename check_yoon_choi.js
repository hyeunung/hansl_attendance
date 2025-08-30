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

  if (!response.ok) {
    throw new Error(await response.text());
  }

  return response.json();
}

async function checkSpecificEmployees() {
  console.log('=== 윤은호, 최창열 상세 확인 ===\n');

  // 윤은호 확인
  const yoonQuery = `
    SELECT 
      name,
      type,
      start_date,
      end_date,
      EXTRACT(MONTH FROM start_date) as month,
      EXTRACT(DAY FROM start_date) as day,
      CASE 
        WHEN type = 'annual' THEN 1
        WHEN type IN ('half_am', 'half_pm') THEN 0.5
        ELSE 0
      END as days
    FROM leave
    WHERE name = '윤은호'
      AND status = 'approved'
      AND start_date >= '2025-01-01'
      AND start_date <= '2025-08-31'
    ORDER BY start_date
  `;

  const yoonData = await runQuery(yoonQuery);
  
  console.log('윤은호 DB 레코드:');
  let yoonTotal = 0;
  const yoonByMonth = {};
  
  yoonData.forEach(record => {
    const monthKey = `${record.month}월`;
    if (!yoonByMonth[monthKey]) {
      yoonByMonth[monthKey] = { days: 0, details: [] };
    }
    yoonByMonth[monthKey].days += parseFloat(record.days);
    yoonByMonth[monthKey].details.push(`${record.day}일(${record.type === 'annual' ? '연차' : record.type === 'half_am' ? '오전반차' : '오후반차'})`);
    yoonTotal += parseFloat(record.days);
  });
  
  Object.entries(yoonByMonth).forEach(([month, data]) => {
    console.log(`  ${month}: ${data.days}일 - ${data.details.join(', ')}`);
  });
  console.log(`  총합: ${yoonTotal}일\n`);

  // 최창열 확인
  const choiQuery = `
    SELECT 
      name,
      type,
      start_date,
      end_date,
      EXTRACT(MONTH FROM start_date) as month,
      EXTRACT(DAY FROM start_date) as day,
      CASE 
        WHEN type = 'annual' THEN 1
        WHEN type IN ('half_am', 'half_pm') THEN 0.5
        ELSE 0
      END as days
    FROM leave
    WHERE name = '최창열'
      AND status = 'approved'
      AND start_date >= '2025-01-01'
      AND start_date <= '2025-08-31'
    ORDER BY start_date
  `;

  const choiData = await runQuery(choiQuery);
  
  console.log('최창열 DB 레코드:');
  let choiTotal = 0;
  const choiByMonth = {};
  
  choiData.forEach(record => {
    const monthKey = `${record.month}월`;
    if (!choiByMonth[monthKey]) {
      choiByMonth[monthKey] = { days: 0, details: [] };
    }
    choiByMonth[monthKey].days += parseFloat(record.days);
    choiByMonth[monthKey].details.push(`${record.day}일(${record.type === 'annual' ? '연차' : record.type === 'half_am' ? '오전반차' : '오후반차'})`);
    choiTotal += parseFloat(record.days);
  });
  
  Object.entries(choiByMonth).forEach(([month, data]) => {
    console.log(`  ${month}: ${data.days}일 - ${data.details.join(', ')}`);
  });
  console.log(`  총합: ${choiTotal}일\n`);

  console.log('=== 엑셀 데이터와 비교 ===');
  console.log('윤은호 엑셀: 10.5일 (1월 1.5, 2월 1.5, 3월 2.5, 4월 1.5, 5월 1, 6월 2, 7월 1.5)');
  console.log(`윤은호 DB: ${yoonTotal}일\n`);
  
  console.log('최창열 엑셀: 10일 (2월 0.5, 3월 0.5, 4월 2, 5월 1, 6월 3, 7월 1.5, 8월 1.5)');
  console.log(`최창열 DB: ${choiTotal}일`);
}

checkSpecificEmployees();