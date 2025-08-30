const fs = require('fs');
const XLSX = require('xlsx');

// 엑셀 파일 다시 읽기 - 휴가대장 관리용 시트에 집중
const workbook = XLSX.readFile('78월.xlsx');
const worksheet = workbook.Sheets['휴가대장 관리용'];

// 더 자세한 옵션으로 파싱
const rawData = XLSX.utils.sheet_to_json(worksheet, { 
  header: 1,  // 첫 번째 행을 헤더로 사용하지 않고 배열로 가져오기
  raw: false,
  dateNF: 'yyyy-mm-dd'
});

console.log('=== 휴가대장 관리용 시트 상세 분석 ===\n');
console.log(`총 행 수: ${rawData.length}`);

// 헤더 찾기 (보통 2-3번째 행에 있음)
let headerRowIndex = -1;
let dataStartRow = -1;

rawData.forEach((row, idx) => {
  if (row.includes('성  명') || row.includes('성명')) {
    headerRowIndex = idx;
    dataStartRow = idx + 1;
    console.log(`\n헤더 행 발견: ${idx + 1}번째 행`);
    console.log('헤더:', row.filter(cell => cell).join(' | '));
  }
});

// 7월(16번 컬럼), 8월(17번 컬럼) 데이터 추출
const monthColumns = {
  '7월': 16,
  '8월': 17
};

console.log('\n=== 7-8월 연차 사용 데이터 ===\n');

let employeeLeaveData = [];

if (dataStartRow > 0) {
  for (let i = dataStartRow; i < rawData.length; i++) {
    const row = rawData[i];
    
    // 이름이 있는 행만 처리
    const name = row[2]; // 성명 컬럼 (보통 3번째)
    if (!name || name === '' || name.includes('합계')) continue;
    
    const julyData = row[monthColumns['7월']] || '';
    const augustData = row[monthColumns['8월']] || '';
    
    if (julyData || augustData) {
      const employee = {
        name: name,
        position: row[1] || '',
        july: julyData,
        august: augustData,
        julyDays: 0,
        augustDays: 0,
        totalDays: 0
      };
      
      // 날짜 파싱
      if (julyData) {
        const dates = parseLeaveData(julyData);
        employee.julyDates = dates;
        employee.julyDays = dates.length;
      }
      
      if (augustData) {
        const dates = parseLeaveData(augustData);
        employee.augustDates = dates;
        employee.augustDays = dates.length;
      }
      
      employee.totalDays = employee.julyDays + employee.augustDays;
      
      if (employee.totalDays > 0) {
        employeeLeaveData.push(employee);
        console.log(`${employee.name}:`);
        console.log(`  7월: ${employee.july} (${employee.julyDays}일)`);
        console.log(`  8월: ${employee.august} (${employee.augustDays}일)`);
        console.log(`  합계: ${employee.totalDays}일\n`);
      }
    }
  }
}

// 연차 데이터 파싱 함수
function parseLeaveData(data) {
  if (!data) return [];
  
  const str = String(data).trim();
  const dates = [];
  
  // 다양한 형식 처리: "1,2,3", "1, 2, 3", "1.2.3", "1 2 3" 등
  const parts = str.split(/[,\s.]+/);
  
  parts.forEach(part => {
    const cleaned = part.trim();
    if (cleaned) {
      // 숫자만 추출
      const num = parseInt(cleaned);
      if (!isNaN(num) && num >= 1 && num <= 31) {
        dates.push(num);
      }
      // 반차 처리 (오전/오후)
      if (cleaned.includes('오전') || cleaned.includes('오후') || 
          cleaned.includes('AM') || cleaned.includes('PM')) {
        // 반차는 0.5일로 계산되지만 날짜는 포함
        const dayNum = parseInt(cleaned.replace(/[^0-9]/g, ''));
        if (!isNaN(dayNum) && dayNum >= 1 && dayNum <= 31) {
          dates.push(dayNum);
        }
      }
    }
  });
  
  return dates;
}

// 결과 저장
fs.writeFileSync('excel_leave_data.json', JSON.stringify(employeeLeaveData, null, 2), 'utf-8');
console.log(`\n✅ ${employeeLeaveData.length}명의 7-8월 연차 데이터를 excel_leave_data.json 파일로 저장했습니다.`);

// 통계
const totalJulyDays = employeeLeaveData.reduce((sum, emp) => sum + emp.julyDays, 0);
const totalAugustDays = employeeLeaveData.reduce((sum, emp) => sum + emp.augustDays, 0);

console.log('\n=== 엑셀 데이터 통계 ===');
console.log(`7월 총 연차 사용: ${totalJulyDays}일`);
console.log(`8월 총 연차 사용: ${totalAugustDays}일`);
console.log(`전체 총 연차 사용: ${totalJulyDays + totalAugustDays}일`);