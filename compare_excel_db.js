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

async function compareExcelWithDB() {
  try {
    console.log('=== 엑셀 데이터와 DB 데이터 비교 분석 ===\n');

    // 1. 엑셀 데이터 로드
    const excelData = JSON.parse(fs.readFileSync('excel_leave_data.json', 'utf-8'));
    console.log(`엑셀 데이터: ${excelData.length}명\n`);

    // 2. DB에서 7-8월 데이터 가져오기
    const dbQuery = `
      SELECT 
        name,
        user_email,
        type,
        start_date,
        end_date,
        status,
        EXTRACT(MONTH FROM start_date) as month,
        EXTRACT(DAY FROM start_date) as day
      FROM leave
      WHERE status = 'approved'
        AND ((start_date >= '2025-07-01' AND start_date <= '2025-08-31')
             OR (end_date >= '2025-07-01' AND end_date <= '2025-08-31'))
      ORDER BY name, start_date
    `;

    const dbData = await runQuery(dbQuery);
    console.log(`DB 데이터: ${dbData.length}건\n`);

    // 3. DB 데이터를 이름별로 그룹화
    const dbByName = {};
    dbData.forEach(record => {
      if (!dbByName[record.name]) {
        dbByName[record.name] = {
          july: [],
          august: [],
          records: []
        };
      }
      
      dbByName[record.name].records.push(record);
      
      const month = parseInt(record.month);
      const day = parseInt(record.day);
      
      if (month === 7) {
        dbByName[record.name].july.push({
          day: day,
          type: record.type
        });
      } else if (month === 8) {
        dbByName[record.name].august.push({
          day: day,
          type: record.type
        });
      }
    });

    // 4. 비교 분석
    console.log('=== 직원별 비교 결과 ===\n');
    
    let perfectMatch = [];
    let mismatch = [];
    let onlyInExcel = [];
    let onlyInDB = [];

    // 엑셀 데이터 기준으로 비교
    excelData.forEach(excelEmp => {
      const name = excelEmp.name;
      const dbEmp = dbByName[name];
      
      if (!dbEmp) {
        onlyInExcel.push(excelEmp);
        console.log(`❌ ${name}: 엑셀에만 있음`);
        console.log(`   엑셀 - 7월: ${excelEmp.julyDays}일, 8월: ${excelEmp.augustDays}일`);
        console.log('');
      } else {
        // 날짜 비교
        const excelJulyDays = excelEmp.julyDates || [];
        const excelAugustDays = excelEmp.augustDates || [];
        const dbJulyDays = dbEmp.july.map(d => d.day);
        const dbAugustDays = dbEmp.august.map(d => d.day);
        
        const julyMatch = arraysEqual(excelJulyDays.sort(), dbJulyDays.sort());
        const augustMatch = arraysEqual(excelAugustDays.sort(), dbAugustDays.sort());
        
        if (julyMatch && augustMatch) {
          perfectMatch.push(name);
          console.log(`✅ ${name}: 완벽 일치`);
        } else {
          mismatch.push({
            name: name,
            excel: { july: excelJulyDays, august: excelAugustDays },
            db: { july: dbJulyDays, august: dbAugustDays }
          });
          console.log(`⚠️ ${name}: 불일치`);
          
          if (!julyMatch) {
            console.log(`   7월 - 엑셀: [${excelJulyDays.join(', ')}], DB: [${dbJulyDays.join(', ')}]`);
          }
          if (!augustMatch) {
            console.log(`   8월 - 엑셀: [${excelAugustDays.join(', ')}], DB: [${dbAugustDays.join(', ')}]`);
          }
        }
        console.log('');
      }
    });

    // DB에만 있는 직원 찾기
    Object.keys(dbByName).forEach(name => {
      if (!excelData.find(e => e.name === name)) {
        onlyInDB.push(name);
      }
    });

    // 5. 최종 요약
    console.log('\n=== 최종 요약 ===');
    console.log(`✅ 완벽 일치: ${perfectMatch.length}명`);
    console.log(`⚠️ 불일치: ${mismatch.length}명`);
    console.log(`❌ 엑셀에만 있음: ${onlyInExcel.length}명`);
    console.log(`❌ DB에만 있음: ${onlyInDB.length}명`);
    
    if (onlyInExcel.length > 0) {
      console.log('\n엑셀에만 있는 직원:');
      onlyInExcel.forEach(emp => {
        console.log(`  - ${emp.name}: 7월 ${emp.julyDays}일, 8월 ${emp.augustDays}일`);
      });
    }
    
    if (onlyInDB.length > 0) {
      console.log('\nDB에만 있는 직원:');
      onlyInDB.forEach(name => {
        console.log(`  - ${name}`);
      });
    }

    // 상세 불일치 내역 저장
    const detailReport = {
      perfectMatch,
      mismatch,
      onlyInExcel,
      onlyInDB,
      summary: {
        excel: excelData.length,
        db: Object.keys(dbByName).length,
        perfectMatch: perfectMatch.length,
        mismatch: mismatch.length,
        onlyInExcel: onlyInExcel.length,
        onlyInDB: onlyInDB.length
      }
    };
    
    fs.writeFileSync('comparison_report.json', JSON.stringify(detailReport, null, 2), 'utf-8');
    console.log('\n✅ 상세 비교 결과를 comparison_report.json 파일로 저장했습니다.');

  } catch (error) {
    console.error('Error:', error);
  }
}

function arraysEqual(a, b) {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

compareExcelWithDB();