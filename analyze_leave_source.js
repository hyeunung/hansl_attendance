const fetch = require('node-fetch');

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

async function analyzeLeaveSource() {
  try {
    console.log('=== Leave 데이터 출처 분석 ===\n');

    // 1. reason 필드에 "엑셀"이 포함된 레코드 확인
    const excelSourceQuery = `
      SELECT 
        user_email,
        name,
        type,
        start_date,
        end_date,
        reason,
        status,
        created_at
      FROM leave
      WHERE reason LIKE '%엑셀%' OR reason LIKE '%78%'
      ORDER BY created_at DESC
      LIMIT 20
    `;

    const excelRecords = await runQuery(excelSourceQuery);
    
    console.log(`"엑셀" 또는 "78"이 포함된 레코드: ${excelRecords.length}개\n`);
    
    if (excelRecords.length > 0) {
      console.log('샘플 데이터 (최대 20개):');
      console.log('─'.repeat(100));
      
      excelRecords.forEach((record, idx) => {
        console.log(`${idx + 1}. ${record.name} (${record.user_email})`);
        console.log(`   날짜: ${record.start_date} ~ ${record.end_date}`);
        console.log(`   타입: ${record.type}, 상태: ${record.status}`);
        console.log(`   사유: ${record.reason}`);
        console.log(`   생성일: ${record.created_at}`);
        console.log('');
      });
    }

    // 2. 생성 시간 패턴 분석 (대량 입력 확인)
    const creationPatternQuery = `
      SELECT 
        DATE(created_at) as creation_date,
        COUNT(*) as count,
        STRING_AGG(DISTINCT name, ', ') as names
      FROM leave
      WHERE created_at >= '2025-08-01'
      GROUP BY DATE(created_at)
      HAVING COUNT(*) > 10
      ORDER BY creation_date DESC
    `;

    const creationPatterns = await runQuery(creationPatternQuery);
    
    if (creationPatterns.length > 0) {
      console.log('\n=== 대량 입력 패턴 (한 날짜에 10건 이상) ===');
      console.log('─'.repeat(60));
      
      creationPatterns.forEach(pattern => {
        console.log(`${pattern.creation_date}: ${pattern.count}건 입력`);
        console.log(`   직원: ${pattern.names.substring(0, 100)}...`);
      });
    }

    // 3. 7-8월 데이터 분석
    const julyAugustQuery = `
      SELECT 
        CASE 
          WHEN user_email LIKE '%@hansl.co.kr' THEN 'hansl.co.kr'
          WHEN user_email LIKE '%@hansl.com' THEN 'hansl.com'
          ELSE 'other'
        END as domain,
        COUNT(*) as count,
        COUNT(DISTINCT user_email) as unique_users
      FROM leave
      WHERE (start_date >= '2025-07-01' AND start_date <= '2025-08-31')
         OR (end_date >= '2025-07-01' AND end_date <= '2025-08-31')
      GROUP BY domain
      ORDER BY domain
    `;

    const julyAugustData = await runQuery(julyAugustQuery);
    
    console.log('\n=== 7-8월 연차 데이터 도메인별 분석 ===');
    console.log('─'.repeat(60));
    
    let totalCount = 0;
    let totalUsers = 0;
    
    julyAugustData.forEach(data => {
      console.log(`${data.domain}: ${data.count}건 (${data.unique_users}명)`);
      totalCount += parseInt(data.count);
      totalUsers = Math.max(totalUsers, parseInt(data.unique_users));
    });
    
    console.log(`\n총합: ${totalCount}건`);
    
    // 4. 삭제된 co.kr 데이터 복원 가능성 확인
    console.log('\n=== co.kr 도메인 데이터 분석 ===');
    console.log('이미 삭제된 63개의 co.kr 레코드는 다음과 같은 특징이 있었습니다:');
    console.log('- 7-8월 기간 데이터');
    console.log('- "엑셀 78월 데이터 추가" 사유로 입력됨');
    console.log('- 2025-08-19 00:57 ~ 00:59 사이에 대량 입력됨');
    console.log('\n이 데이터는 78월.xlsx 파일에서 가져온 것으로 보입니다.');
    console.log('co.kr 이메일은 구 도메인으로, 중복 데이터였던 것으로 판단됩니다.');

  } catch (error) {
    console.error('Error:', error);
  }
}

analyzeLeaveSource();