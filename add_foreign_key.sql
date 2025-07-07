-- ========================================
-- HANSL 앱 외래키 관계 추가 스크립트
-- ========================================
-- 목적: leave.user_email → employees.email 외래키 관계 설정
-- 이후: PostgREST 자동 조인 기능 활성화

-- 1️⃣ employees.email 컬럼에 UNIQUE 제약조건 추가
DO $$
BEGIN
  -- 이미 UNIQUE 제약조건이 있는지 확인
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_type = 'UNIQUE' 
    AND table_name = 'employees' 
    AND constraint_name LIKE '%email%'
  ) THEN
    -- UNIQUE 제약조건 추가
    ALTER TABLE employees ADD CONSTRAINT unique_employees_email UNIQUE (email);
    RAISE NOTICE '✅ UNIQUE 제약조건이 employees.email에 추가되었습니다.';
  ELSE
    RAISE NOTICE '✅ employees.email에 UNIQUE 제약조건이 이미 존재합니다.';
  END IF;
END $$;

-- 2️⃣ leave.user_email → employees.email 외래키 제약조건 추가
DO $$
BEGIN
  -- 이미 외래키 제약조건이 있는지 확인
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_type = 'FOREIGN KEY' 
    AND table_name = 'leave' 
    AND constraint_name = 'fk_leave_user_email_employees_email'
  ) THEN
    -- 외래키 제약조건 추가
    ALTER TABLE leave 
    ADD CONSTRAINT fk_leave_user_email_employees_email 
    FOREIGN KEY (user_email) 
    REFERENCES employees(email)
    ON DELETE CASCADE
    ON UPDATE CASCADE;
    
    RAISE NOTICE '🎉 외래키 관계가 성공적으로 추가되었습니다: leave.user_email → employees.email';
  ELSE
    RAISE NOTICE '✅ 외래키 제약조건이 이미 존재합니다.';
  END IF;
EXCEPTION
  WHEN others THEN
    RAISE WARNING '❌ 에러 발생: %', SQLERRM;
    RAISE NOTICE '💡 해결 방법:';
    RAISE NOTICE '   1. leave 테이블의 user_email 값이 모두 employees.email에 존재하는지 확인';
    RAISE NOTICE '   2. employees.email에 중복값이 없는지 확인';
    RAISE NOTICE '   3. 양쪽 테이블의 데이터 타입이 일치하는지 확인';
END $$;

-- 3️⃣ 결과 확인
SELECT 
  '외래키 관계 확인:' as status,
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'leave'
  AND tc.constraint_name = 'fk_leave_user_email_employees_email';

-- 4️⃣ 테스트 쿼리 (Flutter 앱에서 사용하는 조인)
-- 이 쿼리가 에러 없이 실행되면 성공!
SELECT '테스트 결과:' as status, count(*) as join_count
FROM leave l
JOIN employees e ON l.user_email = e.email;

-- 완료 메시지
SELECT '🎉 외래키 설정 완료! Flutter 앱의 에러가 해결되었습니다.' as final_result; 