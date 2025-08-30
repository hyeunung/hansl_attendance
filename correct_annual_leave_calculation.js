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

// 올바른 연차 계산 함수 (법정 기준)
function calculateCorrectAnnualLeave(joinDate, targetDate = new Date('2025-01-01')) {
  const joinYear = joinDate.getFullYear();
  const joinMonth = joinDate.getMonth() + 1;
  const joinDay = joinDate.getDate();
  
  const targetYear = targetDate.getFullYear();
  const targetMonth = targetDate.getMonth() + 1;
  
  // 근속 기간 계산
  const monthsSinceJoin = (targetYear - joinYear) * 12 + (targetMonth - joinMonth);
  
  // 1년 미만 근로자 (입사년도)
  if (joinYear === targetYear) {
    // 입사 후 한 달마다 1개씩 (최대 11개)
    // 2025년 입사자의 경우, 2025년 1월 기준으로는 아직 만근하지 않았으므로 0개
    // 실제로는 매월 만근 시점에 1개씩 발생
    if (targetMonth === 1) {
      // 1월 1일 기준으로는 이전 년도까지 근무한 개월 수만 계산
      return {
        leave: 0,
        reason: `${joinYear}년 신입 (월차 미발생)`,
        type: 'monthly'
      };
    }
    
    // 실제 월차 계산 (입사월 제외)
    const monthsWorked = Math.max(0, targetMonth - joinMonth);
    const monthlyLeave = Math.min(11, monthsWorked);
    
    return {
      leave: monthlyLeave,
      reason: `${joinYear}년 신입 (월차 ${monthlyLeave}개)`,
      type: 'monthly'
    };
  }
  
  // 입사 후 1년이 지난 경우 - 정규 연차 계산
  // 입사년도 다음해부터 15일 부여
  if (targetYear === joinYear + 1) {
    return {
      leave: 15,
      reason: '입사 1년차 (정규연차 15일)',
      type: 'regular'
    };
  }
  
  // 2년차 이상 - 2년마다 1일씩 추가
  const yearsOfService = targetYear - joinYear;
  const additionalDays = Math.floor((yearsOfService - 1) / 2);
  const totalLeave = Math.min(25, 15 + additionalDays); // 최대 25일
  
  return {
    leave: totalLeave,
    reason: `근속 ${yearsOfService}년 (15 + ${additionalDays} = ${totalLeave}일)`,
    type: 'regular'
  };
}

async function analyzeAndCorrect() {
  console.log('=== 📋 법정 연차 계산 기준 정정 분석 ===\n');
  console.log('📌 올바른 법정 연차 계산:');
  console.log('  - 1년 미만: 입사 후 매월 1일씩 발생 (최대 11일)');
  console.log('  - 1년 이상: 다음 회계연도(1/1)부터 15일 부여');
  console.log('  - 3년차부터: 2년마다 1일씩 추가 (최대 25일)\n');
  console.log('='.repeat(80));

  // 모든 직원 조회
  const query = `
    SELECT 
      name,
      email,
      join_date,
      annual_leave_granted_current_year as current_leave,
      used_annual_leave,
      remaining_annual_leave
    FROM employees
    WHERE join_date IS NOT NULL
    ORDER BY join_date, name
  `;

  const employees = await runQuery(query);
  
  const targetDate = new Date('2025-01-01');
  console.log(`\n기준일: ${targetDate.toISOString().split('T')[0]}\n`);
  
  console.log('직원명\t\t입사일\t\t현재\t정답\t차이\t설명');
  console.log('='.repeat(80));
  
  const corrections = [];
  let correctCount = 0;
  let incorrectCount = 0;
  
  employees.forEach(emp => {
    const joinDate = new Date(emp.join_date);
    const calculated = calculateCorrectAnnualLeave(joinDate, targetDate);
    const diff = emp.current_leave - calculated.leave;
    const isCorrect = Math.abs(diff) < 0.01;
    
    if (!isCorrect) {
      incorrectCount++;
      corrections.push({
        name: emp.name,
        email: emp.email,
        currentLeave: emp.current_leave,
        correctLeave: calculated.leave,
        diff: diff,
        reason: calculated.reason
      });
    } else {
      correctCount++;
    }
    
    const status = isCorrect ? '✅' : '❌';
    
    console.log(
      `${emp.name.padEnd(12)}\t${emp.join_date.substring(0,10)}\t${emp.current_leave}개\t${calculated.leave}개\t${diff > 0 ? '+' : ''}${diff}\t${status} ${calculated.reason}`
    );
  });
  
  console.log('\n' + '='.repeat(80));
  console.log('\n📊 요약:');
  console.log(`✅ 정상: ${correctCount}명`);
  console.log(`❌ 수정필요: ${incorrectCount}명`);
  
  if (corrections.length > 0) {
    console.log('\n⚠️ 수정이 필요한 직원들:');
    corrections.forEach(c => {
      console.log(`  ${c.name}: 현재 ${c.currentLeave}개 → ${c.correctLeave}개 (${c.diff > 0 ? '+' : ''}${c.diff}) - ${c.reason}`);
    });
    
    // SQL 생성
    console.log('\n💾 수정 SQL:');
    console.log('```sql');
    console.log('-- 법정 연차 기준에 맞춰 수정');
    console.log('BEGIN;');
    console.log('');
    
    corrections.forEach(c => {
      console.log(`-- ${c.name}: ${c.currentLeave}개 → ${c.correctLeave}개 (${c.reason})`);
      console.log(`UPDATE employees`);
      console.log(`SET annual_leave_granted_current_year = ${c.correctLeave},`);
      console.log(`    remaining_annual_leave = ${c.correctLeave} - COALESCE(used_annual_leave, 0)`);
      console.log(`WHERE email = '${c.email}';`);
      console.log('');
    });
    
    console.log('COMMIT;');
    console.log('```');
    
    // SQL 파일로 저장
    const fs = require('fs');
    let sqlContent = '-- 법정 연차 기준에 맞춰 수정\n';
    sqlContent += '-- 생성일: ' + new Date().toISOString() + '\n\n';
    sqlContent += 'BEGIN;\n\n';
    
    corrections.forEach(c => {
      sqlContent += `-- ${c.name}: ${c.currentLeave}개 → ${c.correctLeave}개 (${c.reason})\n`;
      sqlContent += `UPDATE employees\n`;
      sqlContent += `SET annual_leave_granted_current_year = ${c.correctLeave},\n`;
      sqlContent += `    remaining_annual_leave = ${c.correctLeave} - COALESCE(used_annual_leave, 0)\n`;
      sqlContent += `WHERE email = '${c.email}';\n\n`;
    });
    
    sqlContent += 'COMMIT;\n';
    
    fs.writeFileSync('fix_annual_leave_legal.sql', sqlContent);
    console.log('\n✅ SQL 파일 생성됨: fix_annual_leave_legal.sql');
  }
}

analyzeAndCorrect();