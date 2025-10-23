#!/usr/bin/env node

/**
 * 이정화, 임소연 직원의 연차 데이터 상세 조사
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';

const supabase = createClient(supabaseUrl, supabaseKey);

const targetEmployees = [
  { name: '이정화', email: 'ljh@hansl.com' },
  { name: '임소연', email: 'lsy@hansl.com' }
];

async function checkSpecificEmployees() {
  console.log('🔍 이정화, 임소연 직원 연차 데이터 상세 조사\n');

  for (const emp of targetEmployees) {
    console.log(`👤 ${emp.name} (${emp.email}) 상세 조사`);
    console.log('='.repeat(60));
    
    try {
      // 1. 현재 employees 테이블 데이터
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
        .eq('email', emp.email)
        .single();

      if (empError) {
        console.error(`❌ ${emp.name} 직원 데이터 조회 실패:`, empError.message);
        continue;
      }

      console.log(`📊 현재 DB 저장 데이터:`);
      console.log(`   지급연차: ${employeeData.annual_leave_granted_current_year}일`);
      console.log(`   사용연차: ${employeeData.used_annual_leave}일`);
      console.log(`   남은연차: ${employeeData.remaining_annual_leave}일`);
      console.log(`   입사일: ${employeeData.join_date}`);

      // 2. 2025년 연차 기록 조회
      const { data: leaves2025, error: leave2025Error } = await supabase
        .from('leave')
        .select('id, type, start_date, end_date, status, created_at, reason')
        .eq('user_email', emp.email)
        .gte('start_date', '2025-01-01')
        .lte('start_date', '2025-12-31')
        .order('start_date', { ascending: true });

      if (leave2025Error) {
        console.error(`❌ ${emp.name} 2025년 연차 기록 조회 실패:`, leave2025Error.message);
        continue;
      }

      console.log(`\n📅 2025년 연차 신청 기록 (${leaves2025?.length || 0}건):`);
      
      let calculated2025 = 0;
      let approvedCount = 0;
      let rejectedCount = 0;
      let pendingCount = 0;

      if (leaves2025 && leaves2025.length > 0) {
        leaves2025.forEach((leave, idx) => {
          const startDate = new Date(leave.start_date);
          const endDate = new Date(leave.end_date);
          let days = 0;

          if (leave.type === 'annual') {
            days = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;
          } else if (leave.type === 'half_am' || leave.type === 'half_pm') {
            days = 0.5;
          }

          if (leave.status === 'approved') {
            calculated2025 += days;
            approvedCount++;
          } else if (leave.status === 'rejected') {
            rejectedCount++;
          } else {
            pendingCount++;
          }

          const statusIcon = leave.status === 'approved' ? '✅' : 
                            leave.status === 'rejected' ? '❌' : '⏳';
          
          console.log(`   ${idx + 1}. ${leave.start_date} ~ ${leave.end_date} | ` +
                      `${leave.type.padEnd(8)} | ${days}일 | ${statusIcon} ${leave.status}`);
        });
      } else {
        console.log(`   (연차 기록 없음)`);
      }

      // 3. 계산 검증
      console.log(`\n🧮 연차 사용량 계산:`);
      console.log(`   승인된 연차: ${approvedCount}건, ${calculated2025}일`);
      console.log(`   반려된 연차: ${rejectedCount}건`);
      console.log(`   대기중 연차: ${pendingCount}건`);
      console.log(`   DB 저장값: ${employeeData.used_annual_leave}일`);
      console.log(`   실제 계산값: ${calculated2025}일`);
      
      const difference = employeeData.used_annual_leave - calculated2025;
      const isConsistent = Math.abs(difference) < 0.001;
      
      console.log(`   차이: ${difference}일`);
      console.log(`   일치 여부: ${isConsistent ? '✅ 일치' : '❌ 불일치'}`);

      // 4. 남은 연차 계산
      const expectedRemaining = employeeData.annual_leave_granted_current_year - calculated2025;
      const actualRemaining = employeeData.remaining_annual_leave;
      const remainingDiff = actualRemaining - expectedRemaining;
      
      console.log(`\n💰 남은 연차 검증:`);
      console.log(`   지급연차: ${employeeData.annual_leave_granted_current_year}일`);
      console.log(`   사용연차(계산): ${calculated2025}일`);
      console.log(`   예상 잔여: ${expectedRemaining}일`);
      console.log(`   실제 잔여: ${actualRemaining}일`);
      console.log(`   잔여 차이: ${remainingDiff}일`);
      
      if (!isConsistent) {
        console.log(`\n🚨 ${emp.name} 데이터 불일치 발견!`);
        console.log(`   문제: 실제 승인된 연차(${calculated2025}일)와 저장된 사용연차(${employeeData.used_annual_leave}일)가 다름`);
        console.log(`   영향: 남은 연차가 ${difference}일 적게 표시됨`);
      }

      console.log('\n');

    } catch (error) {
      console.error(`❌ ${emp.name} 조사 중 오류:`, error.message);
    }
  }
}

// 실행
checkSpecificEmployees();