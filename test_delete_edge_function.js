const { createClient } = require('@supabase/supabase-js');

// Supabase 설정
const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78';

// Service Role로 생성, Anon으로 삭제 테스트
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function testDeleteFunction() {
  try {
    console.log('🧪 Delete Edge Function 테스트 시작...\n');

    // 1. 먼저 테스트용 leave 생성 (Service Role로)
    console.log('1️⃣ 테스트용 leave 생성 중...');
    const { data: newLeave, error: createError } = await supabaseAdmin
      .from('leave')
      .insert([{
        user_email: 'test@example.com',
        type: 'annual',
        start_date: '2024-12-25',
        end_date: '2024-12-25',
        reason: '테스트 연차',
        status: 'pending',
        created_at: new Date().toISOString()
      }])
      .select()
      .single();

    if (createError) {
      console.error('❌ Leave 생성 실패:', createError);
      return;
    }

    console.log('✅ 테스트 leave 생성 완료:', {
      id: newLeave.id,
      user_email: newLeave.user_email,
      status: newLeave.status
    });

    // 2. Edge Function으로 삭제 테스트
    console.log('\n2️⃣ Edge Function으로 삭제 시도...');
    const { data: deleteResult, error: deleteError } = await supabase.functions.invoke(
      'delete_leave',
      {
        body: {
          leaveId: newLeave.id,
          userEmail: 'test@example.com',
          isAdmin: false
        }
      }
    );

    if (deleteError) {
      console.error('❌ Edge Function 호출 실패:', deleteError);
      
      // 생성한 테스트 데이터 정리
      await supabaseAdmin.from('leave').delete().eq('id', newLeave.id);
      return;
    }

    console.log('✅ Edge Function 응답:', deleteResult);

    // 3. 삭제 확인 (Service Role로)
    console.log('\n3️⃣ 삭제 확인 중...');
    const { data: checkData, error: checkError } = await supabaseAdmin
      .from('leave')
      .select('*')
      .eq('id', newLeave.id);

    if (checkError) {
      console.error('❌ 확인 중 에러:', checkError);
      return;
    }

    if (checkData && checkData.length === 0) {
      console.log('✅ 삭제 성공! DB에서 제거됨');
    } else {
      console.log('❌ 삭제 실패! 아직 DB에 존재함:', checkData);
    }

    // 4. 관리자 권한으로 다른 사용자 데이터 삭제 테스트
    console.log('\n4️⃣ 관리자 권한 테스트...');
    
    // 새로운 leave 생성 (Service Role로)
    const { data: adminTestLeave, error: adminCreateError } = await supabaseAdmin
      .from('leave')
      .insert([{
        user_email: 'other@example.com',
        type: 'biztrip',
        start_date: '2024-12-26',
        end_date: '2024-12-27',
        reason: '관리자 테스트',
        status: 'approved',
        created_at: new Date().toISOString()
      }])
      .select()
      .single();

    if (adminCreateError) {
      console.error('❌ 관리자 테스트 leave 생성 실패:', adminCreateError);
      return;
    }

    console.log('✅ 관리자 테스트 leave 생성:', adminTestLeave.id);

    // 관리자 권한으로 삭제
    const { data: adminDeleteResult } = await supabase.functions.invoke(
      'delete_leave',
      {
        body: {
          leaveId: adminTestLeave.id,
          isAdmin: true
        }
      }
    );

    console.log('✅ 관리자 삭제 응답:', adminDeleteResult);

    // 확인 (Service Role로)
    const { data: adminCheckData } = await supabaseAdmin
      .from('leave')
      .select('*')
      .eq('id', adminTestLeave.id);

    if (adminCheckData && adminCheckData.length === 0) {
      console.log('✅ 관리자 삭제 성공!');
    } else {
      console.log('❌ 관리자 삭제 실패!');
      // 정리
      await supabaseAdmin.from('leave').delete().eq('id', adminTestLeave.id);
    }

    console.log('\n✨ 모든 테스트 완료!');

  } catch (error) {
    console.error('❌ 테스트 중 에러:', error);
  }
}

// 테스트 실행
testDeleteFunction();