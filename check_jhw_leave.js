#!/usr/bin/env node

/**
 * 정현웅 직원의 연차 데이터 상세 조사
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkJHWLeave() {
  console.log('🔍 정현웅 직원 연차 데이터 상세 조사\n');

  try {
    // 1. 현재 employees 테이블 데이터
    console.log('=' .repeat(60));
    console.log('📊 현재 DB 저장 데이터');
    console.log('=' .repeat(60));
    
    const { data: employeeData, error: empError } = await supabase
      .from('employees')
      .select(`
        name, 
        email,
        annual_leave_granted_current_year,
        used_annual_leave,
        remaining_annual_leave,
        join_date
      `)
      .eq('email', 'hyun-woong.jeong@hansl.com')
      .single();

    if (empError) {
      console.error(`❌ 직원 데이터 조회 실패:`, empError.message);
      return;
    }

    console.log(`   이름: ${employeeData.name}`);
    console.log(`   이메일: ${employeeData.email}`);
    console.log(`   입사일: ${employeeData.join_date}`);
    console.log(`   지급연차: ${employeeData.annual_leave_granted_current_year}일`);
    console.log(`   사용연차: ${employeeData.used_annual_leave}일`);
    console.log(`   남은연차: ${employeeData.remaining_annual_leave}일`);

    // 2. 2025년 연차 기록 조회
    console.log('\n' + '=' .repeat(60));
    console.log('📅 2025년 연차 신청 기록');
    console.log('=' .repeat(60));
    
    const { data: leaves2025, error: leave2025Error } = await supabase
      .from('leave')
      .select('id, type, start_date, end_date, status, created_at, reason')
      .eq('user_email', 'hyun-woong.jeong@hansl.com')
      .gte('start_date', '2025-01-01')
      .lte('start_date', '2025-12-31')
      .order('start_date', { ascending: true });

    if (leave2025Error) {
      console.error(`❌ 2025년 연차 기록 조회 실패:`, leave2025Error.message);
      return;
    }

    console.log(`\n총 ${leaves2025?.length || 0}건의 신청 기록:\n`);
    
    let calculated2025 = 0;
    let approvedCount = 0;
    let rejectedCount = 0;
    let pendingCount = 0;

    if (leaves2025 && leaves2025.length > 0) {
      leaves2025.forEach((leave, index) => {
        const startDate = new Date(leave.start_date);
        const endDate = new Date(leave.end_date);
        const daysDiff = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;

        let daysUsed = 0;
        if (leave.type === 'annual') {
          daysUsed = daysDiff;
        } else if (leave.type === 'half_am' || leave.type === 'half_pm') {
          daysUsed = 0.5;
        }

        if (leave.status === 'approved') {
          calculated2025 += daysUsed;
          approvedCount++;
        } else if (leave.status === 'rejected') {
          rejectedCount++;
        } else if (leave.status === 'pending') {
          pendingCount++;
        }

        const statusIcon = leave.status === 'approved' ? '✅' : 
                          leave.status === 'rejected' ? '❌' : 
                          leave.status === 'pending' ? '⏳' : '❓';

        console.log(`   ${index + 1}. ${statusIcon} ${leave.start_date} ~ ${leave.end_date}`);
        console.log(`      유형: ${leave.type}`);
        console.log(`      상태: ${leave.status}`);
        console.log(`      사용일수: ${daysUsed}일`);
        console.log(`      신청일: ${leave.created_at}`);
        if (leave.reason) {
          console.log(`      사유: ${leave.reason}`);
        }
        console.log('');
      });

      console.log('=' .repeat(60));
      console.log('📊 통계');
      console.log('=' .repeat(60));
      console.log(`   승인: ${approvedCount}건`);
      console.log(`   반려: ${rejectedCount}건`);
      console.log(`   대기: ${pendingCount}건`);
      console.log(`   계산된 사용연차: ${calculated2025}일 (승인된 것만)`);
      console.log(`   DB 저장된 사용연차: ${employeeData.used_annual_leave}일`);
      
      const difference = Math.abs(calculated2025 - employeeData.used_annual_leave);
      if (difference > 0.01) {
        console.log(`\n   ⚠️  불일치 발견! 차이: ${difference}일`);
      } else {
        console.log(`\n   ✅ 데이터 일관성 확인`);
      }

      // 잔여연차 검증
      const expectedRemaining = employeeData.annual_leave_granted_current_year - calculated2025;
      console.log(`\n   예상 남은연차: ${expectedRemaining}일`);
      console.log(`   실제 남은연차: ${employeeData.remaining_annual_leave}일`);
      
      if (Math.abs(expectedRemaining - employeeData.remaining_annual_leave) > 0.01) {
        console.log(`   ⚠️  남은연차 불일치! 차이: ${Math.abs(expectedRemaining - employeeData.remaining_annual_leave)}일`);
      }
    } else {
      console.log('   연차 신청 기록이 없습니다.');
    }

    // 3. 전체 연차 기록 조회 (2025년 이외)
    console.log('\n' + '=' .repeat(60));
    console.log('📅 전체 연차 신청 기록');
    console.log('=' .repeat(60));
    
    const { data: allLeaves, error: allError } = await supabase
      .from('leave')
      .select('id, type, start_date, end_date, status')
      .eq('user_email', 'hyun-woong.jeong@hansl.com')
      .order('start_date', { ascending: false });

    if (!allError && allLeaves) {
      console.log(`\n총 ${allLeaves.length}건의 전체 신청 기록\n`);
      
      // 연도별로 그룹화
      const byYear = {};
      allLeaves.forEach(leave => {
        const year = leave.start_date.substring(0, 4);
        if (!byYear[year]) {
          byYear[year] = [];
        }
        byYear[year].push(leave);
      });

      Object.keys(byYear).sort().reverse().forEach(year => {
        console.log(`   ${year}년: ${byYear[year].length}건`);
      });
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  }
}

checkJHWLeave().then(() => {
  console.log('\n✅ 조사 완료\n');
  process.exit(0);
}).catch(error => {
  console.error('❌ 실행 실패:', error);
  process.exit(1);
});























