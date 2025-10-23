#!/usr/bin/env node

/**
 * 연차 남은 개수 표시 문제 디버깅 스크립트
 * 실제 데이터베이스에서 연차 관련 데이터를 조회하여 문제점을 파악
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function debugAnnualLeave() {
  console.log('🔍 연차 남은 개수 표시 문제 디버깅 시작\n');

  try {
    // 1. employees 테이블 스키마 확인
    console.log('📋 1. employees 테이블 컬럼 구조 확인');
    console.log('=' .repeat(50));
    
    const { data: employees, error: empError } = await supabase
      .from('employees')
      .select('*')
      .limit(1);

    if (empError) {
      console.error('❌ 직원 데이터 조회 실패:', empError.message);
      return;
    }

    if (employees && employees.length > 0) {
      const columns = Object.keys(employees[0]);
      console.log('📊 사용 가능한 컬럼들:');
      columns.forEach(col => {
        if (col.includes('annual') || col.includes('leave') || col.includes('used') || col.includes('remaining')) {
          console.log(`   ✓ ${col}: ${employees[0][col]}`);
        }
      });
    }

    console.log('\n');

    // 2. 특정 사용자의 연차 데이터 상세 조회
    console.log('👤 2. 특정 사용자 연차 데이터 상세 조회');
    console.log('=' .repeat(50));
    
    const { data: userEmployee, error: userError } = await supabase
      .from('employees')
      .select(`
        name, 
        email,
        annual_leave_granted_current_year,
        used_annual_leave,
        remaining_annual_leave,
        join_date
      `)
      .limit(15);  // 더 많은 샘플 조회

    if (userError) {
      console.error('❌ 사용자 연차 데이터 조회 실패:', userError.message);
      return;
    }

    if (userEmployee && userEmployee.length > 0) {
      userEmployee.forEach(user => {
        console.log(`\n📝 ${user.name} (${user.email})`);
        console.log(`   입사일: ${user.join_date}`);
        console.log(`   지급연차(granted_current_year): ${user.annual_leave_granted_current_year}`);
        console.log(`   사용연차: ${user.used_annual_leave}`);
        console.log(`   남은연차: ${user.remaining_annual_leave}`);
        
        // 계산 검증
        const granted = user.annual_leave_granted_current_year || 0;
        const used = user.used_annual_leave || 0;
        const calculated = granted - used;
        const stored = user.remaining_annual_leave || 0;
        
        console.log(`   계산값: ${granted} - ${used} = ${calculated}`);
        console.log(`   저장값: ${stored}`);
        console.log(`   일치여부: ${calculated === stored ? '✅' : '❌'}`);
      });
    }

    console.log('\n');

    // 3. 최근 연차 신청 내역 확인
    console.log('📅 3. 최근 연차 신청 내역 확인');
    console.log('=' .repeat(50));
    
    const { data: recentLeaves, error: leaveError } = await supabase
      .from('leave')
      .select('user_email, name, type, start_date, end_date, status, created_at')
      .eq('type', 'annual')
      .order('created_at', { ascending: false })
      .limit(10);

    if (leaveError) {
      console.error('❌ 연차 신청 내역 조회 실패:', leaveError.message);
      return;
    }

    if (recentLeaves && recentLeaves.length > 0) {
      recentLeaves.forEach(leave => {
        const startDate = new Date(leave.start_date);
        const endDate = new Date(leave.end_date);
        const days = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;
        
        console.log(`\n📋 ${leave.name} - ${leave.status}`);
        console.log(`   기간: ${leave.start_date} ~ ${leave.end_date} (${days}일)`);
        console.log(`   신청일: ${leave.created_at}`);
      });
    }

    console.log('\n');

    // 4. Edge Function 호출 테스트
    console.log('🔧 4. Edge Function 테스트');
    console.log('=' .repeat(50));
    
    // 간단한 테스트 사용자 선택
    if (userEmployee && userEmployee.length > 0) {
      const testUser = userEmployee[0];
      console.log(`🧪 테스트 대상: ${testUser.name} (${testUser.email})`);
      
      try {
        const { data: result, error: funcError } = await supabase.functions.invoke(
          'update_used_annual_leave',
          {
            body: {
              userEmail: testUser.email,
              targetYear: new Date().getFullYear()
            }
          }
        );

        if (funcError) {
          console.error('❌ Edge Function 호출 실패:', funcError.message);
        } else {
          console.log('✅ Edge Function 실행 결과:');
          console.log(JSON.stringify(result, null, 2));
        }
      } catch (error) {
        console.error('❌ Edge Function 호출 중 오류:', error.message);
      }
    }

  } catch (error) {
    console.error('❌ 전체 디버깅 과정에서 오류 발생:', error.message);
  }
}

// 실행
debugAnnualLeave();