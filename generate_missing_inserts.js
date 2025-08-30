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

async function generateMissingInserts() {
  try {
    console.log('=== 누락된 연차 데이터 추가 SQL 생성 ===\n');

    // 엑셀 데이터 로드
    const excelData = JSON.parse(fs.readFileSync('excel_all_leave_data.json', 'utf-8'));
    
    // 윤은호 데이터 수정 (10.5일로)
    const yoonIndex = excelData.findIndex(emp => emp.name === '윤은호');
    if (yoonIndex !== -1) {
      excelData[yoonIndex].monthlyLeave['7월'] = {
        raw: '14일, 15일(오후반차)',
        dates: [14],
        halfDays: [{day: 15, type: 'half_pm'}],
        days: 1.5
      };
      excelData[yoonIndex].totalDays = 10.5;
    }
    
    // 권혁진 제외
    const filteredExcelData = excelData.filter(emp => emp.name !== '권혁진');

    // 직원 email 정보 가져오기
    const employeeQuery = `
      SELECT name, email
      FROM employees
      WHERE name != '권혁진'
    `;
    const employeeData = await runQuery(employeeQuery);
    const emailMap = {};
    employeeData.forEach(emp => {
      emailMap[emp.name] = emp.email;
    });

    // DB leave 데이터 가져오기 (상세)
    const dbQuery = `
      SELECT 
        name,
        type,
        start_date,
        end_date,
        EXTRACT(MONTH FROM start_date) as month,
        EXTRACT(DAY FROM start_date) as day
      FROM leave
      WHERE status = 'approved'
        AND start_date >= '2025-01-01'
        AND start_date <= '2025-08-31'
        AND name != '권혁진'
      ORDER BY name, start_date
    `;

    const dbData = await runQuery(dbQuery);
    
    // DB 데이터를 직원별로 정리
    const dbByEmployee = {};
    dbData.forEach(record => {
      if (!dbByEmployee[record.name]) {
        dbByEmployee[record.name] = [];
      }
      dbByEmployee[record.name].push({
        month: parseInt(record.month),
        day: parseInt(record.day),
        type: record.type,
        start_date: record.start_date,
        end_date: record.end_date
      });
    });

    // INSERT 문 생성
    const insertStatements = [];
    const updateStatements = [];
    let totalInserts = 0;

    filteredExcelData.forEach(excelEmp => {
      const dbRecords = dbByEmployee[excelEmp.name] || [];
      const email = emailMap[excelEmp.name];

      if (!email) {
        console.log(`⚠️ ${excelEmp.name}의 이메일을 찾을 수 없습니다.`);
        return;
      }

      // 월별로 확인
      Object.entries(excelEmp.monthlyLeave).forEach(([monthStr, monthData]) => {
        const monthNum = parseInt(monthStr.replace('월', ''));
        
        // 해당 월의 DB 레코드
        const monthDbRecords = dbRecords.filter(r => r.month === monthNum);
        const dbDays = monthDbRecords.map(r => r.day);

        // 엑셀의 연차 날짜들
        monthData.dates?.forEach(day => {
          if (!dbDays.includes(day)) {
            const dateStr = `2025-${String(monthNum).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            insertStatements.push(`-- ${excelEmp.name} ${monthStr} ${day}일 연차 추가`);
            insertStatements.push(`INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('${excelEmp.name}', '${email}', 'annual', '${dateStr}', '${dateStr}', 'approved', '개인 사유', NOW());`);
            totalInserts++;
          }
        });

        // 엑셀의 반차 날짜들
        monthData.halfDays?.forEach(half => {
          const dbHalfDay = monthDbRecords.find(r => r.day === half.day && r.type === half.type);
          if (!dbHalfDay) {
            const dateStr = `2025-${String(monthNum).padStart(2, '0')}-${String(half.day).padStart(2, '0')}`;
            const typeStr = half.type === 'half_am' ? '오전 반차' : '오후 반차';
            insertStatements.push(`-- ${excelEmp.name} ${monthStr} ${half.day}일 ${typeStr} 추가`);
            insertStatements.push(`INSERT INTO leave (name, user_email, type, start_date, end_date, status, reason, created_at)
VALUES ('${excelEmp.name}', '${email}', '${half.type}', '${dateStr}', '${dateStr}', 'approved', '개인 사유', NOW());`);
            totalInserts++;
          }
        });
      });

      // employees 테이블 업데이트 SQL 생성
      updateStatements.push(`-- ${excelEmp.name} 사용연차 업데이트 (${excelEmp.totalDays}일)`);
      updateStatements.push(`UPDATE employees 
SET used_annual_leave = ${excelEmp.totalDays},
    remaining_annual_leave = annual_leave_granted_current_year - ${excelEmp.totalDays}
WHERE name = '${excelEmp.name}';`);
    });

    // SQL 파일 생성
    const sqlContent = `-- 누락된 연차 데이터 추가 SQL
-- 생성 시간: ${new Date().toISOString()}
-- 총 ${totalInserts}개의 레코드 추가

BEGIN;

-- 1. leave 테이블에 누락된 연차 추가
${insertStatements.join('\n\n')}

-- 2. employees 테이블 사용연차/남은연차 업데이트
${updateStatements.join('\n\n')}

COMMIT;

-- 실행 후 확인 쿼리
-- SELECT name, COUNT(*) as count, SUM(CASE WHEN type = 'annual' THEN 1 WHEN type IN ('half_am', 'half_pm') THEN 0.5 END) as days
-- FROM leave 
-- WHERE status = 'approved' AND start_date >= '2025-01-01' AND start_date <= '2025-08-31'
-- GROUP BY name
-- ORDER BY name;
`;

    fs.writeFileSync('add_missing_leave.sql', sqlContent, 'utf-8');
    
    console.log(`✅ ${totalInserts}개의 누락된 연차 INSERT 문이 생성되었습니다.`);
    console.log(`✅ ${filteredExcelData.length}명의 employees 테이블 UPDATE 문이 생성되었습니다.`);
    console.log(`\n📁 파일: add_missing_leave.sql`);
    console.log('\n실행 방법:');
    console.log('1. Supabase SQL Editor에서 위 파일 내용 실행');
    console.log('2. 또는 psql로 직접 실행');

  } catch (error) {
    console.error('Error:', error);
  }
}

generateMissingInserts();