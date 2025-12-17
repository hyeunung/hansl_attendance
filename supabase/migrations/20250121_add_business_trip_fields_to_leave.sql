-- ============================================================================
-- 출장 관련 필드를 leave 테이블에 추가
-- 
-- 목적: MAKE 이메일 템플릿에서 각 항목을 개별적으로 표시하기 위해
-- reason 필드는 출장 시 실제 사유(예: '업무')만 저장
-- 출장자(본인+동행)는 별도 배열 필드로 저장
-- ============================================================================

-- STEP 1: leave 테이블에 출장 관련 필드 추가
ALTER TABLE leave 
ADD COLUMN IF NOT EXISTS 출장자 TEXT[],      -- 출장자 + 동행자 전체 배열
ADD COLUMN IF NOT EXISTS place TEXT,          -- 장소 (출장일 때만)
ADD COLUMN IF NOT EXISTS purpose TEXT,        -- 목적 (출장일 때만)
ADD COLUMN IF NOT EXISTS transport TEXT;      -- 교통수단 (출장일 때만)

-- STEP 2: 기존 출장 데이터에서 reason을 파싱해서 새 필드에 채우기
-- reason 형식: "출장자: 이름\n동행: 이름1, 이름2\n장소: 장소명\n목적: 목적\n교통수단: 교통수단"
DO $$
DECLARE
    rec RECORD;
    traveler_name TEXT;
    companion_line TEXT;
    companion_start_pos INTEGER;
    companion_end_pos INTEGER;
    place_start_pos INTEGER;
    place_end_pos INTEGER;
    purpose_start_pos INTEGER;
    purpose_end_pos INTEGER;
    transport_start_pos INTEGER;
    transport_end_pos INTEGER;
    traveler_start_pos INTEGER;
    traveler_end_pos INTEGER;
    all_travelers TEXT[];
BEGIN
    FOR rec IN 
        SELECT id, reason, name
        FROM leave 
        WHERE type IN ('biztrip', 'business_trip')
        AND reason IS NOT NULL
        AND (출장자 IS NULL OR place IS NULL OR purpose IS NULL OR transport IS NULL)
    LOOP
        -- 출장자 이름 추출 (reason에서 "출장자: 이름" 또는 name 필드 사용)
        traveler_name := rec.name;  -- 기본값은 name 필드
        
        IF POSITION('출장자' IN rec.reason) > 0 THEN
            traveler_start_pos := POSITION('출장자' IN rec.reason) + LENGTH('출장자');
            IF traveler_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM traveler_start_pos FOR 1) = ':' THEN
                traveler_start_pos := traveler_start_pos + 1;
                WHILE traveler_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM traveler_start_pos FOR 1) = ' ' LOOP
                    traveler_start_pos := traveler_start_pos + 1;
                END LOOP;
                
                traveler_end_pos := traveler_start_pos;
                WHILE traveler_end_pos <= LENGTH(rec.reason) 
                    AND SUBSTRING(rec.reason FROM traveler_end_pos FOR 1) != E'\n'
                    AND SUBSTRING(rec.reason FROM traveler_end_pos FOR 1) != E'\r' LOOP
                    traveler_end_pos := traveler_end_pos + 1;
                END LOOP;
                
                traveler_name := TRIM(SUBSTRING(rec.reason FROM traveler_start_pos FOR traveler_end_pos - traveler_start_pos));
            END IF;
        END IF;
        
        -- 출장자 배열 초기화 (본인 포함)
        all_travelers := ARRAY[traveler_name];
        
        -- 동행자 파싱 및 배열에 추가
        IF POSITION('동행' IN rec.reason) > 0 THEN
            companion_start_pos := POSITION('동행' IN rec.reason) + LENGTH('동행');
            IF companion_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM companion_start_pos FOR 1) = ':' THEN
                companion_start_pos := companion_start_pos + 1;
                WHILE companion_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM companion_start_pos FOR 1) = ' ' LOOP
                    companion_start_pos := companion_start_pos + 1;
                END LOOP;
                
                companion_end_pos := companion_start_pos;
                WHILE companion_end_pos <= LENGTH(rec.reason) 
                    AND SUBSTRING(rec.reason FROM companion_end_pos FOR 1) != E'\n'
                    AND SUBSTRING(rec.reason FROM companion_end_pos FOR 1) != E'\r' LOOP
                    companion_end_pos := companion_end_pos + 1;
                END LOOP;
                
                companion_line := SUBSTRING(rec.reason FROM companion_start_pos FOR companion_end_pos - companion_start_pos);
                
                IF companion_line IS NOT NULL AND companion_line != '' THEN
                    -- 동행자를 배열로 변환하여 출장자 배열에 추가
                    all_travelers := all_travelers || ARRAY(
                        SELECT TRIM(unnest(string_to_array(companion_line, ',')))
                    );
                END IF;
            END IF;
        END IF;
        
        -- 출장자 배열 업데이트
        UPDATE leave
        SET 출장자 = all_travelers
        WHERE id = rec.id;
        
        -- 장소 파싱
        IF POSITION('장소' IN rec.reason) > 0 THEN
            place_start_pos := POSITION('장소' IN rec.reason) + LENGTH('장소');
            IF place_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM place_start_pos FOR 1) = ':' THEN
                place_start_pos := place_start_pos + 1;
                WHILE place_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM place_start_pos FOR 1) = ' ' LOOP
                    place_start_pos := place_start_pos + 1;
                END LOOP;
                
                place_end_pos := place_start_pos;
                WHILE place_end_pos <= LENGTH(rec.reason) 
                    AND SUBSTRING(rec.reason FROM place_end_pos FOR 1) != E'\n'
                    AND SUBSTRING(rec.reason FROM place_end_pos FOR 1) != E'\r' LOOP
                    place_end_pos := place_end_pos + 1;
                END LOOP;
                
                UPDATE leave
                SET place = TRIM(SUBSTRING(rec.reason FROM place_start_pos FOR place_end_pos - place_start_pos))
                WHERE id = rec.id;
            END IF;
        END IF;
        
        -- 목적 파싱
        IF POSITION('목적' IN rec.reason) > 0 THEN
            purpose_start_pos := POSITION('목적' IN rec.reason) + LENGTH('목적');
            IF purpose_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM purpose_start_pos FOR 1) = ':' THEN
                purpose_start_pos := purpose_start_pos + 1;
                WHILE purpose_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM purpose_start_pos FOR 1) = ' ' LOOP
                    purpose_start_pos := purpose_start_pos + 1;
                END LOOP;
                
                purpose_end_pos := purpose_start_pos;
                WHILE purpose_end_pos <= LENGTH(rec.reason) 
                    AND SUBSTRING(rec.reason FROM purpose_end_pos FOR 1) != E'\n'
                    AND SUBSTRING(rec.reason FROM purpose_end_pos FOR 1) != E'\r' LOOP
                    purpose_end_pos := purpose_end_pos + 1;
                END LOOP;
                
                UPDATE leave
                SET purpose = TRIM(SUBSTRING(rec.reason FROM purpose_start_pos FOR purpose_end_pos - purpose_start_pos))
                WHERE id = rec.id;
            END IF;
        END IF;
        
        -- 교통수단 파싱
        IF POSITION('교통수단' IN rec.reason) > 0 THEN
            transport_start_pos := POSITION('교통수단' IN rec.reason) + LENGTH('교통수단');
            IF transport_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM transport_start_pos FOR 1) = ':' THEN
                transport_start_pos := transport_start_pos + 1;
                WHILE transport_start_pos <= LENGTH(rec.reason) AND SUBSTRING(rec.reason FROM transport_start_pos FOR 1) = ' ' LOOP
                    transport_start_pos := transport_start_pos + 1;
                END LOOP;
                
                transport_end_pos := transport_start_pos;
                WHILE transport_end_pos <= LENGTH(rec.reason) 
                    AND SUBSTRING(rec.reason FROM transport_end_pos FOR 1) != E'\n'
                    AND SUBSTRING(rec.reason FROM transport_end_pos FOR 1) != E'\r' LOOP
                    transport_end_pos := transport_end_pos + 1;
                END LOOP;
                
                UPDATE leave
                SET transport = TRIM(SUBSTRING(rec.reason FROM transport_start_pos FOR transport_end_pos - transport_start_pos))
                WHERE id = rec.id;
            END IF;
        END IF;
        
        -- reason에는 출장 "업무 내용"이 들어가야 함.
        -- 레거시 데이터에서는 '목적'이 사실상 업무 내용이므로 purpose로 채움.
        UPDATE leave
        SET reason = COALESCE(purpose, reason)
        WHERE id = rec.id AND type IN ('biztrip', 'business_trip');
    END LOOP;
END $$;

-- STEP 3: 인덱스 추가 (검색 성능 향상)
-- PostgreSQL에서는 한글 컬럼명을 인용부호로 감싸야 함
CREATE INDEX IF NOT EXISTS idx_leave_travelers ON leave USING GIN("출장자");
CREATE INDEX IF NOT EXISTS idx_leave_place ON leave(place) WHERE place IS NOT NULL;

-- 완료 메시지
SELECT '✅ 출장 관련 필드 추가 완료!' as result;



