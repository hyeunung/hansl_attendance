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

async function detailedPersonCheck() {
  try {
    console.log('=== 직원별 상세 연차 데이터 대조 (1~8월) ===\n');

    // 1. 엑셀 데이터 로드
    const excelData = JSON.parse(fs.readFileSync('excel_all_leave_data.json', 'utf-8'));
    
    // 2. 각 직원별로 상세 확인
    for (const excelEmp of excelData) {
      console.log('─'.repeat(80));
      console.log(`\n🔍 ${excelEmp.name} 상세 분석\n`);
      
      // DB에서 해당 직원의 모든 연차 데이터 가져오기
      const dbQuery = `
        SELECT 
          name,
          user_email,
          type,
          start_date,
          end_date,
          status,
          reason,
          created_at,
          EXTRACT(MONTH FROM start_date) as month,
          EXTRACT(DAY FROM start_date) as start_day,
          EXTRACT(DAY FROM end_date) as end_day,
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
        WHERE name = '${excelEmp.name}'
          AND status = 'approved'
          AND start_date >= '2025-01-01'
          AND start_date <= '2025-08-31'
        ORDER BY start_date
      `;

      const dbData = await runQuery(dbQuery);
      
      // 엑셀 데이터 정리
      console.log('📊 엑셀 데이터:');
      console.log(`  총 ${excelEmp.totalDays}일 사용`);
      
      Object.entries(excelEmp.monthlyLeave).forEach(([month, data]) => {
        if (data.days > 0) {
          console.log(`  ${month}: ${data.days}일`);
          console.log(`    원본: ${data.raw}`);
          if (data.dates && data.dates.length > 0) {
            console.log(`    연차: ${data.dates.join(', ')}일`);
          }
          if (data.halfDays && data.halfDays.length > 0) {
            const halfDayStr = data.halfDays.map(h => `${h.day}일(${h.type === 'half_am' ? '오전' : '오후'}반차)`).join(', ');
            console.log(`    반차: ${halfDayStr}`);
          }
        }
      });
      
      // DB 데이터 정리
      console.log('\n💾 DB 데이터:');
      if (dbData.length === 0) {
        console.log('  ❌ DB에 데이터 없음');
      } else {
        // 월별로 그룹화
        const dbByMonth = {};
        let dbTotal = 0;
        
        dbData.forEach(record => {
          const monthKey = `${record.month}월`;
          if (!dbByMonth[monthKey]) {
            dbByMonth[monthKey] = {
              records: [],
              total: 0
            };
          }
          dbByMonth[monthKey].records.push(record);
          dbByMonth[monthKey].total += parseFloat(record.days);
          dbTotal += parseFloat(record.days);
        });
        
        console.log(`  총 ${dbTotal}일 사용 (${dbData.length}건)`);
        
        Object.entries(dbByMonth).forEach(([month, data]) => {
          console.log(`  ${month}: ${data.total}일`);
          data.records.forEach(record => {
            const typeStr = record.type === 'annual' ? '연차' : 
                          record.type === 'half_am' ? '오전반차' : 
                          record.type === 'half_pm' ? '오후반차' : record.type;
            console.log(`    ${record.start_day}일: ${typeStr} (${record.days}일)`);
          });
        });
      }
      
      // 차이 분석
      console.log('\n⚖️ 비교 결과:');
      const dbTotal = dbData.reduce((sum, r) => sum + parseFloat(r.days), 0);
      const difference = excelEmp.totalDays - dbTotal;
      
      if (Math.abs(difference) < 0.01) {
        console.log('  ✅ 완벽 일치');
      } else {
        console.log(`  ⚠️ 불일치: 엑셀 ${excelEmp.totalDays}일 vs DB ${dbTotal}일`);
        console.log(`  차이: ${difference > 0 ? '+' : ''}${difference}일`);
        
        // 월별 차이 상세
        console.log('\n  월별 차이:');
        const dbByMonth = {};
        dbData.forEach(record => {
          const monthKey = `${record.month}월`;
          if (!dbByMonth[monthKey]) dbByMonth[monthKey] = 0;
          dbByMonth[monthKey] += parseFloat(record.days);
        });
        
        const allMonths = new Set([...Object.keys(excelEmp.monthlyLeave), ...Object.keys(dbByMonth)]);
        
        allMonths.forEach(month => {
          const excelDays = excelEmp.monthlyLeave[month]?.days || 0;
          const dbDays = dbByMonth[month] || 0;
          
          if (Math.abs(excelDays - dbDays) > 0.01) {
            console.log(`    ${month}: 엑셀 ${excelDays}일 - DB ${dbDays}일 = 차이 ${excelDays - dbDays}일`);
            
            // 구체적으로 어떤 날짜가 누락되었는지 확인
            if (excelEmp.monthlyLeave[month]) {
              const monthNum = parseInt(month.replace('월', ''));
              const dbDaysInMonth = dbData
                .filter(r => parseInt(r.month) === monthNum)
                .map(r => parseInt(r.start_day));
              
              const excelDaysInMonth = excelEmp.monthlyLeave[month].dates || [];
              const excelHalfDaysInMonth = excelEmp.monthlyLeave[month].halfDays?.map(h => h.day) || [];
              
              const missingDays = [...excelDaysInMonth, ...excelHalfDaysInMonth]
                .filter(day => !dbDaysInMonth.includes(day));
              
              if (missingDays.length > 0) {
                console.log(`      누락된 날짜: ${missingDays.join(', ')}일`);
              }
            }
          }
        });
      }
      
      console.log('');
    }
    
    // 전체 요약
    console.log('\n' + '='.repeat(80));
    console.log('\n📊 전체 요약\n');
    
    const excelTotal = excelData.reduce((sum, emp) => sum + emp.totalDays, 0);
    
    // DB 전체 합계
    const dbTotalQuery = `
      SELECT 
        COUNT(DISTINCT name) as unique_employees,
        COUNT(*) as total_records,
        SUM(CASE 
          WHEN type = 'annual' THEN 
            CASE 
              WHEN start_date = end_date THEN 1
              ELSE (end_date - start_date + 1)
            END
          WHEN type IN ('half_am', 'half_pm') THEN 0.5
          ELSE 0
        END) as total_days
      FROM leave
      WHERE status = 'approved'
        AND start_date >= '2025-01-01'
        AND start_date <= '2025-08-31'
    `;
    
    const dbSummary = await runQuery(dbTotalQuery);
    
    console.log(`엑셀: ${excelData.length}명, 총 ${excelTotal}일`);
    console.log(`DB: ${dbSummary[0].unique_employees}명, 총 ${dbSummary[0].total_days}일`);
    console.log(`차이: ${excelTotal - dbSummary[0].total_days}일 누락`);
    
  } catch (error) {
    console.error('Error:', error);
  }
}

detailedPersonCheck();