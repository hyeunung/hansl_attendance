const fetch = require('node-fetch');
const fs = require('fs');

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

async function generateFinalReportWithRemaining() {
  try {
    console.log('=== 전체 직원 연차 현황 종합 보고서 ===\n');
    console.log('(권혁진 퇴사자 제외, 윤은호 10.5일로 수정)\n');

    // 직원 정보 가져오기 (사용연차, 남은연차)
    const employeeQuery = `
      SELECT 
        name,
        email,
        used_annual_leave,
        remaining_annual_leave,
        annual_leave_granted_current_year
      FROM employees
      WHERE name != '권혁진'
      ORDER BY name
    `;
    
    const employeeData = await runQuery(employeeQuery);
    const employeeMap = {};
    employeeData.forEach(emp => {
      employeeMap[emp.name] = emp;
    });

    // 엑셀 데이터 로드
    const excelData = JSON.parse(fs.readFileSync('excel_all_leave_data.json', 'utf-8'));
    
    // 윤은호 데이터 수정 (10.5일로)
    const yoonIndex = excelData.findIndex(emp => emp.name === '윤은호');
    if (yoonIndex !== -1) {
      excelData[yoonIndex].monthlyLeave['7월'] = {
        raw: '14일, 15일(오후반차)',
        dates: [14],
        halfDays: [{day: 15, type: 'half_pm'}],
        days: 1.5
      };
      excelData[yoonIndex].totalDays = 10.5;
    }
    
    // 권혁진 제외
    const filteredExcelData = excelData.filter(emp => emp.name !== '권혁진');

    // DB leave 데이터 가져오기
    const dbQuery = `
      SELECT 
        name,
        SUM(CASE 
          WHEN type = 'annual' THEN 
            CASE 
              WHEN start_date = end_date THEN 1
              ELSE (end_date - start_date + 1)
            END
          WHEN type IN ('half_am', 'half_pm') THEN 0.5
          ELSE 0
        END) as total_days
      FROM leave
      WHERE status = 'approved'
        AND start_date >= '2025-01-01'
        AND start_date <= '2025-08-31'
        AND name != '권혁진'
      GROUP BY name
      ORDER BY name
    `;

    const dbLeaveData = await runQuery(dbQuery);
    const dbLeaveMap = {};
    dbLeaveData.forEach(record => {
      dbLeaveMap[record.name] = parseFloat(record.total_days);
    });

    // 엑셀 데이터를 이름으로 매핑
    const excelByName = {};
    filteredExcelData.forEach(emp => {
      excelByName[emp.name] = emp.totalDays;
    });

    // 전체 직원 목록
    const allEmployees = new Set([
      ...Object.keys(employeeMap),
      ...Object.keys(excelByName),
      ...Object.keys(dbLeaveMap)
    ]);
    
    console.log('직원명\t\t엑셀\tDB\t차이\t사용연차\t남은연차\t부여연차\t상태');
    console.log('='.repeat(100));
    
    let totalExcelDays = 0;
    let totalDBDays = 0;
    let totalUsed = 0;
    let totalRemaining = 0;
    let totalGranted = 0;
    
    // 이름순 정렬
    const sortedEmployees = Array.from(allEmployees).sort();
    
    const results = [];
    
    sortedEmployees.forEach(name => {
      const excel = excelByName[name] || 0;
      const db = dbLeaveMap[name] || 0;
      const emp = employeeMap[name] || {};
      
      const diff = excel - db;
      const used = parseFloat(emp.used_annual_leave || 0);
      const remaining = parseFloat(emp.remaining_annual_leave || 0);
      const granted = parseInt(emp.annual_leave_granted_current_year || 0);
      
      totalExcelDays += excel;
      totalDBDays += db;
      totalUsed += used;
      totalRemaining += remaining;
      totalGranted += granted;
      
      let status = '';
      if (Math.abs(diff) < 0.01) {
        status = '✅';
      } else if (diff > 0) {
        status = '⚠️ 누락';
      } else {
        status = '❌ 초과';
      }
      
      results.push({
        name,
        excel,
        db,
        diff,
        used,
        remaining,
        granted,
        status
      });
    });
    
    // 출력
    results.forEach(r => {
      console.log(
        `${r.name.padEnd(12)}\t` +
        `${r.excel.toFixed(1)}\t` +
        `${r.db.toFixed(1)}\t` +
        `${r.diff > 0 ? '+' : ''}${r.diff.toFixed(1)}\t` +
        `${r.used.toFixed(1)}\t\t` +
        `${r.remaining.toFixed(1)}\t\t` +
        `${r.granted.toFixed(1)}\t\t` +
        `${r.status}`
      );
    });
    
    console.log('\n' + '='.repeat(100));
    console.log('\n=== 요약 통계 ===');
    console.log(`총 인원: ${sortedEmployees.size}명`);
    console.log(`\n연차 데이터 비교:`);
    console.log(`  엑셀 총계: ${totalExcelDays.toFixed(1)}일`);
    console.log(`  DB 총계: ${totalDBDays.toFixed(1)}일`);
    console.log(`  차이: ${(totalExcelDays - totalDBDays).toFixed(1)}일 누락`);
    
    console.log(`\n직원 테이블 연차 현황:`);
    console.log(`  총 사용연차: ${totalUsed.toFixed(1)}일`);
    console.log(`  총 남은연차: ${totalRemaining.toFixed(1)}일`);
    console.log(`  총 부여연차: ${totalGranted.toFixed(1)}일`);
    
    // 차이가 큰 직원 TOP 10
    console.log('\n=== 누락이 많은 직원 TOP 10 ===');
    const sorted = results.filter(r => r.diff > 0).sort((a, b) => b.diff - a.diff).slice(0, 10);
    sorted.forEach((r, idx) => {
      console.log(`${idx + 1}. ${r.name}: ${r.diff.toFixed(1)}일 누락 (엑셀 ${r.excel.toFixed(1)}일 - DB ${r.db.toFixed(1)}일)`);
    });
    
    // 남은연차가 많은 직원 TOP 10
    console.log('\n=== 남은연차가 많은 직원 TOP 10 ===');
    const remainingSorted = results.sort((a, b) => b.remaining - a.remaining).slice(0, 10);
    remainingSorted.forEach((r, idx) => {
      console.log(`${idx + 1}. ${r.name}: ${r.remaining.toFixed(1)}일 남음 (부여 ${r.granted.toFixed(1)}일 - 사용 ${r.used.toFixed(1)}일)`);
    });

  } catch (error) {
    console.error('Error:', error);
  }
}

generateFinalReportWithRemaining();