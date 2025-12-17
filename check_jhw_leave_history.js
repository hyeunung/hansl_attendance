#!/usr/bin/env node

/**
 * 정현웅 직원의 연차 히스토리 추적 (모든 상태 포함)
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkJHWLeaveHistory() {
  console.log('🔍 정현웅 직원 연차 히스토리 추적\n');

  try {
    // 1. 이메일로 검색 (모든 필드 확인)
    console.log('=' .repeat(60));
    console.log('📊 직원 정보 (모든 필드)');
    console.log('=' .repeat(60));
    
    const { data: employeeData, error: empError } = await supabase
      .from('employees')
      .select('*')
      .eq('name', '정현웅')
      .single();

    if (empError) {
      console.error(`❌ 직원 데이터 조회 실패:`, empError.message);
      return;
    }

    console.log(JSON.stringify(employeeData, null, 2));

    // 2. leave 테이블에서 모든 상태의 연차 기록 조회
    console.log('\n' + '=' .repeat(60));
    console.log('📅 모든 연차 기록 (모든 상태 포함)');
    console.log('=' .repeat(60));
    
    const { data: allLeaves, error: leaveError } = await supabase
      .from('leave')
      .select('*')
      .or(`user_email.eq.hyun-woong.jeong@hansl.com,user_email.eq.${employeeData.email}`)
      .order('created_at', { ascending: false });

    if (leaveError) {
      console.error(`❌ 연차 기록 조회 실패:`, leaveError.message);
    } else {
      console.log(`\n총 ${allLeaves?.length || 0}건의 연차 기록\n`);
      
      if (allLeaves && allLeaves.length > 0) {
        allLeaves.forEach((leave, index) => {
          console.log(`\n${index + 1}. ID: ${leave.id}`);
          console.log(JSON.stringify(leave, null, 2));
        });
      } else {
        console.log('연차 기록이 없습니다.');
      }
    }

    // 3. attendance_records 확인
    console.log('\n' + '=' .repeat(60));
    console.log('📅 출근 기록 확인 (최근 10건)');
    console.log('=' .repeat(60));
    
    const { data: attendance, error: attError } = await supabase
      .from('attendance_records')
      .select('*')
      .eq('employee_id', employeeData.id)
      .order('date', { ascending: false })
      .limit(10);

    if (!attError && attendance) {
      console.log(`\n최근 ${attendance.length}건의 출근 기록:`);
      attendance.forEach((record, index) => {
        console.log(`\n${index + 1}. ${record.date} - ${record.status}`);
        if (record.status === 'leave' || record.status === 'business_trip') {
          console.log(`   특이사항: ${record.status}`);
        }
      });
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
    console.error(error);
  }
}

checkJHWLeaveHistory().then(() => {
  console.log('\n✅ 조사 완료\n');
  process.exit(0);
}).catch(error => {
  console.error('❌ 실행 실패:', error);
  process.exit(1);
});
















