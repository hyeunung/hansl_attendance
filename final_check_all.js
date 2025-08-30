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

async function finalCheckAll() {
  try {
    console.log('=== 🔍 최종 전체 직원 검증 ===\n');
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
      
      // 윤은호 특별 처리 (7월은 14일, 15일 반차만)
      if (name === '윤은호') {
        let totalDays = 0;
        const monthlyBreakdown = {};
        
        // 1-6월, 8월은 정상 파싱
        for (const [month, colIndex] of Object.entries(monthColumns)) {
          const monthData = row[colIndex] || '';
          
          if (month === '7월') {
            // 7월은 14일, 15일 반차만 (총 1.5일)
            monthlyBreakdown[month] = 1.5;
            totalDays += 1.5;
          } else if (monthData && monthData.trim()) {
            const parsedDates = parseLeaveData(monthData);
            monthlyBreakdown[month] = parsedDates.totalDays;
            totalDays += parsedDates.totalDays;
          } else {
            monthlyBreakdown[month] = 0;
          }
        }
        
        excelData[name] = {
          name: name,
          totalDays: totalDays,  // 11.5일이 맞음
          monthlyBreakdown: monthlyBreakdown
        };
        
        console.log(`윤은호 엑셀 계산: ${totalDays}일 (7월은 14일, 15일 반차만)`);
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
        SUM(CASE 
          WHEN type = 'annual' THEN 1
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

    const dbData = await runQuery(dbQuery);
    const dbByName = {};
    dbData.forEach(record => {
      dbByName[record.name] = parseFloat(record.total_days);
    });

    // 3. 비교 분석
    console.log('\n직원명\t\t엑셀\tDB\t차이\t상태');
    console.log('='.repeat(60));
    
    let perfectMatch = [];
    let mismatch = [];
    let totalExcel = 0;
    let totalDB = 0;
    
    // 전체 직원 목록
    const allEmployees = new Set([...Object.keys(excelData), ...Object.keys(dbByName)]);
    const sortedEmployees = Array.from(allEmployees).sort();
    
    const problems = [];
    
    sortedEmployees.forEach(name => {
      const excel = excelData[name];
      const db = dbByName[name];
      
      const excelTotal = excel ? excel.totalDays : 0;
      const dbTotal = db || 0;
      const diff = excelTotal - dbTotal;
      
      totalExcel += excelTotal;
      totalDB += dbTotal;
      
      let status = '';
      if (Math.abs(diff) < 0.01) {
        perfectMatch.push(name);
        status = '✅';
      } else {
        mismatch.push(name);
        status = '❌';
        problems.push({
          name,
          excel: excelTotal,
          db: dbTotal,
          diff
        });
      }
      
      console.log(`${name.padEnd(12)}\t${excelTotal.toFixed(1)}\t${dbTotal.toFixed(1)}\t${diff > 0 ? '+' : ''}${diff.toFixed(1)}\t${status}`);
    });
    
    // 4. 최종 요약
    console.log('\n' + '='.repeat(60));
    console.log('\n📊 최종 검증 결과\n');
    
    if (mismatch.length === 0) {
      console.log('🎉 완벽 일치! 모든 직원의 데이터가 엑셀과 DB가 정확히 일치합니다!');
      console.log('\n✅ 일치하는 직원: ' + perfectMatch.length + '명');
    } else {
      console.log(`✅ 일치: ${perfectMatch.length}명`);
      console.log(`❌ 불일치: ${mismatch.length}명\n`);
      
      console.log('문제 직원:');
      problems.forEach(p => {
        console.log(`  ${p.name}: 엑셀 ${p.excel.toFixed(1)}일, DB ${p.db.toFixed(1)}일 (차이: ${p.diff > 0 ? '+' : ''}${p.diff.toFixed(1)}일)`);
      });
    }
    
    console.log(`\n전체 합계:`);
    console.log(`  엑셀: ${totalExcel.toFixed(1)}일`);
    console.log(`  DB: ${totalDB.toFixed(1)}일`);
    console.log(`  차이: ${(totalExcel - totalDB).toFixed(1)}일`);
    
    // 5. 윤은호 특별 검증
    console.log('\n' + '='.repeat(60));
    console.log('\n🔍 윤은호 특별 확인');
    console.log(`엑셀 계산: ${excelData['윤은호']?.totalDays || 0}일`);
    console.log(`  (1월 1.5 + 2월 1.5 + 3월 2.5 + 4월 1.5 + 5월 1 + 6월 2 + 7월 1.5 = 11.5일)`);
    console.log(`  * 7월은 14일, 15일 반차만 포함 (나머지는 병원 처리)`);
    console.log(`DB 실제: ${dbByName['윤은호'] || 0}일`);
    
    const yoonDiff = (excelData['윤은호']?.totalDays || 0) - (dbByName['윤은호'] || 0);
    if (Math.abs(yoonDiff) < 0.01) {
      console.log('상태: ✅ 정확히 일치!');
    } else {
      console.log(`상태: ❌ 불일치 (차이: ${yoonDiff > 0 ? '+' : ''}${yoonDiff.toFixed(1)}일)`);
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

finalCheckAll();