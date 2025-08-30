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

async function generateFinalReport() {
  try {
    console.log('=== 전체 직원 1~8월 연차 사용 내역 최종 정리 ===\n');
    console.log('(권혁진 퇴사자 제외, 윤은호 10.5일로 수정)\n');

    // 엑셀 데이터 로드 (이미 파싱된 데이터 사용)
    const excelData = JSON.parse(fs.readFileSync('excel_all_leave_data.json', 'utf-8'));
    
    // 윤은호 데이터 수정
    const yoonIndex = excelData.findIndex(emp => emp.name === '윤은호');
    if (yoonIndex !== -1) {
      // 기존 17.5일을 10.5일로 수정
      // 7월 데이터 수정: 14일, 15일(오후반차)만 = 1.5일
      excelData[yoonIndex].monthlyLeave['7월'] = {
        raw: '14일, 15일(오후반차)',
        dates: [14],
        halfDays: [{day: 15, type: 'half_pm'}],
        days: 1.5
      };
      
      // 총 일수 재계산
      excelData[yoonIndex].totalDays = 0;
      Object.values(excelData[yoonIndex].monthlyLeave).forEach(month => {
        excelData[yoonIndex].totalDays += month.days;
      });
    }
    
    // 권혁진 제외
    const filteredExcelData = excelData.filter(emp => emp.name !== '권혁진');

    // DB 데이터 가져오기
    const dbQuery = `
      SELECT 
        name,
        user_email,
        type,
        start_date,
        end_date,
        status,
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
        AND name != '권혁진'
      ORDER BY name, start_date
    `;

    const dbData = await runQuery(dbQuery);
    
    // DB 데이터를 직원별로 정리
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
      
      const monthKey = `${record.month}월`;
      if (!dbByName[name].monthlyDays[monthKey]) {
        dbByName[name].monthlyDays[monthKey] = 0;
      }
      
      dbByName[name].monthlyDays[monthKey] += parseFloat(record.days);
      dbByName[name].totalDays += parseFloat(record.days);
      dbByName[name].details.push(record);
    });

    // 엑셀 데이터를 이름으로 매핑
    const excelByName = {};
    filteredExcelData.forEach(emp => {
      excelByName[emp.name] = emp;
    });

    // 전체 직원 목록 (권혁진 제외)
    const allEmployees = new Set([...Object.keys(excelByName), ...Object.keys(dbByName)]);
    
    console.log('직원명\t\t엑셀\tDB\t차이\t상태');
    console.log('='.repeat(70));
    
    let perfectMatch = [];
    let mismatch = [];
    let onlyInExcel = [];
    let onlyInDB = [];
    let totalExcelDays = 0;
    let totalDBDays = 0;
    
    // 이름순 정렬
    const sortedEmployees = Array.from(allEmployees).sort();
    
    sortedEmployees.forEach(name => {
      const excel = excelByName[name];
      const db = dbByName[name];
      
      const excelDays = excel ? excel.totalDays : 0;
      const dbDays = db ? db.totalDays : 0;
      const diff = excelDays - dbDays;
      
      totalExcelDays += excelDays;
      totalDBDays += dbDays;
      
      let status = '';
      
      if (!db && excel) {
        onlyInExcel.push(name);
        status = '❌ 엑셀에만 있음';
      } else if (db && !excel) {
        onlyInDB.push(name);
        status = '❌ DB에만 있음';
      } else if (Math.abs(diff) < 0.01) {
        perfectMatch.push(name);
        status = '✅ 일치';
      } else {
        mismatch.push({
          name: name,
          excelDays: excelDays,
          dbDays: dbDays,
          difference: diff
        });
        status = '⚠️ 불일치';
      }
      
      console.log(`${name.padEnd(12)}\t${excelDays}\t${dbDays}\t${diff > 0 ? '+' : ''}${diff.toFixed(1)}\t${status}`);
    });
    
    console.log('\n' + '='.repeat(70));
    console.log('\n=== 최종 요약 (권혁진 제외) ===');
    console.log(`✅ 완벽 일치: ${perfectMatch.length}명`);
    if (perfectMatch.length > 0) {
      console.log(`   ${perfectMatch.join(', ')}`);
    }
    
    console.log(`\n⚠️ 불일치: ${mismatch.length}명`);
    if (mismatch.length > 0) {
      mismatch.sort((a, b) => b.difference - a.difference);
      console.log('\n   차이가 큰 순서:');
      mismatch.forEach(emp => {
        console.log(`   ${emp.name}: 엑셀 ${emp.excelDays}일 - DB ${emp.dbDays}일 = ${emp.difference > 0 ? '+' : ''}${emp.difference.toFixed(1)}일`);
      });
    }
    
    if (onlyInExcel.length > 0) {
      console.log(`\n❌ 엑셀에만 있음: ${onlyInExcel.length}명`);
      console.log(`   ${onlyInExcel.join(', ')}`);
    }
    
    if (onlyInDB.length > 0) {
      console.log(`\n❌ DB에만 있음: ${onlyInDB.length}명`);
      console.log(`   ${onlyInDB.join(', ')}`);
    }
    
    console.log('\n' + '='.repeat(70));
    console.log('\n전체 통계:');
    console.log(`엑셀: ${Object.keys(excelByName).length}명, 총 ${totalExcelDays.toFixed(1)}일`);
    console.log(`DB: ${Object.keys(dbByName).length}명, 총 ${totalDBDays.toFixed(1)}일`);
    console.log(`차이: ${(totalExcelDays - totalDBDays).toFixed(1)}일 누락`);
    console.log(`누락 비율: ${((totalExcelDays - totalDBDays) / totalExcelDays * 100).toFixed(1)}%`);
    
    // 월별 누락 분석
    console.log('\n=== 월별 누락 패턴 분석 ===');
    const monthlyMissing = {};
    
    mismatch.forEach(emp => {
      const excel = excelByName[emp.name];
      const db = dbByName[emp.name];
      
      if (excel && db) {
        Object.entries(excel.monthlyLeave).forEach(([month, data]) => {
          const dbDays = db.monthlyDays[month] || 0;
          const diff = data.days - dbDays;
          
          if (diff > 0) {
            if (!monthlyMissing[month]) {
              monthlyMissing[month] = {
                count: 0,
                totalDays: 0,
                employees: []
              };
            }
            monthlyMissing[month].count++;
            monthlyMissing[month].totalDays += diff;
            monthlyMissing[month].employees.push(emp.name);
          }
        });
      }
    });
    
    const months = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월'];
    months.forEach(month => {
      if (monthlyMissing[month]) {
        console.log(`${month}: ${monthlyMissing[month].count}명에서 총 ${monthlyMissing[month].totalDays.toFixed(1)}일 누락`);
      }
    });

  } catch (error) {
    console.error('Error:', error);
  }
}

generateFinalReport();