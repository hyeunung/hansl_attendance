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

async function fixEmailSpace() {
  try {
    console.log('=== 최창진 이메일 공백 제거 작업 ===\n');

    // 1. 문제 있는 레코드 확인
    const checkQuery = `
      SELECT id, user_email, name, type, start_date, end_date
      FROM leave
      WHERE user_email LIKE '%chang-jin.choi%@hansl.com'
      ORDER BY created_at DESC
    `;

    const problemRecords = await runQuery(checkQuery);
    
    console.log(`공백이 있는 레코드: ${problemRecords.length}개\n`);
    
    if (problemRecords.length > 0) {
      console.log('수정할 레코드:');
      problemRecords.forEach((record, idx) => {
        console.log(`${idx + 1}. [ID: ${record.id}] ${record.name}`);
        console.log(`   현재 이메일: "${record.user_email}"`);
        console.log(`   ${record.type} | ${record.start_date} ~ ${record.end_date}`);
      });
      
      // 2. 이메일 수정
      console.log('\n이메일 수정 중...');
      
      const updateQuery = `
        UPDATE leave
        SET user_email = 'chang-jin.choi@hansl.com'
        WHERE user_email LIKE '%chang-jin.choi%@hansl.com'
        RETURNING id, user_email, name
      `;
      
      const updatedRecords = await runQuery(updateQuery);
      
      console.log(`\n✅ ${updatedRecords.length}개 레코드의 이메일 수정 완료!\n`);
      
      updatedRecords.forEach(record => {
        console.log(`- ${record.name}: ${record.user_email}`);
      });
      
      // 3. 수정 후 확인
      const verifyQuery = `
        SELECT COUNT(*) as count
        FROM leave
        WHERE user_email = 'chang-jin.choi@hansl.com'
      `;
      
      const verifyResult = await runQuery(verifyQuery);
      console.log(`\n최창진(chang-jin.choi@hansl.com) 총 레코드: ${verifyResult[0].count}개`);
      
    } else {
      console.log('수정할 레코드가 없습니다.');
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

fixEmailSpace();