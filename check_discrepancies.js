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

async function checkProblematicEmployees() {
  console.log('=== 문제 직원들 상세 확인 ===\n');

  const problemEmployees = [
    {name: '강영은', excel: {3: 2, 6: 1}},
    {name: '이정화', excel: {2: 2.5}},
    {name: '김경태', excel: {4: 1.5}},
    {name: '나유성', excel: {1: 1}},
    {name: '이재형', excel: {2: 1}},
    {name: '이한빈', excel: {4: 1}},
    {name: '정현웅', excel: {8: 0}},
    {name: '백현덕', excel: {4: 0}},
    {name: '윤은호', excel: {2: 1.5}}
  ];

  for (const emp of problemEmployees) {
    console.log(`\n${emp.name} 확인:`);
    
    for (const [month, excelDays] of Object.entries(emp.excel)) {
      const query = `
        SELECT 
          type,
          start_date,
          EXTRACT(DAY FROM start_date) as day
        FROM leave
        WHERE name = '${emp.name}'
          AND status = 'approved'
          AND EXTRACT(MONTH FROM start_date) = ${month}
          AND EXTRACT(YEAR FROM start_date) = 2025
        ORDER BY start_date
      `;
      
      const data = await runQuery(query);
      
      let dbDays = 0;
      const details = [];
      
      data.forEach(record => {
        if (record.type === 'annual') {
          dbDays += 1;
          details.push(`${record.day}일(연차)`);
        } else if (record.type === 'half_am' || record.type === 'half_pm') {
          dbDays += 0.5;
          details.push(`${record.day}일(${record.type === 'half_am' ? '오전' : '오후'}반차)`);
        }
      });
      
      console.log(`  ${month}월: 엑셀 ${excelDays}일 vs DB ${dbDays}일`);
      if (dbDays > 0) {
        console.log(`    DB 상세: ${details.join(', ')}`);
      }
      
      if (Math.abs(excelDays - dbDays) > 0.01) {
        console.log(`    ⚠️ 차이: ${dbDays - excelDays}일 초과`);
      }
    }
  }
}

checkProblematicEmployees();