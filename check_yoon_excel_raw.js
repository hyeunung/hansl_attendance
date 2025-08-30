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
console.log('=== 윤은호 엑셀 원본 데이터 확인 ===\n');

for (let i = 0; i < rawData.length; i++) {
  const row = rawData[i];
  if (row[2] && row[2].includes('윤은호')) {
    console.log(`행 번호: ${i + 1}`);
    console.log(`이름: ${row[2]}`);
    console.log(`직급: ${row[1]}`);
    console.log('\n월별 데이터:');
    console.log(`1월 (컬럼 10): "${row[10] || ''}"`);
    console.log(`2월 (컬럼 11): "${row[11] || ''}"`);
    console.log(`3월 (컬럼 12): "${row[12] || ''}"`);
    console.log(`4월 (컬럼 13): "${row[13] || ''}"`);
    console.log(`5월 (컬럼 14): "${row[14] || ''}"`);
    console.log(`6월 (컬럼 15): "${row[15] || ''}"`);
    console.log(`7월 (컬럼 16): "${row[16] || ''}"`);
    console.log(`8월 (컬럼 17): "${row[17] || ''}"`);
    
    // 수동으로 계산
    console.log('\n=== 수동 계산 ===');
    let total = 0;
    
    // 1월
    if (row[10]) {
      console.log(`\n1월: ${row[10]}`);
      const jan = row[10].toString();
      // 10일 = 1일
      // 17일(오후반차) = 0.5일
      console.log('  10일 = 1일');
      console.log('  17일(오후반차) = 0.5일');
      console.log('  1월 소계 = 1.5일');
      total += 1.5;
    }
    
    // 2월
    if (row[11]) {
      console.log(`\n2월: ${row[11]}`);
      // 7일 = 1일
      // 14일(오후반차) = 0.5일
      console.log('  7일 = 1일');
      console.log('  14일(오후반차) = 0.5일');
      console.log('  2월 소계 = 1.5일');
      total += 1.5;
    }
    
    // 3월
    if (row[12]) {
      console.log(`\n3월: ${row[12]}`);
      // 17 = 1일
      // 18 = 1일
      // 28(오후반차) = 0.5일
      console.log('  17일 = 1일');
      console.log('  18일 = 1일');
      console.log('  28일(오후반차) = 0.5일');
      console.log('  3월 소계 = 2.5일');
      total += 2.5;
    }
    
    // 4월
    if (row[13]) {
      console.log(`\n4월: ${row[13]}`);
      // 11일 = 1일
      // 22(오후반차) = 0.5일
      console.log('  11일 = 1일');
      console.log('  22일(오후반차) = 0.5일');
      console.log('  4월 소계 = 1.5일');
      total += 1.5;
    }
    
    // 5월
    if (row[14]) {
      console.log(`\n5월: ${row[14]}`);
      // 22일 = 1일
      console.log('  22일 = 1일');
      console.log('  5월 소계 = 1일');
      total += 1;
    }
    
    // 6월
    if (row[15]) {
      console.log(`\n6월: ${row[15]}`);
      // 10일(오후반차) = 0.5일
      // 23일(오후반차) = 0.5일
      // 27일 = 1일
      console.log('  10일(오후반차) = 0.5일');
      console.log('  23일(오후반차) = 0.5일');
      console.log('  27일 = 1일');
      console.log('  6월 소계 = 2일');
      total += 2;
    }
    
    // 7월
    if (row[16]) {
      console.log(`\n7월: ${row[16]}`);
      const july = row[16].toString();
      
      // 7월 데이터를 라인별로 분리
      const lines = july.split(/[\n\r]+/);
      console.log('  라인별 분석:');
      lines.forEach(line => {
        console.log(`    "${line}"`);
      });
      
      // 날짜 카운트
      let julyDays = 0;
      if (july.includes('14일')) julyDays += 1;
      if (july.includes('15일(오후반차)')) julyDays += 0.5;
      if (july.includes('18일')) julyDays += 1;
      if (july.includes('21일')) julyDays += 1;
      if (july.includes('22일')) julyDays += 1;
      if (july.includes('23일')) julyDays += 1;
      if (july.includes('24일')) julyDays += 1;
      if (july.includes('25일')) julyDays += 1;
      
      console.log(`  7월 소계 = ${julyDays}일`);
      total += julyDays;
    }
    
    // 8월
    if (row[17]) {
      console.log(`\n8월: ${row[17]}`);
      console.log('  8월 소계 = 0일');
    }
    
    console.log(`\n총 합계: ${total}일`);
    break;
  }
}