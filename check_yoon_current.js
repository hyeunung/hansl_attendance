const fetch = require('node-fetch');

const ACCESS_TOKEN = 'sbp_2c485a033dfe9b5fcf41ff624f28dca65f82231e';
const PROJECT_REF = 'qvhbigvdfyvhoegkhvef';

async function check() {
  const query = `
    SELECT 
      name,
      type,
      start_date,
      EXTRACT(MONTH FROM start_date) as month,
      EXTRACT(DAY FROM start_date) as day,
      CASE 
        WHEN type = 'annual' THEN 1
        WHEN type IN ('half_am', 'half_pm') THEN 0.5
      END as days
    FROM leave
    WHERE name = '윤은호'
      AND status = 'approved'
      AND start_date >= '2025-01-01'
      AND start_date <= '2025-12-31'
    ORDER BY start_date
  `;
  
  const response = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${ACCESS_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query })
  });

  const data = await response.json();
  
  console.log('윤은호 현재 DB 레코드:');
  let total = 0;
  const byMonth = {};
  
  data.forEach(r => {
    const m = r.month + '월';
    if (!byMonth[m]) byMonth[m] = 0;
    byMonth[m] += parseFloat(r.days);
    total += parseFloat(r.days);
  });
  
  Object.entries(byMonth).forEach(([m, d]) => {
    console.log(`  ${m}: ${d}일`);
  });
  console.log(`  총: ${total}일`);
  
  console.log('\n상세:');
  data.forEach(r => {
    console.log(`  ${r.month}/${r.day} - ${r.type} (${r.days}일)`);
  });
  
  console.log('\n정답: 10.5일이어야 함');
  console.log('차이:', total - 10.5, '일 더 많음');
}

check();