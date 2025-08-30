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

async function deleteOldDomainRecords() {
  try {
    console.log('=== hansl.co.kr 도메인 레코드 삭제 작업 ===\n');

    // 1. 먼저 삭제할 레코드 확인
    const checkQuery = `
      SELECT 
        id,
        user_email,
        name,
        type,
        start_date,
        end_date,
        status
      FROM leave
      WHERE user_email LIKE '%@hansl.co.kr'
      ORDER BY created_at DESC
    `;

    const recordsToDelete = await runQuery(checkQuery);
    
    console.log(`삭제 예정 레코드: ${recordsToDelete.length}개\n`);
    
    if (recordsToDelete.length > 0) {
      console.log('삭제될 레코드 목록:');
      console.log('─'.repeat(80));
      recordsToDelete.forEach((record, idx) => {
        console.log(`${idx + 1}. [ID: ${record.id}] ${record.name} (${record.user_email})`);
        console.log(`   ${record.type} | ${record.start_date} ~ ${record.end_date} | ${record.status}`);
      });
      
      // 2. 삭제 실행
      console.log('\n삭제 중...');
      
      const deleteQuery = `
        DELETE FROM leave
        WHERE user_email LIKE '%@hansl.co.kr'
        RETURNING id, user_email, name
      `;
      
      const deletedRecords = await runQuery(deleteQuery);
      
      console.log(`\n✅ ${deletedRecords.length}개 레코드 삭제 완료!\n`);
      
      // 3. 삭제 후 확인
      const verifyQuery = `
        SELECT COUNT(*) as remaining_count
        FROM leave
        WHERE user_email LIKE '%@hansl.co.kr'
      `;
      
      const verifyResult = await runQuery(verifyQuery);
      console.log(`남은 hansl.co.kr 레코드: ${verifyResult[0].remaining_count}개`);
      
      // 4. 전체 통계
      const statsQuery = `
        SELECT 
          COUNT(*) as total_records,
          COUNT(DISTINCT user_email) as unique_users
        FROM leave
      `;
      
      const stats = await runQuery(statsQuery);
      console.log(`\n=== 삭제 후 전체 통계 ===`);
      console.log(`총 레코드 수: ${stats[0].total_records}개`);
      console.log(`고유 사용자 수: ${stats[0].unique_users}명`);
      
    } else {
      console.log('삭제할 hansl.co.kr 도메인 레코드가 없습니다.');
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

// 실행
deleteOldDomainRecords();