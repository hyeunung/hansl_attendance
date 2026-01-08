#!/usr/bin/env node

/**
 * 정현웅 직원의 연차 데이터 수정 스크립트
 * CSV 파일 기준으로 올바른 값으로 수정
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function fixJHWLeave() {
  console.log('🔧 정현웅 직원 연차 데이터 수정\n');

  try {
    // 현재 상태 확인
    const { data: beforeData, error: beforeError } = await supabase
      .from('employees')
      .select('name, annual_leave_granted_current_year, used_annual_leave, remaining_annual_leave')
      .eq('email', 'hyun-woong.jeong@hansl.com')
      .single();

    if (beforeError) {
      console.error('❌ 직원 데이터 조회 실패:', beforeError.message);
      return;
    }

    console.log('📊 수정 전:');
    console.log(`   지급연차: ${beforeData.annual_leave_granted_current_year}일`);
    console.log(`   사용연차: ${beforeData.used_annual_leave}일`);
    console.log(`   남은연차: ${beforeData.remaining_annual_leave}일`);

    // CSV 기준으로 수정
    // CSV: 1월 3일, 9일(오전반차) = 1 + 0.5 = 1.5일
    // 그런데 CSV에는 2.0일로 되어 있음 (아마 9일을 전일로 계산한 듯)
    
    const correctUsed = 2.0; // CSV 기준
    const correctRemaining = beforeData.annual_leave_granted_current_year - correctUsed;

    console.log('\n📝 수정할 값:');
    console.log(`   사용연차: ${beforeData.used_annual_leave}일 → ${correctUsed}일`);
    console.log(`   남은연차: ${beforeData.remaining_annual_leave}일 → ${correctRemaining}일`);

    // 사용자 확인
    console.log('\n⚠️  위 값으로 수정하시겠습니까?');
    console.log('실행하려면 주석을 해제하세요.\n');

    // 실제 업데이트 (주석 처리됨)
    /*
    const { data: updateData, error: updateError } = await supabase
      .from('employees')
      .update({
        used_annual_leave: correctUsed,
        remaining_annual_leave: correctRemaining
      })
      .eq('email', 'hyun-woong.jeong@hansl.com')
      .select();

    if (updateError) {
      console.error('❌ 업데이트 실패:', updateError.message);
      return;
    }

    console.log('✅ 업데이트 성공!');
    console.log('\n📊 수정 후:');
    console.log(`   지급연차: ${updateData[0].annual_leave_granted_current_year}일`);
    console.log(`   사용연차: ${updateData[0].used_annual_leave}일`);
    console.log(`   남은연차: ${updateData[0].remaining_annual_leave}일`);
    */

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  }
}

fixJHWLeave().then(() => {
  console.log('\n✅ 스크립트 완료\n');
  process.exit(0);
}).catch(error => {
  console.error('❌ 실행 실패:', error);
  process.exit(1);
});























