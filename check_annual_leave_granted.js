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

async function checkAnnualLeaveGranted() {
  console.log('=== 🔍 직원별 연차 지급 현황 확인 ===\n');
  console.log('📌 연차 계산 로직 (annual_year_update 함수):');
  console.log('  - 신입(0년차): 15개 기본값');
  console.log('  - 1~2년차: 15개 고정');
  console.log('  - 3년차 이상: 15 + Math.floor((근속년수-1)/2)개, 최대 25개');
  console.log('  - 예: 3-4년차(16개), 5-6년차(17개), 7-8년차(18개)...\n');
  console.log('='.repeat(80));

  // 모든 직원의 연차 데이터 조회
  const query = `
    SELECT 
      name,
      email,
      join_date,
      annual_leave_granted_current_year,
      used_annual_leave,
      remaining_annual_leave,
      DATE_PART('year', AGE('2025-01-01'::date, join_date::date)) as service_years
    FROM employees
    WHERE join_date IS NOT NULL
    ORDER BY join_date, name
  `;

  const employees = await runQuery(query);

  console.log('직원명\t\t입사일\t\t근속\t지급\t예상\t차이\t상태');
  console.log('='.repeat(80));

  let correctCount = 0;
  let incorrectCount = 0;
  const problems = [];

  employees.forEach(emp => {
    const serviceYears = Math.floor(emp.service_years);
    
    // 예상 연차 계산 (annual_year_update 로직과 동일)
    let expectedLeave;
    if (serviceYears === 0) {
      expectedLeave = 15;
    } else if (serviceYears === 1 || serviceYears === 2) {
      expectedLeave = 15;
    } else {
      const additionalLeave = Math.floor((serviceYears - 1) / 2);
      expectedLeave = Math.min(25, 15 + additionalLeave);
    }
    
    const granted = emp.annual_leave_granted_current_year || 0;
    const diff = granted - expectedLeave;
    const isCorrect = Math.abs(diff) < 0.01;
    
    if (isCorrect) {
      correctCount++;
    } else {
      incorrectCount++;
      problems.push({
        name: emp.name,
        joinDate: emp.join_date,
        serviceYears,
        granted,
        expected: expectedLeave,
        diff
      });
    }
    
    const status = isCorrect ? '✅' : '❌';
    const serviceStr = `${serviceYears}년차`;
    
    console.log(
      `${emp.name.padEnd(12)}\t${emp.join_date.substring(0,10)}\t${serviceStr}\t${granted}개\t${expectedLeave}개\t${diff > 0 ? '+' : ''}${diff}\t${status}`
    );
  });

  console.log('\n' + '='.repeat(80));
  console.log('\n📊 요약:');
  console.log(`✅ 정상: ${correctCount}명`);
  console.log(`❌ 오류: ${incorrectCount}명`);
  
  if (problems.length > 0) {
    console.log('\n⚠️ 문제가 있는 직원들:');
    problems.forEach(p => {
      console.log(`  ${p.name}: ${p.serviceYears}년차, 지급 ${p.granted}개, 예상 ${p.expected}개 (차이: ${p.diff > 0 ? '+' : ''}${p.diff})`);
    });
    
    console.log('\n💡 수정 방법:');
    console.log('1. annual_year_update 엣지 펑션을 실행하여 전체 직원 연차 재계산');
    console.log('2. 또는 개별 직원 수동 업데이트');
  } else {
    console.log('\n🎉 모든 직원의 연차가 정상적으로 지급되었습니다!');
  }
}

checkAnnualLeaveGranted();