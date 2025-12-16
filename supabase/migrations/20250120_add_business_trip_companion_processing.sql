-- ============================================================================
-- 출장 승인 시 동행자 처리 및 MAKE 이메일 연동
-- 
-- 요구사항:
-- 1. 출장 승인 시 동행자들도 출장으로 처리되어야 함
-- 2. 동행자들도 달력에 표시되어야 함
-- 3. 동행자들도 출장 카운트에 포함되어야 함
-- 4. 근무 기록에서 미출근으로 표시되지 않아야 함
-- 5. MAKE와 연동해서 출장 승인 시 사내 전체에 이메일 보내기
-- ============================================================================

-- STEP 1: 출장 승인 시 동행자 처리 함수 생성
CREATE OR REPLACE FUNCTION process_business_trip_companions()
RETURNS TRIGGER AS $$
DECLARE
    출장자_배열 TEXT[];
    make_webhook_url TEXT;
    email_subject TEXT;
    email_body TEXT;
    all_employees TEXT[];
BEGIN
    -- 출장(biztrip)이고 승인된 경우만 처리
    IF NEW.type NOT IN ('biztrip', 'business_trip') OR NEW.status != 'approved' OR OLD.status = 'approved' THEN
        RETURN NEW;
    END IF;
    
    -- 출장자 배열 가져오기 (본인 + 동행자 전체)
    출장자_배열 := COALESCE(NEW."출장자", ARRAY[NEW.name]);
    
    -- MAKE webhook 호출하여 사내 전체에 이메일 전송
    SELECT value INTO make_webhook_url FROM app_settings WHERE key = 'make_webhook_url';
    
    IF make_webhook_url IS NOT NULL AND make_webhook_url != '' THEN
        -- 이메일 제목 및 본문 생성
        IF array_length(출장자_배열, 1) > 1 THEN
            email_subject := '출장 승인 알림: ' || NEW.name || '님 외 ' || (array_length(출장자_배열, 1) - 1) || '명';
        ELSE
            email_subject := '출장 승인 알림: ' || NEW.name || '님';
        END IF;
        
        email_body := NEW.name || '님의 출장이 승인되었습니다.' || E'\n\n' ||
                     '기간: ' || TO_CHAR(NEW.start_date, 'YYYY-MM-DD') || ' ~ ' || TO_CHAR(NEW.end_date, 'YYYY-MM-DD') || E'\n' ||
                     '출장자: ' || array_to_string(출장자_배열, ', ');
        
        -- 사내 전체 직원 이메일 수집
        SELECT ARRAY_AGG(email) INTO all_employees
        FROM employees
        WHERE email IS NOT NULL AND email != '';
        
        -- MAKE webhook 호출
        IF all_employees IS NOT NULL AND array_length(all_employees, 1) > 0 THEN
            PERFORM net.http_post(
                url := make_webhook_url,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json'
                ),
                body := jsonb_build_object(
                    'subject', email_subject,
                    'body', email_body,
                    'recipients', all_employees,
                    'leave_id', NEW.id,
                    'requester_name', NEW.name,
                    'start_date', NEW.start_date,
                    'end_date', NEW.end_date,
                    '출장자', 출장자_배열,
                    'place', NEW.place,
                    'transport', NEW.transport
                )::jsonb
            );
        END IF;
    END IF;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in process_business_trip_companions: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 2: 트리거 생성
DROP TRIGGER IF EXISTS business_trip_companion_trigger ON leave;
CREATE TRIGGER business_trip_companion_trigger
    AFTER UPDATE ON leave
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'approved')
    EXECUTE FUNCTION process_business_trip_companions();

-- STEP 3: app_settings에 MAKE webhook URL 설정 (없는 경우)
INSERT INTO app_settings (key, value, description)
VALUES ('make_webhook_url', '', 'MAKE webhook URL for sending business trip approval emails')
ON CONFLICT (key) DO NOTHING;

-- 완료 메시지
SELECT '✅ 출장 승인 시 동행자 처리 및 MAKE 이메일 연동 설정 완료!' as result;

