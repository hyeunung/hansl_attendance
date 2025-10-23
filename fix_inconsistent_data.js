#!/usr/bin/env node

/**
 * 불일치 직원들의 연차 데이터 수정
 * Edge Function을 호출하여 정확한 값으로 업데이트
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';

const supabase = createClient(supabaseUrl, supabaseKey);

const inconsistentEmployees = [
  { name: '나유성', email: 'yu-seong.na@hansl.com' },
  { name: '정승후', email: 'seung-hoo.jung@hansl.com' },
  { name: '최창열', email: 'ccy@hansl.com' }
];

async function fixInconsistentData() {
  console.log('🔧 불일치 직원들의 연차 데이터 수정 시작\n');

  for (const emp of inconsistentEmployees) {
    console.log(`🛠️  ${emp.name} (${emp.email}) 데이터 수정`);
    console.log('='.repeat(50));
    
    try {
      // 수정 전 상태 확인
      const { data: beforeData, error: beforeError } = await supabase
        .from('employees')
        .select('used_annual_leave, remaining_annual_leave, annual_leave_granted_current_year')
        .eq('email', emp.email)
        .single();

      if (beforeError) {
        console.error(`❌ ${emp.name} 수정 전 데이터 조회 실패:`, beforeError.message);
        continue;
      }

      console.log(`📋 수정 전:`);
      console.log(`   지급연차: ${beforeData.annual_leave_granted_current_year}일`);
      console.log(`   사용연차: ${beforeData.used_annual_leave}일`);
      console.log(`   남은연차: ${beforeData.remaining_annual_leave}일`);

      // 2025년 실제 연차 기록 확인
      const { data: actualLeaves, error: leaveError } = await supabase
        .from('leave')
        .select('type, start_date, end_date, status')
        .eq('user_email', emp.email)
        .eq('status', 'approved')
        .gte('start_date', '2025-01-01')
        .lte('start_date', '2025-12-31');

      if (leaveError) {
        console.error(`❌ ${emp.name} 연차 기록 조회 실패:`, leaveError.message);
        continue;
      }

      let actualUsed = 0;
      if (actualLeaves && actualLeaves.length > 0) {
        actualLeaves.forEach(leave => {
          if (leave.type === 'annual') {
            const startDate = new Date(leave.start_date);
            const endDate = new Date(leave.end_date);
            const days = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;
            actualUsed += days;
          } else if (leave.type === 'half_am' || leave.type === 'half_pm') {
            actualUsed += 0.5;
          }
        });
      }

      console.log(`📊 실제 승인된 연차: ${actualUsed}일`);

      // 직접 DB 업데이트 (Edge Function 대신)
      const newRemaining = Math.max(0, beforeData.annual_leave_granted_current_year - actualUsed);
      
      const { error: updateError } = await supabase
        .from('employees')
        .update({
          used_annual_leave: actualUsed,
          remaining_annual_leave: newRemaining
        })
        .eq('email', emp.email);

      if (updateError) {
        console.error(`❌ ${emp.name} 데이터 업데이트 실패:`, updateError.message);
        continue;
      }

      console.log(`✅ ${emp.name} 데이터 수정 완료:`);
      console.log(`   사용연차: ${beforeData.used_annual_leave} → ${actualUsed}일`);
      console.log(`   남은연차: ${beforeData.remaining_annual_leave} → ${newRemaining}일`);
      console.log(`   차이: ${beforeData.used_annual_leave - actualUsed}일 감소\n`);

    } catch (error) {
      console.error(`❌ ${emp.name} 수정 중 오류:`, error.message);
    }
  }

  console.log('🎉 모든 불일치 데이터 수정 완료!');
  console.log('\n📋 수정 후 확인:');
  console.log('1. 앱에서 연차 정보 새로고침');
  console.log('2. 각 직원의 연차 잔여일수 확인');
  console.log('3. 데이터 일관성 재검증');
}

// 실행
fixInconsistentData();