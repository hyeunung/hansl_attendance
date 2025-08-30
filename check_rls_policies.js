const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// SERVICE KEY를 사용해야 RLS 정책 확인 가능
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function checkPolicies() {
  try {
    // RLS 정책 확인 쿼리
    const { data: policies, error } = await supabase
      .rpc('get_policies_for_table', { schema_name: 'public', table_name: 'leave' });

    if (error) {
      // RPC가 없을 수 있으므로 직접 쿼리
      const { data, error: queryError } = await supabase
        .from('pg_policies')
        .select('*')
        .eq('tablename', 'leave')
        .eq('schemaname', 'public');
      
      if (queryError) {
        console.log('정책 조회 실패, 직접 SQL 실행');
        
        // 직접 SQL로 정책 확인
        const { data: sqlData, error: sqlError } = await supabase.rpc('run_sql', {
          query: `
            SELECT 
              polname as policy_name,
              polcmd as command,
              polroles::text as roles,
              polqual::text as using_expression,
              polwithcheck::text as with_check
            FROM pg_policy 
            WHERE polrelid = 'public.leave'::regclass
          `
        });
        
        if (sqlError) {
          console.log('SQL 쿼리도 실패, pg_stat_user_tables 사용');
          // 다른 방법으로 확인
          const { data: tables } = await supabase
            .from('information_schema.tables')
            .select('*')
            .eq('table_schema', 'public')
            .eq('table_name', 'leave');
          
          console.log('leave 테이블 존재 여부:', tables?.length > 0);
        } else {
          console.log('leave 테이블 RLS 정책:', sqlData);
        }
      } else {
        console.log('pg_policies 조회 결과:', data);
      }
    } else {
      console.log('RLS 정책:', policies);
    }
    
    // 현재 RLS 활성화 상태 확인
    console.log('\n=== RLS 활성화 상태 확인 ===');
    const { data: rlsStatus } = await supabase
      .from('information_schema.tables')
      .select('*')
      .eq('table_schema', 'public')
      .eq('table_name', 'leave')
      .single();
    
    console.log('leave 테이블 정보:', rlsStatus);
    
  } catch (error) {
    console.error('오류:', error);
  }
}

checkPolicies();
