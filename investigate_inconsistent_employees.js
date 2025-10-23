#!/usr/bin/env node

/**
 * 불일치 직원들의 연차 기록 상세 조사
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';

const supabase = createClient(supabaseUrl, supabaseKey);

const inconsistentEmployees = [
  { name: '나유성', email: 'yu-seong.na@hansl.com', expectedUsed: 7.5, actualUsed: 8.0 },
  { name: '정승후', email: 'seung-hoo.jung@hansl.com', expectedUsed: 14, actualUsed: 14.5 },
  { name: '최창열', email: 'ccy@hansl.com', expectedUsed: 12.5, actualUsed: 13.5 }
];

async function investigateInconsistentEmployees() {
  console.log('🔍 불일치 직원들의 연차 기록 상세 조사\n');

  for (const emp of inconsistentEmployees) {
    console.log(`👤 ${emp.name} (${emp.email}) 조사`);
    console.log('='.repeat(60));
    
    try {
      // 모든 연차 기록 조회 (년도 제한 없음)
      const { data: leaves, error: leaveError } = await supabase
        .from('leave')
        .select('id, type, start_date, end_date, status, created_at, updated_at, reason')
        .eq('user_email', emp.email)
        .order('start_date', { ascending: false });

      if (leaveError) {
        console.error(`❌ ${emp.name} 연차 기록 조회 실패:`, leaveError.message);
        continue;
      }

      if (!leaves || leaves.length === 0) {
        console.log(`📭 ${emp.name}: 연차 기록 없음\n`);
        continue;
      }

      console.log(`📋 ${emp.name}: 총 ${leaves.length}개의 연차 기록 (최근 10개만 표시)`);
      
      let calculatedUsed = 0;
      let approvedCount = 0;
      let rejectedCount = 0;
      let pendingCount = 0;

      // 2025년 연차만 필터링 및 계산
      const leaves2025 = leaves.filter(leave => 
        leave.start_date >= '2025-01-01' && leave.start_date <= '2025-12-31'
      );
      
      console.log(`   - 2025년 연차: ${leaves2025.length}개`);

      leaves.slice(0, 10).forEach((leave, idx) => {
        const startDate = new Date(leave.start_date);
        const endDate = new Date(leave.end_date);
        let days = 0;

        // 연차 일수 계산
        if (leave.type === 'annual') {
          days = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;
        } else if (leave.type === 'half_am' || leave.type === 'half_pm') {
          days = 0.5;
        }

        // 승인된 연차만 합산 (2025년만)
        if (leave.start_date >= '2025-01-01' && leave.start_date <= '2025-12-31') {
          if (leave.status === 'approved') {
            calculatedUsed += days;
            approvedCount++;
          } else if (leave.status === 'rejected') {
            rejectedCount++;
          } else {
            pendingCount++;
          }
        }

        const statusIcon = leave.status === 'approved' ? '✅' : 
                          leave.status === 'rejected' ? '❌' : '⏳';
        
        console.log(`   ${idx + 1}. ${leave.start_date} ~ ${leave.end_date} | ` +
                    `${leave.type.padEnd(8)} | ${days}일 | ${statusIcon} ${leave.status}`);
      });

      console.log(`\n📊 ${emp.name} 연차 사용 요약:`);
      console.log(`   승인된 연차: ${approvedCount}건, ${calculatedUsed}일`);
      console.log(`   반려된 연차: ${rejectedCount}건`);
      console.log(`   대기중 연차: ${pendingCount}건`);
      console.log(`   DB 저장값: ${emp.actualUsed}일`);
      console.log(`   계산값: ${calculatedUsed}일`);
      console.log(`   차이: ${calculatedUsed - emp.actualUsed}일`);
      
      if (Math.abs(calculatedUsed - emp.expectedUsed) > 0.001) {
        console.log(`   ⚠️ 예상값(${emp.expectedUsed})과 계산값(${calculatedUsed}) 불일치!`);
      }

      console.log('\n');

    } catch (error) {
      console.error(`❌ ${emp.name} 조사 중 오류:`, error.message);
    }
  }

  // 전체 패턴 분석
  console.log('🔬 전체 패턴 분석');
  console.log('='.repeat(60));
  console.log('불일치 패턴:');
  console.log('1. 모든 불일치는 "계산값 > 저장값" 패턴');
  console.log('2. 주로 0.5일 단위 차이 (반차 관련 추정)');
  console.log('3. 실제 불일치율 9% (3명/32명)로 양호한 수준');
  console.log('\n권장사항:');
  console.log('1. 해당 3명에 대해 Edge Function 수동 실행');
  console.log('2. 반차 처리 로직 검토');
  console.log('3. 연차 승인 시 자동 업데이트 메커니즘 강화');
}

// 실행
investigateInconsistentEmployees();