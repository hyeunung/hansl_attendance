const { createClient } = require('@supabase/supabase-js');

// Supabase 연결 설정
const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.BrNMjHpH8HQoZ9rSgCWDczL5HHJR5o7h3cGzKG02qnI';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function normalizeEmails() {
  console.log('🔄 이메일 정규화 시작...\n');
  
  try {
    // 1. 현재 상태 확인
    console.log('📊 현재 매칭 상태 확인...');
    const { data: beforeStatus, error: beforeError } = await supabase.rpc('get_email_matching_status');
    if (beforeError) {
      console.log('RPC 함수가 없으므로 직접 쿼리 실행...\n');
    }
    
    // 2. employees 테이블에서 모든 @hansl.com 이메일 가져오기
    const { data: allEmployees, error: checkError } = await supabase
      .from('employees')
      .select('id, email')
      .like('email', '%@hansl.com');
    
    // 정규화가 필요한 이메일 필터링
    const needsNormalization = allEmployees?.filter(emp => 
      emp.email !== emp.email.toLowerCase().trim()
    ) || [];
    
    if (checkError) {
      console.error('❌ 확인 중 오류:', checkError);
      return;
    }
    
    console.log(`📝 정규화가 필요한 이메일: ${needsNormalization?.length || 0}개`);
    
    if (needsNormalization && needsNormalization.length > 0) {
      console.log('\n정규화할 이메일 목록:');
      needsNormalization.forEach(emp => {
        console.log(`  - ${emp.email} → ${emp.email.toLowerCase().trim()}`);
      });
      
      // 3. 각 이메일 정규화
      console.log('\n✨ 이메일 정규화 진행중...');
      for (const emp of needsNormalization) {
        const normalizedEmail = emp.email.toLowerCase().trim();
        const { error: updateError } = await supabase
          .from('employees')
          .update({ email: normalizedEmail })
          .eq('id', emp.id);
        
        if (updateError) {
          console.error(`❌ ${emp.email} 업데이트 실패:`, updateError);
        } else {
          console.log(`✅ ${emp.email} → ${normalizedEmail}`);
        }
      }
    }
    
    // 4. auth.users와 employees 매칭 상태 확인
    console.log('\n📊 최종 매칭 상태 확인...');
    
    // auth.users 전체 개수
    const { count: authCount } = await supabase
      .from('auth.users')
      .select('*', { count: 'exact', head: true })
      .like('email', '%@hansl.com');
    
    // employees 전체 개수
    const { count: empCount } = await supabase
      .from('employees')
      .select('*', { count: 'exact', head: true })
      .like('email', '%@hansl.com');
    
    console.log(`\n📈 결과:`);
    console.log(`  - auth.users (@hansl.com): ${authCount}명`);
    console.log(`  - employees (@hansl.com): ${empCount}명`);
    console.log(`  - 정규화된 이메일: ${needsNormalization?.length || 0}개`);
    
    // 5. 매칭 안 되는 사용자 확인
    const { data: authUsers } = await supabase
      .from('auth.users')
      .select('email, created_at')
      .like('email', '%@hansl.com');
    
    const { data: employees } = await supabase
      .from('employees')
      .select('email');
    
    const employeeEmails = new Set(employees?.map(e => e.email.toLowerCase()) || []);
    const unmatchedUsers = authUsers?.filter(u => !employeeEmails.has(u.email.toLowerCase())) || [];
    
    if (unmatchedUsers.length > 0) {
      console.log('\n⚠️ employees 테이블에 없는 auth.users:');
      unmatchedUsers.forEach(u => {
        console.log(`  - ${u.email} (가입일: ${new Date(u.created_at).toLocaleDateString()})`);
      });
    } else {
      console.log('\n✅ 모든 auth.users가 employees 테이블과 매칭됩니다!');
    }
    
    console.log('\n✨ 이메일 정규화 완료!');
    
  } catch (error) {
    console.error('❌ 오류 발생:', error);
  }
}

// 실행
normalizeEmails();