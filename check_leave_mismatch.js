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

async function checkLeaveMismatch() {
  try {
    console.log('=== 연차 사용 일치성 검사 ===\n');

    // 1. 각 직원의 실제 승인된 연차 계산
    const leaveQuery = `
      SELECT 
        user_email,
        SUM(CASE 
          WHEN type = 'annual' THEN 
            CASE 
              WHEN start_date = end_date THEN 1
              ELSE (end_date - start_date + 1)
            END
          WHEN type = 'half_am' OR type = 'half_pm' THEN 0.5
          ELSE 0
        END) as calculated_used_leave
      FROM leave
      WHERE status = 'approved'
        AND type IN ('annual', 'half_am', 'half_pm')
      GROUP BY user_email
      ORDER BY calculated_used_leave DESC
    `;

    const leaveData = await runQuery(leaveQuery);
    console.log('승인된 연차 데이터를 가진 직원 수:', leaveData.length);

    // 2. employees 테이블에서 사용연차 정보 가져오기
    const empQuery = `
      SELECT 
        id,
        name,
        email,
        used_annual_leave
      FROM employees
      ORDER BY name
    `;

    const empData = await runQuery(empQuery);
    console.log('전체 직원 수:', empData.length);

    // 3. 이메일로 매핑
    const leaveByEmail = {};
    leaveData.forEach(item => {
      leaveByEmail[item.user_email] = parseFloat(item.calculated_used_leave);
    });

    // 4. 불일치 찾기
    const mismatches = [];
    const matches = [];
    
    empData.forEach(emp => {
      const dbUsed = parseFloat(emp.used_annual_leave || 0);
      const calculatedUsed = leaveByEmail[emp.email] || 0;
      
      if (Math.abs(dbUsed - calculatedUsed) > 0.01) {
        mismatches.push({
          id: emp.id,
          name: emp.name,
          email: emp.email,
          dbUsed,
          calculatedUsed,
          difference: dbUsed - calculatedUsed
        });
      } else if (dbUsed > 0 || calculatedUsed > 0) {
        matches.push({
          name: emp.name,
          email: emp.email,
          used: dbUsed
        });
      }
    });

    // 5. 결과 출력
    if (matches.length > 0) {
      console.log('\n✅ 일치하는 직원 (' + matches.length + '명):');
      matches.forEach(m => {
        console.log(`  ${m.name}: ${m.used}일`);
      });
    }

    if (mismatches.length > 0) {
      console.log('\n⚠️ 불일치 발견 (' + mismatches.length + '명):');
      console.log('\n이름\t\t\tDB 사용연차\t실제 승인연차\t차이');
      console.log('─'.repeat(60));
      
      mismatches.forEach(m => {
        console.log(`${m.name.padEnd(15)}\t${m.dbUsed}\t\t${m.calculatedUsed}\t\t${m.difference > 0 ? '+' : ''}${m.difference.toFixed(1)}`);
      });
      
      console.log('\n📝 수정 SQL:');
      mismatches.forEach(m => {
        console.log(`UPDATE employees SET used_annual_leave = ${m.calculatedUsed} WHERE id = '${m.id}'; -- ${m.name}`);
      });
    } else {
      console.log('\n✅ 모든 직원의 사용연차가 정확히 일치합니다!');
    }

    // 6. 요약
    console.log('\n=== 요약 ===');
    console.log(`총 직원 수: ${empData.length}명`);
    console.log(`일치: ${matches.length}명`);
    console.log(`불일치: ${mismatches.length}명`);
    console.log(`연차 사용 기록이 있는 직원: ${Object.keys(leaveByEmail).length}명`);

  } catch (error) {
    console.error('Error:', error);
  }
}

checkLeaveMismatch();