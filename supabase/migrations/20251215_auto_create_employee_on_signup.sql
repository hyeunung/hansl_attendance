-- ====================================================================
-- 회원가입 시 employees 테이블 자동 생성
-- ====================================================================
-- 목적: auth.users에 사용자가 생성될 때 자동으로 employees 테이블에 레코드 생성
--      auth.users.id와 employees.id를 동기화하여 박정현 케이스 같은 문제 해결

-- 1. employees 테이블에 auth_user_id 컬럼 추가 (UUID)
-- ====================================================================
ALTER TABLE employees 
ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE;

-- 인덱스 생성 (조회 성능 향상)
CREATE INDEX IF NOT EXISTS idx_employees_auth_user_id ON employees(auth_user_id);

-- 2. auth.users 생성 시 employees 레코드 자동 생성 함수
-- ====================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_display_name TEXT;
  v_email TEXT;
  v_position TEXT;
BEGIN
  -- auth.users의 email과 raw_user_meta_data에서 이름 가져오기
  v_email := NEW.email;
  v_display_name := COALESCE(
    NEW.raw_user_meta_data->>'display_name',
    NEW.raw_user_meta_data->>'name',
    split_part(v_email, '@', 1)  -- 이메일에서 이름 부분 추출 (기본값)
  );
  
  -- raw_user_meta_data에서 직원 유형(position) 가져오기 (회원가입 시 선택한 값)
  v_position := NEW.raw_user_meta_data->>'position';

  -- employees 테이블에 이미 해당 이메일이나 auth_user_id로 등록된 사용자가 있는지 확인
  IF NOT EXISTS (
    SELECT 1 FROM employees 
    WHERE email = v_email OR id = NEW.id OR auth_user_id = NEW.id
  ) THEN
    -- employees 테이블에 새 레코드 생성
    -- id는 auth.users.id를 사용하여 동기화 (둘 다 UUID)
    -- 신규 직원은 입사일(join_date)이 없으므로 연차는 0으로 설정
    -- 입사일 설정 후 fix_new_hire_annual_leave 함수로 연차 계산 필요
    INSERT INTO public.employees (
      id,
      name,
      email,
      auth_user_id,
      department,
      position,
      join_date,
      annual_leave_granted_current_year,
      remaining_annual_leave,
      used_annual_leave,
      updated_at
    ) VALUES (
      NEW.id,  -- auth.users.id를 그대로 사용 (UUID 타입) - 동기화
      v_display_name,
      v_email,
      NEW.id,  -- auth.users.id를 auth_user_id로도 저장
      NULL,  -- 부서는 나중에 관리자가 설정
      v_position,  -- 회원가입 시 선택한 직원 유형 (알바, 계약직, 정직원)
      NULL,  -- 입사일은 관리자가 수동으로 설정 (설정 후 트리거가 자동으로 연차 계산)
      0,   -- 입사일이 없으므로 연차 0 (입사일 설정 후 자동 계산됨)
      0,   -- 남은 연차도 0
      0,   -- 사용한 연차
      NOW()
    );
  ELSE
    -- 이미 존재하는 경우:
    -- 1. id가 다른 경우: id를 auth.users.id로 업데이트 (동기화)
    -- 2. auth_user_id가 없는 경우: auth_user_id 업데이트
    UPDATE public.employees
    SET 
      id = CASE 
        WHEN id != NEW.id THEN NEW.id  -- id가 다르면 동기화
        ELSE id  -- 같으면 유지
      END,
      auth_user_id = COALESCE(auth_user_id, NEW.id),  -- auth_user_id가 없으면 설정
      updated_at = NOW()
    WHERE (email = v_email OR id = NEW.id OR auth_user_id = NEW.id)
      AND (id != NEW.id OR auth_user_id IS NULL);
  END IF;

  RETURN NEW;
END;
$$;

-- 3. 트리거 생성
-- ====================================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 4. 기존 employees 레코드에 auth_user_id 업데이트 (이메일로 매칭)
-- ====================================================================
UPDATE employees e
SET auth_user_id = au.id
FROM auth.users au
WHERE e.email = au.email
  AND e.auth_user_id IS NULL;

-- 5. 권한 설정
-- ====================================================================
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- 6. 코멘트 추가
-- ====================================================================
COMMENT ON FUNCTION public.handle_new_user() IS 'auth.users에 새 사용자가 생성될 때 employees 테이블에 자동으로 레코드를 생성하는 함수';
COMMENT ON TRIGGER on_auth_user_created ON auth.users IS '회원가입 시 employees 테이블 자동 생성 트리거';
COMMENT ON COLUMN employees.auth_user_id IS 'auth.users.id와 매핑되는 UUID. 회원가입 시 자동 설정됨';

