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

async function checkNoLeaveEmployees() {
  try {
    console.log('=== 연차 기록이 없는 직원 확인 ===\n');

    // 1. Leave 테이블에 있는 이메일 목록
    const leaveEmailsQuery = `
      SELECT DISTINCT user_email
      FROM leave
    `;
    const leaveEmails = await runQuery(leaveEmailsQuery);
    const leaveEmailSet = new Set(leaveEmails.map(e => e.user_email));

    // 2. 모든 직원 정보 가져오기
    const employeesQuery = `
      SELECT 
        id,
        name,
        email,
        department,
        position,
        used_annual_leave,
        remaining_annual_leave
      FROM employees
      ORDER BY name
    `;
    const employees = await runQuery(employeesQuery);

    // 3. Leave 테이블에 없는 직원 찾기
    const noLeaveEmployees = employees.filter(emp => !leaveEmailSet.has(emp.email));
    
    console.log(`연차 기록이 없는 직원: ${noLeaveEmployees.length}명\n`);
    console.log('─'.repeat(100));
    console.log('이름\t\t부서\t\t직급\t\t이메일\t\t\t\t\tDB사용연차');
    console.log('─'.repeat(100));
    
    noLeaveEmployees.forEach((emp, idx) => {
      const name = emp.name.padEnd(12);
      const dept = (emp.department || 'N/A').padEnd(10);
      const position = (emp.position || 'N/A').padEnd(10);
      const email = emp.email.padEnd(35);
      const usedLeave = emp.used_annual_leave || 0;
      
      console.log(`${name}\t${dept}\t${position}\t${email}\t${usedLeave}일`);
    });

    // 4. 추가 분석
    console.log('\n=== 상세 분석 ===\n');
    
    noLeaveEmployees.forEach((emp, idx) => {
      console.log(`${idx + 1}. ${emp.name}`);
      console.log(`   - 이메일: ${emp.email}`);
      console.log(`   - 부서: ${emp.department || 'N/A'}`);
      console.log(`   - 직급: ${emp.position || 'N/A'}`);
      console.log(`   - DB 사용연차: ${emp.used_annual_leave || 0}일`);
      console.log(`   - 잔여연차: ${emp.remaining_annual_leave || 0}일`);
      
      if (emp.used_annual_leave > 0) {
        console.log(`   ⚠️ DB에 ${emp.used_annual_leave}일 사용 기록이 있지만 leave 테이블에는 없음`);
      }
      console.log('');
    });

  } catch (error) {
    console.error('Error:', error);
  }
}

checkNoLeaveEmployees();