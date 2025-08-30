const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo';

// Service Role client for direct DB access
const supabase = createClient(supabaseUrl, serviceKey);

async function testLeaveUpdate() {
  console.log('🔍 Pending 상태의 leave 레코드 조회...');
  
  // 1. Pending 상태의 leave 조회
  const { data: pendingLeaves, error: fetchError } = await supabase
    .from('leave')
    .select('*')
    .eq('status', 'pending')
    .limit(1);
    
  if (fetchError) {
    console.error('❌ Leave 조회 실패:', fetchError);
    return;
  }
  
  if (!pendingLeaves || pendingLeaves.length === 0) {
    console.log('⚠️ Pending 상태의 leave가 없습니다.');
    
    // 모든 leave 상태 확인
    const { data: allLeaves } = await supabase
      .from('leave')
      .select('id, user_email, name, type, status')
      .limit(5);
    
    console.log('📋 최근 leave 레코드들:');
    console.table(allLeaves);
    return;
  }
  
  const testLeave = pendingLeaves[0];
  console.log('✅ 테스트할 leave 찾음:');
  console.log('  - ID:', testLeave.id);
  console.log('  - 신청자:', testLeave.name, '(', testLeave.user_email, ')');
  console.log('  - 타입:', testLeave.type);
  console.log('  - 현재 상태:', testLeave.status);
  
  // 2. Service Role로 직접 업데이트 테스트
  console.log('\n🔧 Service Role로 직접 DB 업데이트 시도...');
  
  const { data: updateResult, error: updateError } = await supabase
    .from('leave')
    .update({
      status: 'approved',
      updated_at: new Date().toISOString(),
      middle_manager_approval: true,
      final_approval: true,
      middle_manager_email: 'test@hansl.com',
      final_approver_email: 'test@hansl.com'
    })
    .eq('id', testLeave.id)
    .select();
    
  if (updateError) {
    console.error('❌ DB 업데이트 실패:', updateError);
    return;
  }
  
  console.log('✅ DB 업데이트 성공!');
  console.log('업데이트된 레코드:', updateResult);
  
  // 3. 원래 상태로 복구
  console.log('\n🔄 원래 상태(pending)로 복구...');
  
  const { data: restoreResult, error: restoreError } = await supabase
    .from('leave')
    .update({
      status: 'pending',
      updated_at: new Date().toISOString(),
      middle_manager_approval: false,
      final_approval: false,
      middle_manager_email: null,
      final_approver_email: null
    })
    .eq('id', testLeave.id)
    .select();
    
  if (restoreError) {
    console.error('❌ 복구 실패:', restoreError);
  } else {
    console.log('✅ 원래 상태로 복구 완료');
  }
}

testLeaveUpdate();