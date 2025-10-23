#!/usr/bin/env node

/**
 * 전체 직원의 연차 데이터 일관성 검증
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://qvhbigvdfyvhoegkhvef.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkAllEmployees() {
  console.log('📊 전체 직원 연차 데이터 일관성 검증\n');

  try {
    // 모든 직원 조회
    const { data: employees, error: empError } = await supabase
      .from('employees')
      .select(`
        name, 
        email,
        annual_leave_granted_current_year,
        used_annual_leave,
        remaining_annual_leave,
        join_date
      `)
      .not('email', 'is', null)
      .order('name', { ascending: true });

    if (empError) {
      console.error('❌ 직원 데이터 조회 실패:', empError.message);
      return;
    }

    if (!employees || employees.length === 0) {
      console.log('📭 조회된 직원이 없습니다.');
      return;
    }

    console.log(`👥 총 ${employees.length}명의 직원 조회\n`);

    let consistentCount = 0;
    let inconsistentCount = 0;
    const inconsistentEmployees = [];

    employees.forEach((user, index) => {
      const granted = user.annual_leave_granted_current_year || 0;
      const used = user.used_annual_leave || 0;
      const calculated = granted - used;
      const stored = user.remaining_annual_leave || 0;
      const isConsistent = Math.abs(calculated - stored) < 0.001; // 부동소수점 오차 고려

      if (isConsistent) {
        consistentCount++;
      } else {
        inconsistentCount++;
        inconsistentEmployees.push({
          name: user.name,
          email: user.email,
          joinDate: user.join_date,
          granted,
          used,
          calculated,
          stored,
          difference: Math.round((calculated - stored) * 10) / 10
        });
      }

      const status = isConsistent ? '✅' : '❌';
      console.log(`${(index + 1).toString().padStart(2, ' ')}. ${user.name.padEnd(8)} | ` +
                  `지급: ${granted.toString().padStart(4)}일 | ` +
                  `사용: ${used.toString().padStart(5)}일 | ` +
                  `계산: ${calculated.toString().padStart(5)}일 | ` +
                  `저장: ${stored.toString().padStart(5)}일 | ${status}`);
    });

    console.log('\n' + '='.repeat(80));
    console.log(`📈 통계 요약:`);
    console.log(`   전체 직원: ${employees.length}명`);
    console.log(`   일치: ${consistentCount}명 (${Math.round(consistentCount / employees.length * 100)}%)`);
    console.log(`   불일치: ${inconsistentCount}명 (${Math.round(inconsistentCount / employees.length * 100)}%)`);

    if (inconsistentEmployees.length > 0) {
      console.log('\n🔍 데이터 불일치 직원 상세 분석:');
      console.log('='.repeat(60));
      
      inconsistentEmployees.forEach((emp, idx) => {
        console.log(`${idx + 1}. ${emp.name} (${emp.email})`);
        console.log(`   입사일: ${emp.joinDate}`);
        console.log(`   지급연차: ${emp.granted}일`);
        console.log(`   사용연차: ${emp.used}일`);
        console.log(`   계산값: ${emp.calculated}일`);
        console.log(`   저장값: ${emp.stored}일`);
        console.log(`   차이: ${emp.difference > 0 ? '+' : ''}${emp.difference}일\n`);
      });

      console.log('🔬 불일치 패턴 분석:');
      const positiveErrors = inconsistentEmployees.filter(e => e.difference > 0);
      const negativeErrors = inconsistentEmployees.filter(e => e.difference < 0);
      
      console.log(`   계산값 > 저장값: ${positiveErrors.length}명 (연차가 덜 차감됨)`);
      console.log(`   계산값 < 저장값: ${negativeErrors.length}명 (연차가 더 차감됨)`);
      
      // 차이값 분포
      const differences = inconsistentEmployees.map(e => e.difference);
      const avgDiff = differences.reduce((a, b) => a + b, 0) / differences.length;
      console.log(`   평균 차이: ${Math.round(avgDiff * 10) / 10}일`);
      console.log(`   최대 차이: ${Math.max(...differences.map(Math.abs))}일`);
    }

  } catch (error) {
    console.error('❌ 전체 검증 과정에서 오류 발생:', error.message);
  }
}

// 실행
checkAllEmployees();