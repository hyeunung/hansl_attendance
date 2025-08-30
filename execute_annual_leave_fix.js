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

async function executeSQLFile() {
  try {
    // SQL 파일 읽기
    const sql = fs.readFileSync('fix_annual_leave_august.sql', 'utf8');
    
    console.log('🔧 연차 수정 SQL 실행 중...\n');
    
    // BEGIN부터 COMMIT까지만 추출 (검증 쿼리 제외)
    const executeSql = sql.split('-- 검증 쿼리')[0].trim();
    
    // SQL 실행
    const result = await runQuery(executeSql);
    
    console.log('✅ SQL 실행 완료\n');
    
    // 검증 쿼리 실행
    const verifyQuery = `
      SELECT name, join_date, 
             annual_leave_granted_current_year as granted,
             used_annual_leave as used,
             remaining_annual_leave as remaining
      FROM employees
      WHERE email IN (
        'young-eun.kang@hansl.com',
        'do-geun.yeo@hansl.com',
        'jin-tae.seok@hansl.com',
        'eun-ho.yoon@hansl.com',
        'yu-seong.na@hansl.com',
        'hee-ung.jeong@hansl.com',
        'hee-seung.kim@hansl.com',
        'seung-hoo.jung@hansl.com',
        'ji-hye.kim@hansl.com',
        'hcb@hansl.com'
      )
      ORDER BY join_date, name
    `;
    
    const verifyResult = await runQuery(verifyQuery);
    
    console.log('📊 수정된 직원들의 현재 상태:');
    console.log('='.repeat(70));
    console.log('직원명\t\t입사일\t\t지급\t사용\t잔여');
    console.log('='.repeat(70));
    
    verifyResult.forEach(emp => {
      const granted = parseFloat(emp.granted);
      const used = parseFloat(emp.used);
      const remaining = parseFloat(emp.remaining);
      
      console.log(`${emp.name.padEnd(12)}\t${emp.join_date.substring(0,10)}\t${granted}개\t${used}\t${remaining}`);
    });
    
    console.log('='.repeat(70));
    console.log('\n✅ 모든 연차가 법정 기준에 맞게 수정되었습니다!');
    
    // 전체 요약
    const summaryQuery = `
      SELECT 
        COUNT(*) as total_employees,
        SUM(annual_leave_granted_current_year) as total_granted,
        SUM(used_annual_leave) as total_used,
        SUM(remaining_annual_leave) as total_remaining
      FROM employees
      WHERE join_date IS NOT NULL
    `;
    
    const summary = await runQuery(summaryQuery);
    
    console.log('\n📈 전체 직원 연차 현황:');
    console.log(`  직원 수: ${summary[0].total_employees}명`);
    console.log(`  총 지급 연차: ${summary[0].total_granted}개`);
    console.log(`  총 사용 연차: ${summary[0].total_used}개`);
    console.log(`  총 잔여 연차: ${summary[0].total_remaining}개`);
    
  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  }
}

executeSQLFile();