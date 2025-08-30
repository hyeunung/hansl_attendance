const XLSX = require('xlsx');

// 엑셀 파일 읽기
const workbook = XLSX.readFile('78월.xlsx');
const worksheet = workbook.Sheets['휴가대장 관리용'];

// 배열로 가져오기
const rawData = XLSX.utils.sheet_to_json(worksheet, { 
  header: 1,
  raw: false,
  dateNF: 'yyyy-mm-dd'
});

// 윤은호 찾기
console.log('=== 윤은호 7월 원본 데이터 확인 ===\n');

for (let i = 0; i < rawData.length; i++) {
  const row = rawData[i];
  if (row[2] && row[2].includes('윤은호')) {
    console.log(`행 번호: ${i + 1}`);
    console.log(`이름: ${row[2]}`);
    console.log(`직급: ${row[1]}`);
    
    console.log('\n7월 원본 데이터:');
    console.log(`컬럼 16 (7월): "${row[16]}"`);
    
    // 줄바꿈으로 분리해서 보기
    if (row[16]) {
      const lines = row[16].toString().split(/[\r\n]+/);
      console.log('\n라인별 분석:');
      lines.forEach((line, idx) => {
        console.log(`  라인 ${idx + 1}: "${line.trim()}"`);
      });
    }
    
    break;
  }
}