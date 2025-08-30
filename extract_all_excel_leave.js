const XLSX = require('xlsx');
const fs = require('fs');

// 엑셀 파일 읽기
const workbook = XLSX.readFile('78월.xlsx');
const worksheet = workbook.Sheets['휴가대장 관리용'];

// 더 자세한 옵션으로 파싱
const rawData = XLSX.utils.sheet_to_json(worksheet, { 
  header: 1,  // 배열로 가져오기
  raw: false,
  dateNF: 'yyyy-mm-dd'
});

console.log('=== 78월 엑셀 파일 전체 연차 데이터 추출 (1~8월) ===\n');

// 헤더 찾기
let headerRowIndex = -1;
let dataStartRow = -1;

rawData.forEach((row, idx) => {
  if (row.includes('성  명') || row.includes('성명')) {
    headerRowIndex = idx;
    dataStartRow = idx + 1;
  }
});

// 월별 컬럼 인덱스 (보통 10번째부터 시작)
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

let allEmployeeData = [];

if (dataStartRow > 0) {
  for (let i = dataStartRow; i < rawData.length; i++) {
    const row = rawData[i];
    
    // 이름이 있는 행만 처리
    const name = row[2]; // 성명 컬럼
    if (!name || name === '' || name.includes('합계')) continue;
    
    const employeeData = {
      name: name.trim(),
      position: (row[1] || '').trim(),
      monthlyLeave: {},
      totalDays: 0,
      details: []
    };
    
    // 각 월별 데이터 추출
    Object.entries(monthColumns).forEach(([month, colIndex]) => {
      const monthData = row[colIndex] || '';
      
      if (monthData && monthData.trim()) {
        const parsedDates = parseLeaveData(monthData);
        employeeData.monthlyLeave[month] = {
          raw: monthData,
          dates: parsedDates.dates,
          halfDays: parsedDates.halfDays,
          days: parsedDates.totalDays
        };
        employeeData.totalDays += parsedDates.totalDays;
        
        // 상세 내역 추가
        parsedDates.dates.forEach(date => {
          employeeData.details.push({
            month: month,
            day: date,
            type: 'annual'
          });
        });
        
        parsedDates.halfDays.forEach(half => {
          employeeData.details.push({
            month: month,
            day: half.day,
            type: half.type
          });
        });
      }
    });
    
    if (employeeData.totalDays > 0) {
      allEmployeeData.push(employeeData);
    }
  }
}

// 연차 데이터 파싱 함수 (개선된 버전)
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

// 결과 출력
console.log(`총 ${allEmployeeData.length}명의 직원 연차 데이터 추출\n`);

// 직원별 요약
allEmployeeData.forEach(emp => {
  console.log(`${emp.name} (${emp.position})`);
  console.log(`  총 사용 연차: ${emp.totalDays}일`);
  
  Object.entries(emp.monthlyLeave).forEach(([month, data]) => {
    if (data.days > 0) {
      console.log(`  ${month}: ${data.days}일 - ${data.raw}`);
    }
  });
  console.log('');
});

// 전체 통계
const totalByMonth = {};
Object.keys(monthColumns).forEach(month => {
  totalByMonth[month] = 0;
});

allEmployeeData.forEach(emp => {
  Object.entries(emp.monthlyLeave).forEach(([month, data]) => {
    totalByMonth[month] += data.days;
  });
});

console.log('=== 월별 전체 통계 ===');
Object.entries(totalByMonth).forEach(([month, total]) => {
  console.log(`${month}: ${total}일`);
});

const grandTotal = Object.values(totalByMonth).reduce((sum, val) => sum + val, 0);
console.log(`\n전체 총합: ${grandTotal}일`);

// JSON 파일로 저장
fs.writeFileSync('excel_all_leave_data.json', JSON.stringify(allEmployeeData, null, 2), 'utf-8');
console.log(`\n✅ 데이터를 excel_all_leave_data.json 파일로 저장했습니다.`);