const fetch = require('node-fetch');

const ACCESS_TOKEN = 'sbp_2c485a033dfe9b5fcf41ff624f28dca65f82231e';
const PROJECT_REF = 'qvhbigvdfyvhoegkhvef';

async function runQuery(query) {
  const response = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${ACCESS_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(error);
  }

  return response.json();
}

async function setupAutomation() {
  console.log('🚀 연차 자동화 시스템 설정 시작...\n');
  
  try {
    // 1. pg_cron 확장 확인
    console.log('1️⃣ pg_cron 확장 확인...');
    const checkCron = await runQuery(`
      SELECT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
      ) as cron_exists;
    `);
    
    if (!checkCron[0].cron_exists) {
      console.log('   pg_cron 확장 설치 중...');
      try {
        await runQuery('CREATE EXTENSION IF NOT EXISTS pg_cron;');
        console.log('   ✅ pg_cron 설치 완료');
      } catch (error) {
        console.log('   ⚠️ pg_cron은 Supabase 대시보드에서 활성화해야 합니다.');
        console.log('   https://supabase.com/dashboard/project/' + PROJECT_REF + '/settings/postgres');
        return;
      }
    } else {
      console.log('   ✅ pg_cron 이미 설치됨');
    }
    
    // 2. 자동화 함수들 생성
    console.log('\n2️⃣ 자동화 함수 생성...');
    
    // 월차 부여 함수
    console.log('   월차 부여 함수 생성...');
    await runQuery(`
      CREATE OR REPLACE FUNCTION public.grant_monthly_leave()
      RETURNS void
      LANGUAGE plpgsql
      SECURITY DEFINER
      AS $$
      DECLARE
          emp RECORD;
          current_date_val DATE;
          months_worked INTEGER;
          monthly_leave INTEGER;
      BEGIN
          current_date_val := CURRENT_DATE;
          
          FOR emp IN 
              SELECT 
                  id,
                  email,
                  name,
                  join_date,
                  annual_leave_granted_current_year,
                  DATE_PART('year', AGE(current_date_val, join_date::date)) * 12 + 
                  DATE_PART('month', AGE(current_date_val, join_date::date)) as total_months
              FROM employees
              WHERE join_date IS NOT NULL
                AND DATE_PART('year', join_date::date) = DATE_PART('year', current_date_val)
          LOOP
              IF DATE_PART('day', emp.join_date::date) = 1 THEN
                  months_worked := DATE_PART('month', current_date_val) - DATE_PART('month', emp.join_date::date);
              ELSE
                  months_worked := DATE_PART('month', current_date_val) - DATE_PART('month', emp.join_date::date) - 1;
              END IF;
              
              monthly_leave := LEAST(GREATEST(months_worked, 0), 11);
              
              IF emp.annual_leave_granted_current_year != monthly_leave THEN
                  UPDATE employees
                  SET annual_leave_granted_current_year = monthly_leave,
                      remaining_annual_leave = monthly_leave - COALESCE(used_annual_leave, 0),
                      updated_at = NOW()
                  WHERE id = emp.id;
              END IF;
          END LOOP;
      END;
      $$;
    `);
    console.log('   ✅ 월차 부여 함수 생성 완료');
    
    // 연차 초기화 함수
    console.log('   연차 초기화 함수 생성...');
    await runQuery(`
      CREATE OR REPLACE FUNCTION public.reset_annual_leave()
      RETURNS void
      LANGUAGE plpgsql
      SECURITY DEFINER
      AS $$
      DECLARE
          emp RECORD;
          new_leave INTEGER;
          service_years INTEGER;
          current_year INTEGER;
      BEGIN
          current_year := DATE_PART('year', CURRENT_DATE);
          
          FOR emp IN 
              SELECT 
                  id,
                  email,
                  name,
                  join_date,
                  DATE_PART('year', AGE(CURRENT_DATE, join_date::date)) as years_of_service
              FROM employees
              WHERE join_date IS NOT NULL
          LOOP
              service_years := emp.years_of_service;
              
              IF DATE_PART('year', emp.join_date::date) = current_year THEN
                  CONTINUE;
              ELSIF service_years = 0 THEN
                  new_leave := 15;
              ELSIF service_years <= 2 THEN
                  new_leave := 15;
              ELSE
                  new_leave := LEAST(15 + FLOOR((service_years - 1) / 2)::INTEGER, 25);
              END IF;
              
              UPDATE employees
              SET annual_leave_granted_current_year = new_leave,
                  used_annual_leave = 0,
                  remaining_annual_leave = new_leave,
                  updated_at = NOW()
              WHERE id = emp.id;
          END LOOP;
          
          PERFORM grant_monthly_leave();
      END;
      $$;
    `);
    console.log('   ✅ 연차 초기화 함수 생성 완료');
    
    // 입사기념일 체크 함수
    console.log('   입사기념일 체크 함수 생성...');
    await runQuery(`
      CREATE OR REPLACE FUNCTION public.check_anniversary()
      RETURNS void
      LANGUAGE plpgsql
      SECURITY DEFINER
      AS $$
      DECLARE
          emp RECORD;
          today DATE;
      BEGIN
          today := CURRENT_DATE;
          
          FOR emp IN 
              SELECT 
                  id,
                  email,
                  name,
                  join_date
              FROM employees
              WHERE join_date = today - INTERVAL '1 year'
          LOOP
              UPDATE employees
              SET annual_leave_granted_current_year = 15,
                  remaining_annual_leave = 15 - COALESCE(used_annual_leave, 0),
                  updated_at = NOW()
              WHERE id = emp.id;
          END LOOP;
      END;
      $$;
    `);
    console.log('   ✅ 입사기념일 체크 함수 생성 완료');
    
    // 수동 실행 함수
    console.log('   수동 실행 함수 생성...');
    await runQuery(`
      CREATE OR REPLACE FUNCTION public.run_annual_leave_automation(
          task_name TEXT DEFAULT 'all'
      )
      RETURNS TABLE(
          task TEXT,
          status TEXT,
          message TEXT
      )
      LANGUAGE plpgsql
      SECURITY DEFINER
      AS $$
      BEGIN
          IF task_name = 'all' OR task_name = 'reset' THEN
              PERFORM reset_annual_leave();
              RETURN QUERY SELECT 'reset_annual_leave'::TEXT, 'completed'::TEXT, '연차 초기화 완료'::TEXT;
          END IF;
          
          IF task_name = 'all' OR task_name = 'monthly' THEN
              PERFORM grant_monthly_leave();
              RETURN QUERY SELECT 'grant_monthly_leave'::TEXT, 'completed'::TEXT, '월차 부여 완료'::TEXT;
          END IF;
          
          IF task_name = 'all' OR task_name = 'anniversary' THEN
              PERFORM check_anniversary();
              RETURN QUERY SELECT 'check_anniversary'::TEXT, 'completed'::TEXT, '입사기념일 체크 완료'::TEXT;
          END IF;
          
          IF task_name NOT IN ('all', 'reset', 'monthly', 'anniversary') THEN
              RETURN QUERY SELECT task_name, 'error'::TEXT, '유효하지 않은 작업명'::TEXT;
          END IF;
      END;
      $$;
    `);
    console.log('   ✅ 수동 실행 함수 생성 완료');
    
    // 3. pg_cron 스케줄 설정
    console.log('\n3️⃣ pg_cron 스케줄 설정...');
    
    try {
      // 기존 스케줄 삭제
      await runQuery(`SELECT cron.unschedule('annual-leave-reset');`).catch(() => {});
      await runQuery(`SELECT cron.unschedule('monthly-leave-grant');`).catch(() => {});
      await runQuery(`SELECT cron.unschedule('anniversary-check');`).catch(() => {});
      
      // 새 스케줄 설정
      console.log('   1월 1일 연차 초기화 스케줄 설정...');
      await runQuery(`
        SELECT cron.schedule(
            'annual-leave-reset',
            '0 0 1 1 *',
            $$SELECT public.reset_annual_leave();$$
        );
      `);
      
      console.log('   매월 1일 월차 부여 스케줄 설정...');
      await runQuery(`
        SELECT cron.schedule(
            'monthly-leave-grant',
            '30 0 1 * *',
            $$SELECT public.grant_monthly_leave();$$
        );
      `);
      
      console.log('   매일 입사기념일 체크 스케줄 설정...');
      await runQuery(`
        SELECT cron.schedule(
            'anniversary-check',
            '0 1 * * *',
            $$SELECT public.check_anniversary();$$
        );
      `);
      
      console.log('   ✅ 모든 스케줄 설정 완료');
      
      // 스케줄 확인
      const schedules = await runQuery(`
        SELECT 
            jobname as schedule_name,
            schedule,
            command
        FROM cron.job
        WHERE jobname IN ('annual-leave-reset', 'monthly-leave-grant', 'anniversary-check');
      `);
      
      console.log('\n📅 설정된 스케줄:');
      schedules.forEach(s => {
        console.log(`   ${s.schedule_name}: ${s.schedule}`);
      });
      
    } catch (error) {
      console.log('   ⚠️ pg_cron 스케줄 설정 실패. Supabase 대시보드에서 pg_cron을 활성화하세요.');
      console.log('   에러:', error.message);
    }
    
    // 4. 테스트 실행
    console.log('\n4️⃣ 테스트 실행...');
    const testResult = await runQuery(`
      SELECT * FROM run_annual_leave_automation('monthly');
    `);
    
    console.log('   테스트 결과:');
    testResult.forEach(r => {
      console.log(`   ${r.task}: ${r.status} - ${r.message}`);
    });
    
    console.log('\n✅ 연차 자동화 시스템 설정 완료!');
    console.log('\n📌 설정된 자동 실행:');
    console.log('   • 매년 1월 1일 00:00 - 전체 직원 연차 초기화');
    console.log('   • 매월 1일 00:30 - 신입 월차 부여');
    console.log('   • 매일 01:00 - 입사 1년 완성자 체크');
    console.log('\n💡 수동 실행 방법:');
    console.log("   SELECT * FROM run_annual_leave_automation('all');     -- 모든 작업");
    console.log("   SELECT * FROM run_annual_leave_automation('reset');   -- 연차 초기화");
    console.log("   SELECT * FROM run_annual_leave_automation('monthly'); -- 월차 부여");
    console.log("   SELECT * FROM run_annual_leave_automation('anniversary'); -- 입사기념일");
    
  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  }
}

setupAutomation();