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

async function compareCompleteData() {
  try {
    console.log('=== 엑셀과 DB 전체 데이터 비교 (1~8월) ===\n');

    // 1. 엑셀 데이터 로드
    const excelData = JSON.parse(fs.readFileSync('excel_all_leave_data.json', 'utf-8'));
    console.log(`엑셀 데이터: ${excelData.length}명\n`);

    // 2. DB에서 모든 leave 데이터 가져오기 (2025년 1~8월)
    const dbQuery = `
      SELECT 
        name,
        user_email,
        type,
        start_date,
        end_date,
        status,
        reason,
        EXTRACT(MONTH FROM start_date) as month,
        EXTRACT(DAY FROM start_date) as day,
        CASE 
          WHEN type = 'annual' THEN 
            CASE 
              WHEN start_date = end_date THEN 1
              ELSE (end_date - start_date + 1)
            END
          WHEN type IN ('half_am', 'half_pm') THEN 0.5
          ELSE 0
        END as days
      FROM leave
      WHERE status = 'approved'
        AND start_date >= '2025-01-01'
        AND start_date <= '2025-08-31'
      ORDER BY name, start_date
    `;

    const dbData = await runQuery(dbQuery);
    console.log(`DB 데이터: ${dbData.length}건\n`);

    // 3. DB 데이터를 직원별로 집계
    const dbByName = {};
    dbData.forEach(record => {
      const name = record.name;
      if (!dbByName[name]) {
        dbByName[name] = {
          totalDays: 0,
          monthlyDays: {},
          details: []
        };
      }
      
      const month = parseInt(record.month);
      const monthKey = `${month}월`;
      
      if (!dbByName[name].monthlyDays[monthKey]) {
        dbByName[name].monthlyDays[monthKey] = 0;
      }
      
      dbByName[name].monthlyDays[monthKey] += parseFloat(record.days);
      dbByName[name].totalDays += parseFloat(record.days);
      dbByName[name].details.push({
        date: record.start_date,
        type: record.type,
        days: record.days
      });
    });

    // 4. 엑셀 데이터를 이름으로 매핑
    const excelByName = {};
    excelData.forEach(emp => {
      excelByName[emp.name] = emp;
    });

    // 5. 비교 분석
    console.log('=== 직원별 연차 사용 일수 비교 ===\n');
    console.log('직원명\t\t엑셀 총계\tDB 총계\t\t차이\t\t상태');
    console.log('─'.repeat(70));

    let perfectMatch = [];
    let mismatch = [];
    let onlyInExcel = [];
    let onlyInDB = [];

    // 엑셀 기준으로 비교
    Object.entries(excelByName).forEach(([name, excelEmp]) => {
      const dbEmp = dbByName[name];
      
      if (!dbEmp) {
        onlyInExcel.push(name);
        console.log(`${name.padEnd(12)}\t${excelEmp.totalDays}\t\t0\t\t${excelEmp.totalDays}\t\t❌ 엑셀에만 있음`);
      } else {
        const diff = excelEmp.totalDays - dbEmp.totalDays;
        
        if (Math.abs(diff) < 0.01) {
          perfectMatch.push(name);
          console.log(`${name.padEnd(12)}\t${excelEmp.totalDays}\t\t${dbEmp.totalDays}\t\t0\t\t✅ 일치`);
        } else {
          mismatch.push({
            name: name,
            excelDays: excelEmp.totalDays,
            dbDays: dbEmp.totalDays,
            difference: diff
          });
          console.log(`${name.padEnd(12)}\t${excelEmp.totalDays}\t\t${dbEmp.totalDays}\t\t${diff > 0 ? '+' : ''}${diff}\t\t⚠️ 불일치`);
        }
      }
    });

    // DB에만 있는 직원
    Object.keys(dbByName).forEach(name => {
      if (!excelByName[name]) {
        onlyInDB.push(name);
        const dbEmp = dbByName[name];
        console.log(`${name.padEnd(12)}\t0\t\t${dbEmp.totalDays}\t\t-${dbEmp.totalDays}\t\t❌ DB에만 있음`);
      }
    });

    // 6. 불일치 상세 분석
    if (mismatch.length > 0) {
      console.log('\n\n=== 불일치 직원 상세 분석 ===\n');
      
      mismatch.forEach(emp => {
        console.log(`\n${emp.name}`);
        console.log(`  엑셀 총계: ${emp.excelDays}일`);
        console.log(`  DB 총계: ${emp.dbDays}일`);
        console.log(`  차이: ${emp.difference > 0 ? '+' : ''}${emp.difference}일`);
        
        // 월별 비교
        const excelMonthly = excelByName[emp.name].monthlyLeave;
        const dbMonthly = dbByName[emp.name].monthlyDays;
        
        console.log('\n  월별 비교:');
        const allMonths = new Set([...Object.keys(excelMonthly), ...Object.keys(dbMonthly)]);
        
        allMonths.forEach(month => {
          const excelDays = excelMonthly[month]?.days || 0;
          const dbDays = dbMonthly[month] || 0;
          
          if (Math.abs(excelDays - dbDays) > 0.01) {
            console.log(`    ${month}: 엑셀 ${excelDays}일 vs DB ${dbDays}일 (차이: ${excelDays - dbDays}일)`);
          }
        });
      });
    }

    // 7. 최종 요약
    console.log('\n\n=== 최종 요약 ===');
    console.log(`✅ 완벽 일치: ${perfectMatch.length}명`);
    console.log(`⚠️ 불일치: ${mismatch.length}명`);
    console.log(`❌ 엑셀에만 있음: ${onlyInExcel.length}명`);
    console.log(`❌ DB에만 있음: ${onlyInDB.length}명`);
    
    if (onlyInExcel.length > 0) {
      console.log('\n엑셀에만 있는 직원:');
      onlyInExcel.forEach(name => {
        const emp = excelByName[name];
        console.log(`  - ${name}: ${emp.totalDays}일`);
      });
    }
    
    if (onlyInDB.length > 0) {
      console.log('\nDB에만 있는 직원:');
      onlyInDB.forEach(name => {
        const emp = dbByName[name];
        console.log(`  - ${name}: ${emp.totalDays}일`);
      });
    }

    // 8. 전체 합계 비교
    const excelTotal = Object.values(excelByName).reduce((sum, emp) => sum + emp.totalDays, 0);
    const dbTotal = Object.values(dbByName).reduce((sum, emp) => sum + emp.totalDays, 0);
    
    console.log('\n=== 전체 합계 ===');
    console.log(`엑셀 전체: ${excelTotal}일`);
    console.log(`DB 전체: ${dbTotal}일`);
    console.log(`차이: ${excelTotal - dbTotal}일`);

    // 결과 저장
    const report = {
      summary: {
        excel: excelData.length,
        db: Object.keys(dbByName).length,
        perfectMatch: perfectMatch.length,
        mismatch: mismatch.length,
        onlyInExcel: onlyInExcel.length,
        onlyInDB: onlyInDB.length,
        totalExcelDays: excelTotal,
        totalDbDays: dbTotal,
        totalDifference: excelTotal - dbTotal
      },
      mismatchDetails: mismatch,
      onlyInExcel: onlyInExcel,
      onlyInDB: onlyInDB
    };
    
    fs.writeFileSync('final_comparison_report.json', JSON.stringify(report, null, 2), 'utf-8');
    console.log('\n✅ 상세 비교 결과를 final_comparison_report.json 파일로 저장했습니다.');

  } catch (error) {
    console.error('Error:', error);
  }
}

compareCompleteData();