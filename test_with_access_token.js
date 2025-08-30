const fetch = require('node-fetch');

const ACCESS_TOKEN = 'sbp_2c485a033dfe9b5fcf41ff624f28dca65f82231e';
const PROJECT_REF = 'qvhbigvdfyvhoegkhvef';

async function queryDatabase() {
  try {
    // SQL 쿼리 실행
    const queries = [
      "SELECT COUNT(*) as total_count FROM leave",
      "SELECT status, COUNT(*) as count FROM leave GROUP BY status",
      "SELECT type, COUNT(*) as count FROM leave GROUP BY type", 
      "SELECT COUNT(*) as approved_annual FROM leave WHERE status = 'approved' AND type IN ('연차', 'annual', '연차휴가')",
      "SELECT * FROM leave WHERE status = 'approved' LIMIT 5"
    ];

    for (const query of queries) {
      console.log(`\n=== 쿼리: ${query.substring(0, 50)}... ===`);
      
      const response = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ query })
      });

      if (!response.ok) {
        const error = await response.text();
        console.error('Error:', error);
        continue;
      }

      const data = await response.json();
      console.log('결과:', JSON.stringify(data, null, 2));
    }

    // employees 테이블도 확인
    console.log('\n=== Employees 사용연차 확인 ===');
    const empQuery = "SELECT name, email, used_annual_leave FROM employees WHERE used_annual_leave > 0 ORDER BY used_annual_leave DESC LIMIT 5";
    
    const empResponse = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query: empQuery })
    });

    if (empResponse.ok) {
      const empData = await empResponse.json();
      console.log('직원 사용연차:', JSON.stringify(empData, null, 2));
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

queryDatabase();