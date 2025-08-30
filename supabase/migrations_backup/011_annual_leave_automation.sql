-- 011_annual_leave_automation.sql
-- 연차 자동화 시스템 구축
-- 1. pg_cron 설정
-- 2. 월차 자동 부여 함수
-- 3. 연차 초기화 함수
-- 4. 입사기념일 체크 함수

-- ============================================
-- 1. pg_cron 확장 활성화 (이미 있으면 스킵)
-- ============================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- cron 작업 스키마 생성 (Supabase에서 필요)
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- ============================================
-- 2. 월차 자동 부여 함수 (매월 1일 실행)
-- ============================================
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
    
    -- 1년 미만 직원들 대상으로 월차 계산
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
        -- 월차 계산 로직
        IF DATE_PART('day', emp.join_date::date) = 1 THEN
            -- 1일 입사자: 입사월 다음달부터 월차 발생
            months_worked := DATE_PART('month', current_date_val) - DATE_PART('month', emp.join_date::date);
        ELSE
            -- 1일이 아닌 입사자: 1개월 만근 후 다음달부터
            months_worked := DATE_PART('month', current_date_val) - DATE_PART('month', emp.join_date::date) - 1;
        END IF;
        
        -- 월차는 최대 11개
        monthly_leave := LEAST(GREATEST(months_worked, 0), 11);
        
        -- 현재 설정된 연차와 다르면 업데이트
        IF emp.annual_leave_granted_current_year != monthly_leave THEN
            UPDATE employees
            SET annual_leave_granted_current_year = monthly_leave,
                remaining_annual_leave = monthly_leave - COALESCE(used_annual_leave, 0),
                updated_at = NOW()
            WHERE id = emp.id;
            
            RAISE NOTICE '월차 부여: % (%개)', emp.name, monthly_leave;
        END IF;
    END LOOP;
END;
$$;

-- ============================================
-- 3. 연차 초기화 함수 (매년 1월 1일 실행)
-- ============================================
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
        
        -- 법정 연차 계산
        IF DATE_PART('year', emp.join_date::date) = current_year THEN
            -- 신입: 월차로 처리 (grant_monthly_leave에서 처리)
            CONTINUE;
        ELSIF service_years = 0 THEN
            -- 입사 1년차: 15일
            new_leave := 15;
        ELSIF service_years <= 2 THEN
            -- 1~2년차: 15일
            new_leave := 15;
        ELSE
            -- 3년차 이상: 2년마다 1일 추가 (최대 25일)
            new_leave := LEAST(15 + FLOOR((service_years - 1) / 2)::INTEGER, 25);
        END IF;
        
        -- 연차 초기화 (사용연차 0, 잔여연차 = 지급연차)
        UPDATE employees
        SET annual_leave_granted_current_year = new_leave,
            used_annual_leave = 0,
            remaining_annual_leave = new_leave,
            updated_at = NOW()
        WHERE id = emp.id;
        
        RAISE NOTICE '연차 초기화: % (%년차, %개)', emp.name, service_years, new_leave;
    END LOOP;
    
    -- 신입 월차 처리
    PERFORM grant_monthly_leave();
END;
$$;

-- ============================================
-- 4. 입사 기념일 체크 함수 (매일 실행)
-- ============================================
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
    
    -- 정확히 1년 전 오늘 입사한 직원 찾기
    FOR emp IN 
        SELECT 
            id,
            email,
            name,
            join_date
        FROM employees
        WHERE join_date = today - INTERVAL '1 year'
    LOOP
        -- 입사 1년 완성: 15개 연차 부여
        UPDATE employees
        SET annual_leave_granted_current_year = 15,
            remaining_annual_leave = 15 - COALESCE(used_annual_leave, 0),
            updated_at = NOW()
        WHERE id = emp.id;
        
        RAISE NOTICE '입사 1년 완성: % (15개 부여)', emp.name;
    END LOOP;
END;
$$;

-- ============================================
-- 5. pg_cron 스케줄 설정
-- ============================================

-- 기존 스케줄 삭제 (있으면)
SELECT cron.unschedule('annual-leave-reset');
SELECT cron.unschedule('monthly-leave-grant');
SELECT cron.unschedule('anniversary-check');

-- 1월 1일 00:00 - 연차 초기화
SELECT cron.schedule(
    'annual-leave-reset',
    '0 0 1 1 *',  -- 매년 1월 1일 00:00
    $$SELECT public.reset_annual_leave();$$
);

-- 매월 1일 00:30 - 월차 부여
SELECT cron.schedule(
    'monthly-leave-grant',
    '30 0 1 * *',  -- 매월 1일 00:30
    $$SELECT public.grant_monthly_leave();$$
);

-- 매일 01:00 - 입사기념일 체크
SELECT cron.schedule(
    'anniversary-check',
    '0 1 * * *',  -- 매일 01:00
    $$SELECT public.check_anniversary();$$
);

-- ============================================
-- 6. 수동 실행 함수 (테스트/관리용)
-- ============================================
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
        RETURN QUERY SELECT 'reset_annual_leave', 'completed', '연차 초기화 완료';
    END IF;
    
    IF task_name = 'all' OR task_name = 'monthly' THEN
        PERFORM grant_monthly_leave();
        RETURN QUERY SELECT 'grant_monthly_leave', 'completed', '월차 부여 완료';
    END IF;
    
    IF task_name = 'all' OR task_name = 'anniversary' THEN
        PERFORM check_anniversary();
        RETURN QUERY SELECT 'check_anniversary', 'completed', '입사기념일 체크 완료';
    END IF;
    
    IF task_name NOT IN ('all', 'reset', 'monthly', 'anniversary') THEN
        RETURN QUERY SELECT task_name, 'error', '유효하지 않은 작업명';
    END IF;
END;
$$;

-- ============================================
-- 7. 스케줄 확인 뷰
-- ============================================
CREATE OR REPLACE VIEW public.annual_leave_schedules AS
SELECT 
    jobname as schedule_name,
    schedule,
    command,
    nodename,
    nodeport,
    database,
    username,
    active
FROM cron.job
WHERE jobname IN ('annual-leave-reset', 'monthly-leave-grant', 'anniversary-check');

-- 권한 설정
GRANT SELECT ON public.annual_leave_schedules TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_annual_leave_automation TO authenticated;

-- ============================================
-- 8. 설정 확인
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '===================================';
    RAISE NOTICE '연차 자동화 시스템 설정 완료';
    RAISE NOTICE '===================================';
    RAISE NOTICE '1. 매년 1월 1일 00:00 - 연차 초기화';
    RAISE NOTICE '2. 매월 1일 00:30 - 월차 부여';
    RAISE NOTICE '3. 매일 01:00 - 입사기념일 체크';
    RAISE NOTICE '';
    RAISE NOTICE '수동 실행:';
    RAISE NOTICE 'SELECT * FROM run_annual_leave_automation(''all'');';
    RAISE NOTICE 'SELECT * FROM run_annual_leave_automation(''reset'');';
    RAISE NOTICE 'SELECT * FROM run_annual_leave_automation(''monthly'');';
    RAISE NOTICE 'SELECT * FROM run_annual_leave_automation(''anniversary'');';
    RAISE NOTICE '';
    RAISE NOTICE '스케줄 확인:';
    RAISE NOTICE 'SELECT * FROM annual_leave_schedules;';
END $$;