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

async function checkColumns() {
  const query = `
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_name = 'employees'
    ORDER BY ordinal_position
  `;
  
  const columns = await runQuery(query);
  console.log('Employees 테이블 컬럼:');
  columns.forEach(col => {
    console.log(`  - ${col.column_name}: ${col.data_type}`);
  });
}

checkColumns();