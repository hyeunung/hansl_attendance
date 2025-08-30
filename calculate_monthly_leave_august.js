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

// 월차 계산 함수 (1개월 만근 후 다음달 1일 기준)
function calculateMonthlyLeave(joinDate, targetDate = new Date('2025-08-01')) {
  const joinYear = joinDate.getFullYear();
  const joinMonth = joinDate.getMonth() + 1; // 0-based to 1-based
  const joinDay = joinDate.getDate();
  
  const targetYear = targetDate.getFullYear();
  const targetMonth = targetDate.getMonth() + 1;
  
  // 입사년도가 아니면 정규 연차 대상
  if (joinYear < targetYear) {
    return {
      type: 'regular',
      monthlyLeave: 0,
      reason: '정규 연차 대상 (월차 아님)'
    };
  }
  
  // 2025년 신입만 월차 계산
  if (joinYear === 2025) {
    let monthlyLeave = 0;
    const details = [];
    
    // 1일 입사자는 다음달 1일부터 월차 발생
    if (joinDay === 1) {
      // 입사월 다음달부터 현재까지 계산
      for (let month = joinMonth + 1; month <= targetMonth; month++) {
        monthlyLeave++;
        details.push(`${month}월`);
      }
    } else {
      // 1일이 아닌 입사자는 1개월 만근 후 다음달 1일에 발생
      // 예: 1/6 입사 → 2/6 만근 → 3/1에 첫 월차
      // 예: 2/6 입사 → 3/6 만근 → 4/1에 첫 월차
      const firstLeaveMonth = joinMonth + 2; // 입사 다다음달부터
      
      for (let month = firstLeaveMonth; month <= targetMonth; month++) {
        if (month <= 12) {
          monthlyLeave++;
          details.push(`${month}월`);
        }
      }
    }
    
    // 최대 11개 제한
    monthlyLeave = Math.min(11, monthlyLeave);
    
    return {
      type: 'monthly',
      monthlyLeave: monthlyLeave,
      reason: `월차 ${monthlyLeave}개 (${details.join(', ') || '미발생'})`,
      details: details
    };
  }
  
  return {
    type: 'none',
    monthlyLeave: 0,
    reason: '해당없음'
  };
}

// 정규 연차 계산 (1년 이상 근무자)
function calculateRegularLeave(joinDate, targetDate = new Date('2025-01-01')) {
  const joinYear = joinDate.getFullYear();
  const targetYear = targetDate.getFullYear();
  
  // 2025년 신입은 월차 대상
  if (joinYear === 2025) {
    return 0;
  }
  
  // 2024년 입사자는 2025년부터 정규연차 15일
  if (joinYear === 2024) {
    return 15;
  }
  
  // 2년차 이상 - 2년마다 1일씩 추가
  const yearsOfService = targetYear - joinYear;
  const additionalDays = Math.floor((yearsOfService - 1) / 2);
  const totalLeave = Math.min(25, 15 + additionalDays);
  
  return totalLeave;
}

async function analyzeAugustLeave() {
  console.log('=== 📅 2025년 8월 기준 연차 분석 ===\n');
  console.log('📌 월차 발생 규칙:');
  console.log('  - 1일 입사: 다음달 1일에 1개 발생');
  console.log('  - 그 외: 1개월 만근 후 다음달 1일에 1개 발생');
  console.log('  - 최대 11개까지 발생\n');
  console.log('📌 정규 연차:');
  console.log('  - 입사 1년 후 다음 회계연도(1/1)부터 15일');
  console.log('  - 3년차부터 2년마다 1일 추가 (최대 25일)\n');
  console.log('='.repeat(100));

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
    ORDER BY join_date DESC, name
  `;

  const employees = await runQuery(query);
  
  const augustDate = new Date('2025-08-01');
  const januaryDate = new Date('2025-01-01');
  
  console.log('\n직원명\t\t입사일\t\t현재\t8월기준\t차이\t설명');
  console.log('='.repeat(100));
  
  const corrections = [];
  let correctCount = 0;
  let incorrectCount = 0;
  
  employees.forEach(emp => {
    const joinDate = new Date(emp.join_date);
    const joinYear = joinDate.getFullYear();
    
    let correctLeave = 0;
    let reason = '';
    
    if (joinYear === 2025) {
      // 2025년 신입: 월차 계산
      const monthly = calculateMonthlyLeave(joinDate, augustDate);
      correctLeave = monthly.monthlyLeave;
      reason = monthly.reason;
    } else {
      // 기존 직원: 정규 연차
      correctLeave = calculateRegularLeave(joinDate, januaryDate);
      const yearsOfService = 2025 - joinYear;
      
      if (joinYear === 2024) {
        reason = `입사 1년차 (정규연차 15일)`;
      } else {
        const additionalDays = Math.floor((yearsOfService - 1) / 2);
        reason = `근속 ${yearsOfService}년 (15 + ${additionalDays} = ${correctLeave}일)`;
      }
    }
    
    const diff = emp.current_leave - correctLeave;
    const isCorrect = Math.abs(diff) < 0.01;
    
    if (!isCorrect) {
      incorrectCount++;
      corrections.push({
        name: emp.name,
        email: emp.email,
        joinDate: emp.join_date,
        currentLeave: emp.current_leave,
        correctLeave: correctLeave,
        diff: diff,
        reason: reason,
        usedLeave: emp.used_annual_leave || 0
      });
    } else {
      correctCount++;
    }
    
    const status = isCorrect ? '✅' : '❌';
    
    console.log(
      `${emp.name.padEnd(12)}\t${emp.join_date.substring(0,10)}\t${emp.current_leave}개\t${correctLeave}개\t${diff > 0 ? '+' : ''}${diff}\t${status} ${reason}`
    );
  });
  
  console.log('\n' + '='.repeat(100));
  console.log('\n📊 요약:');
  console.log(`✅ 정상: ${correctCount}명`);
  console.log(`❌ 수정필요: ${incorrectCount}명`);
  
  if (corrections.length > 0) {
    console.log('\n⚠️ 수정이 필요한 직원들:');
    
    // 2025년 신입 먼저 표시
    const newHires2025 = corrections.filter(c => c.joinDate.startsWith('2025'));
    if (newHires2025.length > 0) {
      console.log('\n[2025년 신입 - 월차]');
      newHires2025.forEach(c => {
        console.log(`  ${c.name} (${c.joinDate}): 현재 ${c.currentLeave}개 → ${c.correctLeave}개 - ${c.reason}`);
      });
    }
    
    // 기존 직원
    const existing = corrections.filter(c => !c.joinDate.startsWith('2025'));
    if (existing.length > 0) {
      console.log('\n[기존 직원 - 정규연차]');
      existing.forEach(c => {
        console.log(`  ${c.name}: 현재 ${c.currentLeave}개 → ${c.correctLeave}개 - ${c.reason}`);
      });
    }
    
    // SQL 생성
    console.log('\n💾 수정 SQL 생성...\n');
    
    const fs = require('fs');
    let sqlContent = '-- 2025년 8월 기준 연차 수정\n';
    sqlContent += '-- 생성일: ' + new Date().toISOString() + '\n';
    sqlContent += '-- 월차: 1일 입사자는 다음달부터, 그 외는 1개월 만근 후 다음달부터\n\n';
    sqlContent += 'BEGIN;\n\n';
    
    corrections.forEach(c => {
      sqlContent += `-- ${c.name} (${c.joinDate}): ${c.currentLeave}개 → ${c.correctLeave}개\n`;
      sqlContent += `-- ${c.reason}\n`;
      sqlContent += `UPDATE employees\n`;
      sqlContent += `SET annual_leave_granted_current_year = ${c.correctLeave},\n`;
      sqlContent += `    remaining_annual_leave = ${c.correctLeave} - ${c.usedLeave}\n`;
      sqlContent += `WHERE email = '${c.email}';\n\n`;
    });
    
    sqlContent += 'COMMIT;\n\n';
    sqlContent += '-- 검증 쿼리\n';
    sqlContent += 'SELECT name, join_date, annual_leave_granted_current_year, used_annual_leave, remaining_annual_leave\n';
    sqlContent += 'FROM employees\n';
    sqlContent += 'WHERE email IN (\n';
    corrections.forEach((c, i) => {
      sqlContent += `  '${c.email}'${i < corrections.length - 1 ? ',' : ''}\n`;
    });
    sqlContent += ')\n';
    sqlContent += 'ORDER BY join_date DESC, name;\n';
    
    fs.writeFileSync('fix_annual_leave_august.sql', sqlContent);
    console.log('✅ SQL 파일 생성됨: fix_annual_leave_august.sql');
  }
}

analyzeAugustLeave();