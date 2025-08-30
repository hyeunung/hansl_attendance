const XLSX = require('xlsx');

const workbook = XLSX.readFile('78월.xlsx');
const worksheet = workbook.Sheets['휴가대장 관리용'];

const rawData = XLSX.utils.sheet_to_json(worksheet, { 
  header: 1,
  raw: false
});

for (let i = 0; i < rawData.length; i++) {
  const row = rawData[i];
  if (row[2] && row[2].includes('윤은호')) {
    console.log('윤은호 2월 원본 데이터:');
    console.log(`2월 (컬럼 11): "${row[11]}"`);
    
    // 파싱
    const febData = row[11];
    if (febData) {
      console.log('\n파싱 결과:');
      // 7일
      if (febData.includes('7일')) console.log('  - 7일 발견');
      // 14일(오후반차)
      if (febData.includes('14일')) {
        if (febData.includes('오후')) {
          console.log('  - 14일(오후반차) 발견');
        } else {
          console.log('  - 14일 발견');
        }
      }
    }
    break;
  }
}