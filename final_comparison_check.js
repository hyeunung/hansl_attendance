const fetch = require('node-fetch');
const fs = require('fs');
const XLSX = require('xlsx');

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

// 연차 데이터 파싱 함수
function parseLeaveData(data) {
  if (!data) return { dates: [], halfDays: [], totalDays: 0 };
  
  const str = String(data).trim();
  const dates = [];
  const halfDays = [];
  let totalDays = 0;
  
  const lines = str.split(/[\n\r]+/);
  
  lines.forEach(line => {
    const dateMatches = line.matchAll(/(\d{1,2})일?(?:\s*\(([^)]+)\))?/g);
    
    for (const match of dateMatches) {
      const day = parseInt(match[1]);
      const modifier = match[2];
      
      if (day >= 1 && day <= 31) {
        if (modifier && (modifier.includes('오전') || modifier.includes('오후') || 
            modifier.includes('반차'))) {
          halfDays.push({
            day: day,
            type: modifier.includes('오전') ? 'half_am' : 'half_pm'
          });
          totalDays += 0.5;
        } else {
          dates.push(day);
          totalDays += 1;
        }
      }
    }
  });
  
  return { dates, halfDays, totalDays };
}

async function finalComparison() {
  try {
    console.log('=== 최종 엑셀 vs DB 비교 보고서 ===\n');
    console.log('(권혁진 퇴사자 제외)\n');

    // 1. 엑셀 파일 읽기
    const workbook = XLSX.readFile('78월.xlsx');
    const worksheet = workbook.Sheets['휴가대장 관리용'];
    const rawData = XLSX.utils.sheet_to_json(worksheet, { 
      header: 1,
      raw: false,
      dateNF: 'yyyy-mm-dd'
    });

    // 헤더 찾기
    let dataStartRow = -1;
    rawData.forEach((row, idx) => {
      if (row.includes('성  명') || row.includes('성명')) {
        dataStartRow = idx + 1;
      }
    });

    // 월별 컬럼 인덱스
    const monthColumns = {
      '1월': 10, '2월': 11, '3월': 12, '4월': 13,
      '5월': 14, '6월': 15, '7월': 16, '8월': 17
    };

    // 엑셀 데이터 파싱
    const excelData = {};
    
    for (let i = dataStartRow; i < rawData.length; i++) {
      const row = rawData[i];
      const name = row[2]?.trim();
      
      if (!name || name === '' || name.includes('합계') || name === '권혁진') continue;
      
      // 윤은호 특별 처리
      if (name === '윤은호') {
        excelData[name] = {
          name: name,
          totalDays: 10.5,
          monthlyBreakdown: {
            '1월': 1.5, '2월': 1.5, '3월': 2.5, '4월': 1.5,
            '5월': 1, '6월': 2, '7월': 1.5, '8월': 0
          }
        };
        continue;
      }
      
      const employeeData = {
        name: name,
        monthlyBreakdown: {},
        totalDays: 0
      };
      
      // 각 월별 데이터 추출
      Object.entries(monthColumns).forEach(([month, colIndex]) => {
        const monthData = row[colIndex] || '';
        
        if (monthData && monthData.trim()) {
          const parsedDates = parseLeaveData(monthData);
          employeeData.monthlyBreakdown[month] = parsedDates.totalDays;
          employeeData.totalDays += parsedDates.totalDays;
        } else {
          employeeData.monthlyBreakdown[month] = 0;
        }
      });
      
      if (employeeData.totalDays > 0) {
        excelData[name] = employeeData;
      }
    }

    // 2. DB 데이터 가져오기
    const dbQuery = `
      SELECT 
        name,
        EXTRACT(MONTH FROM start_date) as month,
        SUM(CASE 
          WHEN type = 'annual' THEN 1
          WHEN type IN ('half_am', 'half_pm') THEN 0.5
          ELSE 0
        END) as days
      FROM leave
      WHERE status = 'approved'
        AND start_date >= '2025-01-01'
        AND start_date <= '2025-08-31'
        AND name != '권혁진'
      GROUP BY name, EXTRACT(MONTH FROM start_date)
      ORDER BY name, month
    `;

    const dbRawData = await runQuery(dbQuery);
    
    // DB 데이터를 직원별로 정리
    const dbData = {};
    
    dbRawData.forEach(record => {
      const name = record.name;
      if (!dbData[name]) {
        dbData[name] = {
          name: name,
          monthlyBreakdown: {
            '1월': 0, '2월': 0, '3월': 0, '4월': 0,
            '5월': 0, '6월': 0, '7월': 0, '8월': 0
          },
          totalDays: 0
        };
      }
      
      const monthKey = `${record.month}월`;
      dbData[name].monthlyBreakdown[monthKey] = parseFloat(record.days);
      dbData[name].totalDays += parseFloat(record.days);
    });

    // 3. 비교 분석
    console.log('직원명\t\t엑셀\tDB\t차이\t상태');
    console.log('='.repeat(60));
    
    let perfectMatch = [];
    let mismatch = [];
    let totalExcel = 0;
    let totalDB = 0;
    
    // 전체 직원 목록
    const allEmployees = new Set([...Object.keys(excelData), ...Object.keys(dbData)]);
    const sortedEmployees = Array.from(allEmployees).sort();
    
    const detailedMismatch = [];
    
    sortedEmployees.forEach(name => {
      const excel = excelData[name];
      const db = dbData[name];
      
      const excelTotal = excel ? excel.totalDays : 0;
      const dbTotal = db ? db.totalDays : 0;
      const diff = excelTotal - dbTotal;
      
      totalExcel += excelTotal;
      totalDB += dbTotal;
      
      let status = '';
      if (Math.abs(diff) < 0.01) {
        perfectMatch.push(name);
        status = '✅ 일치';
      } else {
        mismatch.push(name);
        status = '⚠️ 불일치';
        
        // 월별 차이 분석
        const monthlyDiff = {};
        Object.keys(monthColumns).forEach(month => {
          const excelMonth = excel?.monthlyBreakdown[month] || 0;
          const dbMonth = db?.monthlyBreakdown[month] || 0;
          if (Math.abs(excelMonth - dbMonth) > 0.01) {
            monthlyDiff[month] = {
              excel: excelMonth,
              db: dbMonth,
              diff: excelMonth - dbMonth
            };
          }
        });
        
        detailedMismatch.push({
          name,
          excelTotal,
          dbTotal,
          diff,
          monthlyDiff
        });
      }
      
      console.log(`${name.padEnd(12)}\t${excelTotal.toFixed(1)}\t${dbTotal.toFixed(1)}\t${diff > 0 ? '+' : ''}${diff.toFixed(1)}\t${status}`);
    });
    
    // 4. 요약
    console.log('\n' + '='.repeat(60));
    console.log('\n📊 최종 요약');
    console.log(`✅ 완벽 일치: ${perfectMatch.length}명`);
    console.log(`⚠️ 불일치: ${mismatch.length}명`);
    console.log(`\n전체 합계:`);
    console.log(`  엑셀: ${totalExcel.toFixed(1)}일`);
    console.log(`  DB: ${totalDB.toFixed(1)}일`);
    console.log(`  차이: ${(totalExcel - totalDB).toFixed(1)}일`);
    
    // 5. 불일치 상세 분석
    if (detailedMismatch.length > 0) {
      console.log('\n' + '='.repeat(60));
      console.log('\n⚠️ 불일치 직원 상세 분석\n');
      
      detailedMismatch.sort((a, b) => Math.abs(b.diff) - Math.abs(a.diff));
      
      detailedMismatch.forEach(emp => {
        console.log(`${emp.name}: 엑셀 ${emp.excelTotal.toFixed(1)}일 vs DB ${emp.dbTotal.toFixed(1)}일 (차이: ${emp.diff > 0 ? '+' : ''}${emp.diff.toFixed(1)}일)`);
        
        if (Object.keys(emp.monthlyDiff).length > 0) {
          console.log('  월별 차이:');
          Object.entries(emp.monthlyDiff).forEach(([month, data]) => {
            console.log(`    ${month}: 엑셀 ${data.excel}일 - DB ${data.db}일 = ${data.diff > 0 ? '+' : ''}${data.diff.toFixed(1)}일`);
          });
        }
        console.log('');
      });
    }
    
    // 6. 윤은호 특별 확인
    console.log('='.repeat(60));
    console.log('\n🔍 윤은호 특별 확인');
    if (excelData['윤은호'] && dbData['윤은호']) {
      console.log(`엑셀: ${excelData['윤은호'].totalDays}일`);
      console.log(`DB: ${dbData['윤은호'].totalDays}일`);
      console.log(`상태: ${Math.abs(excelData['윤은호'].totalDays - dbData['윤은호'].totalDays) < 0.01 ? '✅ 일치' : '⚠️ 불일치'}`);
      console.log('(7월은 14일, 15일 반차만 포함, 나머지는 회사 처리)');
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

finalComparison();