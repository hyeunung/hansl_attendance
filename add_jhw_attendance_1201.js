#!/usr/bin/env node

/**
 * 정현웅 12/1 출근 처리
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function addAttendance() {
  console.log('🕐 정현웅 12/1 출근 처리\n');

  try {
    const employeeId = 'daa0487b-b7a1-4b8c-ac60-a00caf7f226f';
    const employeeName = '정현웅';
    const employeeEmail = 'hyun-woong.jeong@hansl.com';
    const date = '2025-12-01';
    const checkInTime = '08:25:00'; // 8:25

    console.log('📝 출근 정보:');
    console.log(`   직원: ${employeeName}`);
    console.log(`   날짜: ${date}`);
    console.log(`   출근시간: 08:25`);
    console.log('');

    // 1. 기존 레코드 확인
    const { data: existing, error: checkError } = await supabase
      .from('attendance_records')
      .select('*')
      .eq('employee_id', employeeId)
      .eq('date', date)
      .single();

    if (checkError && checkError.code !== 'PGRST116') {
      console.error('❌ 레코드 확인 실패:', checkError.message);
      return;
    }

    if (existing) {
      console.log('📌 기존 레코드 발견:');
      console.log(`   상태: ${existing.status}`);
      console.log(`   출근시간: ${existing.clock_in || '없음'}`);
      console.log(`   퇴근시간: ${existing.clock_out || '없음'}`);
      console.log('');

      // 업데이트
      const { data: updated, error: updateError } = await supabase
        .from('attendance_records')
        .update({
          status: 'present',
          clock_in: checkInTime,
          employee_name: employeeName,
          user_email: employeeEmail,
          updated_at: new Date().toISOString()
        })
        .eq('employee_id', employeeId)
        .eq('date', date)
        .select();

      if (updateError) {
        console.error('❌ 업데이트 실패:', updateError.message);
        return;
      }

      console.log('✅ 출근 기록 업데이트 완료!');
      console.log(JSON.stringify(updated[0], null, 2));
    } else {
      console.log('📝 새 레코드 생성 중...\n');

      // 삽입
      const { data: inserted, error: insertError } = await supabase
        .from('attendance_records')
        .insert({
          employee_id: employeeId,
          employee_name: employeeName,
          user_email: employeeEmail,
          date: date,
          clock_in: checkInTime,
          status: 'present',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .select();

      if (insertError) {
        console.error('❌ 삽입 실패:', insertError.message);
        return;
      }

      console.log('✅ 출근 기록 생성 완료!');
      console.log(JSON.stringify(inserted[0], null, 2));
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
    console.error(error);
  }
}

addAttendance().then(() => {
  console.log('\n✅ 처리 완료\n');
  process.exit(0);
}).catch(error => {
  console.error('❌ 실행 실패:', error);
  process.exit(1);
});

