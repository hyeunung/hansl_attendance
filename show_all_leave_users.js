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

async function showAllLeaveUsers() {
  try {
    console.log('=== Leave 테이블의 모든 사용자 (중복 제거) ===\n');

    // 1. leave 테이블에서 고유한 사용자 목록
    const uniqueUsersQuery = `
      SELECT DISTINCT
        user_email,
        name,
        COUNT(*) as leave_count,
        SUM(CASE 
          WHEN type = 'annual' THEN 
            CASE 
              WHEN start_date = end_date THEN 1
              ELSE (end_date - start_date + 1)
            END
          WHEN type = 'half_am' OR type = 'half_pm' THEN 0.5
          ELSE 0
        END) as total_days
      FROM leave
      WHERE status = 'approved'
        AND type IN ('annual', 'half_am', 'half_pm')
      GROUP BY user_email, name
      ORDER BY name
    `;

    const leaveUsers = await runQuery(uniqueUsersQuery);
    
    console.log(`Leave 테이블의 고유 사용자 수: ${leaveUsers.length}명\n`);
    
    console.log('번호\t이름\t\t\t이메일\t\t\t\t신청건수\t사용일수');
    console.log('─'.repeat(100));
    
    leaveUsers.forEach((user, idx) => {
      const name = user.name || 'N/A';
      const email = user.user_email;
      const count = user.leave_count;
      const days = user.total_days || 0;
      
      console.log(`${(idx + 1).toString().padEnd(4)}\t${name.padEnd(15)}\t${email.padEnd(30)}\t${count}\t\t${days}`);
    });

    // 2. employees 테이블과 비교
    console.log('\n\n=== Employees 테이블과 비교 ===\n');
    
    const empQuery = `
      SELECT 
        name,
        email
      FROM employees
      ORDER BY name
    `;
    
    const employees = await runQuery(empQuery);
    
    // Leave에만 있는 사용자 찾기
    const empEmails = new Set(employees.map(e => e.email));
    const leaveOnlyUsers = leaveUsers.filter(u => !empEmails.has(u.user_email));
    
    if (leaveOnlyUsers.length > 0) {
      console.log(`⚠️ Leave 테이블에만 있는 사용자 (${leaveOnlyUsers.length}명):`);
      console.log('─'.repeat(60));
      leaveOnlyUsers.forEach(user => {
        console.log(`  - ${user.name} (${user.user_email}): ${user.total_days}일 사용`);
      });
    }
    
    // Employees에만 있는 사용자 찾기
    const leaveEmails = new Set(leaveUsers.map(u => u.user_email));
    const empOnlyUsers = employees.filter(e => !leaveEmails.has(e.email));
    
    if (empOnlyUsers.length > 0) {
      console.log(`\n⚠️ Employees 테이블에만 있는 사용자 (${empOnlyUsers.length}명):`);
      console.log('─'.repeat(60));
      empOnlyUsers.forEach(user => {
        console.log(`  - ${user.name} (${user.email})`);
      });
    }

    // 3. 이메일 도메인 분석
    console.log('\n\n=== 이메일 도메인 분석 ===\n');
    const domains = {};
    leaveUsers.forEach(user => {
      const domain = user.user_email.split('@')[1];
      if (!domains[domain]) domains[domain] = 0;
      domains[domain]++;
    });
    
    Object.entries(domains).forEach(([domain, count]) => {
      console.log(`${domain}: ${count}명`);
    });

  } catch (error) {
    console.error('Error:', error);
  }
}

showAllLeaveUsers();