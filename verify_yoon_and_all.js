const fetch = require('node-fetch');
const XLSX = require('xlsx');
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

// 연차 데이터 파싱 함수
function parseLeaveData(data) {
  if (!data) return { dates: [], halfDays: [], totalDays: 0 };
  
  const str = String(data).trim();
  const dates = [];
  const halfDays = [];
  let totalDays = 0;
  
  // 여러 줄로 나뉜 데이터 처리
  const lines = str.split(/[\n\r]+/);
  
  lines.forEach(line => {
    // 날짜 추출 (숫자 + 일)
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

async function verifyAllEmployees() {
  try {
    console.log('=== 전체 직원 1~8월 연차 사용 내역 재검증 ===\n');

    // 1. 엑셀 파일 다시 읽기
    const workbook = XLSX.readFile('78월.xlsx');
    const worksheet = workbook.Sheets['휴가대장 관리용'];
    const rawData = XLSX.utils.sheet_to_json(worksheet, { 
      header: 1,
      raw: false,
      dateNF: 'yyyy-mm-dd'
    });

    // 헤더 찾기
    let headerRowIndex = -1;
    let dataStartRow = -1;
    
    rawData.forEach((row, idx) => {
      if (row.includes('성  명') || row.includes('성명')) {
        headerRowIndex = idx;
        dataStartRow = idx + 1;
      }
    });

    // 월별 컬럼 인덱스
    const monthColumns = {
      '1월': 10,
      '2월': 11,
      '3월': 12,
      '4월': 13,
      '5월': 14,
      '6월': 15,
      '7월': 16,
      '8월': 17
    };

    // 엑셀 데이터 파싱
    const excelData = {};
    
    for (let i = dataStartRow; i < rawData.length; i++) {
      const row = rawData[i];
      const name = row[2]?.trim();
      
      if (!name || name === '' || name.includes('합계')) continue;
      
      const employeeData = {
        name: name,
        position: (row[1] || '').trim(),
        monthlyDetail: {},
        totalDays: 0
      };
      
      // 각 월별 데이터 추출
      Object.entries(monthColumns).forEach(([month, colIndex]) => {
        const monthData = row[colIndex] || '';
        
        if (monthData && monthData.trim()) {
          const parsedDates = parseLeaveData(monthData);
          employeeData.monthlyDetail[month] = {
            raw: monthData.trim(),
            dates: parsedDates.dates,
            halfDays: parsedDates.halfDays,
            days: parsedDates.totalDays
          };
          employeeData.totalDays += parsedDates.totalDays;
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
      ORDER BY name, start_date
    `;

    const dbRawData = await runQuery(dbQuery);
    
    // DB 데이터를 직원별로 정리
    const dbData = {};
    
    dbRawData.forEach(record => {
      const name = record.name;
      if (!dbData[name]) {
        dbData[name] = {
          name: name,
          monthlyDetail: {},
          totalDays: 0,
          records: []
        };
      }
      
      const monthKey = `${record.month}월`;
      
      if (!dbData[name].monthlyDetail[monthKey]) {
        dbData[name].monthlyDetail[monthKey] = {
          dates: [],
          halfDays: [],
          days: 0
        };
      }
      
      // 날짜와 타입 저장
      if (record.type === 'annual') {
        dbData[name].monthlyDetail[monthKey].dates.push(record.day);
      } else if (record.type === 'half_am' || record.type === 'half_pm') {
        dbData[name].monthlyDetail[monthKey].halfDays.push({
          day: record.day,
          type: record.type
        });
      }
      
      dbData[name].monthlyDetail[monthKey].days += parseFloat(record.days);
      dbData[name].totalDays += parseFloat(record.days);
      dbData[name].records.push(record);
    });

    // 3. 전체 직원 목록 생성
    const allEmployees = new Set([...Object.keys(excelData), ...Object.keys(dbData)]);
    
    // 4. 직원별 상세 출력
    console.log('직원명\t\t엑셀\tDB\t차이\t월별 상세');
    console.log('='.repeat(100));
    
    let totalExcel = 0;
    let totalDB = 0;
    
    // 이름순 정렬
    const sortedEmployees = Array.from(allEmployees).sort();
    
    sortedEmployees.forEach(name => {
      const excel = excelData[name];
      const db = dbData[name];
      
      const excelTotal = excel ? excel.totalDays : 0;
      const dbTotal = db ? db.totalDays : 0;
      const diff = excelTotal - dbTotal;
      
      totalExcel += excelTotal;
      totalDB += dbTotal;
      
      // 기본 정보 출력
      console.log(`\n${name.padEnd(12)}\t${excelTotal}\t${dbTotal}\t${diff > 0 ? '+' : ''}${diff}`);
      
      // 월별 상세 출력
      const months = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월'];
      
      months.forEach(month => {
        const excelMonth = excel?.monthlyDetail[month];
        const dbMonth = db?.monthlyDetail[month];
        
        if (excelMonth || dbMonth) {
          const excelDays = excelMonth?.days || 0;
          const dbDays = dbMonth?.days || 0;
          
          if (excelDays > 0 || dbDays > 0) {
            console.log(`  ${month}: 엑셀 ${excelDays}일 / DB ${dbDays}일`);
            
            // 엑셀 상세
            if (excelMonth && excelMonth.days > 0) {
              if (excelMonth.dates.length > 0) {
                console.log(`    엑셀 연차: ${excelMonth.dates.join(', ')}일`);
              }
              if (excelMonth.halfDays.length > 0) {
                const halfStr = excelMonth.halfDays.map(h => 
                  `${h.day}일(${h.type === 'half_am' ? '오전' : '오후'})`
                ).join(', ');
                console.log(`    엑셀 반차: ${halfStr}`);
              }
            }
            
            // DB 상세
            if (dbMonth && dbMonth.days > 0) {
              if (dbMonth.dates.length > 0) {
                console.log(`    DB 연차: ${dbMonth.dates.join(', ')}일`);
              }
              if (dbMonth.halfDays.length > 0) {
                const halfStr = dbMonth.halfDays.map(h => 
                  `${h.day}일(${h.type === 'half_am' ? '오전' : '오후'})`
                ).join(', ');
                console.log(`    DB 반차: ${halfStr}`);
              }
            }
          }
        }
      });
    });
    
    // 5. 최종 요약
    console.log('\n' + '='.repeat(100));
    console.log('\n=== 최종 요약 ===');
    console.log(`엑셀 총계: ${Object.keys(excelData).length}명, ${totalExcel}일`);
    console.log(`DB 총계: ${Object.keys(dbData).length}명, ${totalDB}일`);
    console.log(`차이: ${totalExcel - totalDB}일 누락`);
    
    // 특별히 윤은호 확인
    console.log('\n=== 윤은호 특별 확인 ===');
    if (excelData['윤은호']) {
      console.log('엑셀에서 윤은호:');
      console.log(`  총 ${excelData['윤은호'].totalDays}일`);
      Object.entries(excelData['윤은호'].monthlyDetail).forEach(([month, data]) => {
        console.log(`  ${month}: ${data.days}일 - ${data.raw}`);
      });
    }
    
    if (dbData['윤은호']) {
      console.log('\nDB에서 윤은호:');
      console.log(`  총 ${dbData['윤은호'].totalDays}일`);
      Object.entries(dbData['윤은호'].monthlyDetail).forEach(([month, data]) => {
        console.log(`  ${month}: ${data.days}일`);
      });
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

verifyAllEmployees();