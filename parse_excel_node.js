const XLSX = require('xlsx');
const fs = require('fs');

// 엑셀 파일 읽기
const workbook = XLSX.readFile('78월.xlsx');

console.log('=== 78월.xlsx 파일 분석 ===\n');
console.log(`시트 목록: ${workbook.SheetNames.join(', ')}\n`);

let allData = [];

// 각 시트 처리
workbook.SheetNames.forEach(sheetName => {
  const worksheet = workbook.Sheets[sheetName];
  const jsonData = XLSX.utils.sheet_to_json(worksheet, { raw: false, dateNF: 'yyyy-mm-dd' });
  
  console.log(`\n시트: ${sheetName}`);
  console.log(`데이터 행 수: ${jsonData.length}`);
  
  if (jsonData.length > 0) {
    console.log(`컬럼: ${Object.keys(jsonData[0]).join(', ')}`);
    
    // 처음 3개 데이터 샘플 출력
    console.log('\n샘플 데이터 (처음 3행):');
    jsonData.slice(0, 3).forEach((row, idx) => {
      console.log(`${idx + 1}. `, row);
    });
    
    // 모든 데이터 수집
    jsonData.forEach((row, idx) => {
      allData.push({
        sheet: sheetName,
        rowIndex: idx,
        ...row
      });
    });
  }
});

// JSON 파일로 저장
fs.writeFileSync('excel_data.json', JSON.stringify(allData, null, 2), 'utf-8');
console.log(`\n✅ 총 ${allData.length}개 행의 데이터를 excel_data.json 파일로 저장했습니다.`);

// 데이터 구조 분석
console.log('\n=== 데이터 구조 분석 ===');
if (allData.length > 0) {
  const sampleRow = allData[0];
  console.log('컬럼 목록:');
  Object.keys(sampleRow).forEach(key => {
    if (key !== 'sheet' && key !== 'rowIndex') {
      const values = [...new Set(allData.slice(0, 10).map(row => row[key]))];
      console.log(`  - ${key}: ${values.slice(0, 3).join(', ')}...`);
    }
  });
}

// 날짜 관련 컬럼 찾기
console.log('\n날짜 관련 컬럼 찾기:');
if (allData.length > 0) {
  Object.keys(allData[0]).forEach(key => {
    const value = allData[0][key];
    if (value && (value.includes('2025') || value.includes('07') || value.includes('08'))) {
      console.log(`  - ${key}: ${value}`);
    }
  });
}