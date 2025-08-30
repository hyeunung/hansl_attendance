const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  'https://qvhbigvdfyvhoegkhvef.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo'  // Service role key로 RLS 우회
);

async function insertTestLeaves() {
  try {
    // 오늘 날짜 기준
    const today = new Date();
    const currentMonth = today.getMonth();
    const currentYear = today.getFullYear();
    
    // 테스트용 leave 데이터
    const testLeaves = [
      {
        user_email: 'test@hansl.com',
        name: '테스트',
        type: 'annual',
        start_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-15`,
        end_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-16`,
        reason: '개인 사유',
        status: 'approved',
        created_at: new Date().toISOString()
      },
      {
        user_email: 'hyun-woong.jeong@hansl.com',
        name: '정현웅',
        type: 'annual',
        start_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-20`,
        end_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-22`,
        reason: '가족 행사',
        status: 'approved',
        created_at: new Date().toISOString()
      },
      {
        user_email: 'test@hansl.com',
        name: '테스트',
        type: 'biztrip',
        start_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-25`,
        end_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-26`,
        reason: '장소: 서울\n목적: 미팅\n교통수단: KTX',
        status: 'approved',
        created_at: new Date().toISOString()
      },
      {
        user_email: 'test2@hansl.com',
        name: '김철수',
        type: 'half_am',
        start_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-10`,
        end_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-10`,
        reason: '병원',
        status: 'approved',
        created_at: new Date().toISOString()
      },
      {
        user_email: 'test3@hansl.com',
        name: '이영희',
        type: 'half_pm',
        start_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-12`,
        end_date: `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-12`,
        reason: '개인 사유',
        status: 'approved',
        created_at: new Date().toISOString()
      }
    ];
    
    // 데이터 삽입
    const { data, error } = await supabase
      .from('leave')
      .insert(testLeaves);
    
    if (error) {
      console.error('삽입 오류:', error);
      return;
    }
    
    console.log(`✅ ${testLeaves.length}개의 테스트 leave 데이터 삽입 완료!`);
    
    // 삽입 확인
    const { data: checkData, error: checkError } = await supabase
      .from('leave')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (!checkError) {
      console.log(`\n현재 leave 테이블 데이터 수: ${checkData.length}개`);
      console.log('\n최근 삽입된 데이터:');
      checkData.slice(0, 5).forEach(leave => {
        console.log(`- ${leave.name} (${leave.user_email}): ${leave.type} | ${leave.start_date} ~ ${leave.end_date} | 상태: ${leave.status}`);
      });
    }
    
  } catch (error) {
    console.error('오류 발생:', error);
  }
}

insertTestLeaves();