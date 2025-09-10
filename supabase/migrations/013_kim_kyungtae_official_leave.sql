-- 김경태님 공가 처리 (2025년 1월 31일, 2월 11일~13일)
-- 1/31: 장인어른 상
-- 2/11~2/13: 할머니 상

-- 김경태님 이메일 확인
DO $$
DECLARE
  v_user_email text;
BEGIN
  -- 김경태님 이메일 조회
  SELECT email INTO v_user_email 
  FROM employees 
  WHERE name = '김경태'
  LIMIT 1;
  
  IF v_user_email IS NULL THEN
    RAISE NOTICE '김경태님을 찾을 수 없습니다.';
    RETURN;
  END IF;
  
  RAISE NOTICE '김경태님 이메일: %', v_user_email;
  
  -- 기존 연차 신청이 있다면 삭제
  DELETE FROM leave 
  WHERE user_email = v_user_email 
  AND start_date IN ('2025-01-31', '2025-02-11', '2025-02-12', '2025-02-13');
  
  -- 1/31 장인어른 상 - 공가 등록
  INSERT INTO leave (
    user_email,
    type,
    start_date,
    end_date,
    days,
    reason,
    status,
    created_at,
    updated_at
  ) VALUES (
    v_user_email,
    'official',  -- 공가
    '2025-01-31',
    '2025-01-31',
    1,
    '장인어른 상',
    'approved',
    NOW(),
    NOW()
  );
  
  -- 2/11~2/13 할머니 상 - 공가 등록
  INSERT INTO leave (
    user_email,
    type,
    start_date,
    end_date,
    days,
    reason,
    status,
    created_at,
    updated_at
  ) VALUES (
    v_user_email,
    'official',  -- 공가
    '2025-02-11',
    '2025-02-13',
    3,
    '할머니 상',
    'approved',
    NOW(),
    NOW()
  );
  
  RAISE NOTICE '공가 처리가 완료되었습니다.';
  
  -- 연차 사용 일수 업데이트 (공가는 연차 차감 안 함)
  -- annual_leave_history 테이블에서 해당 날짜의 연차 사용 기록이 있다면 삭제
  DELETE FROM annual_leave_history
  WHERE employee_email = v_user_email
  AND leave_date IN ('2025-01-31', '2025-02-11', '2025-02-12', '2025-02-13');
  
END $$;

-- 달력 화면에서 모든 직원이 승인된 연차/출장/공가를 볼 수 있도록 RLS 정책 수정
-- leave 테이블의 읽기 권한을 모든 인증된 사용자에게 부여

-- 기존 정책 삭제 (있을 경우)
DROP POLICY IF EXISTS "authenticated_users_can_view_approved_leaves" ON leave;

-- 새로운 정책 생성: 모든 인증된 사용자가 승인된 연차/출장/공가를 볼 수 있음
CREATE POLICY "authenticated_users_can_view_approved_leaves" 
ON leave 
FOR SELECT 
USING (
  auth.role() = 'authenticated' 
  AND status = 'approved'
);

-- 추가로 자신의 모든 연차는 상태와 관계없이 볼 수 있음
DROP POLICY IF EXISTS "users_can_view_own_leaves" ON leave;

CREATE POLICY "users_can_view_own_leaves" 
ON leave 
FOR SELECT 
USING (
  auth.role() = 'authenticated' 
  AND user_email = auth.jwt()->>'email'
);

-- 관리자는 모든 연차를 볼 수 있음
DROP POLICY IF EXISTS "admins_can_view_all_leaves" ON leave;

CREATE POLICY "admins_can_view_all_leaves" 
ON leave 
FOR SELECT 
USING (
  auth.role() = 'authenticated' 
  AND EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.jwt()->>'email' 
    AND (attendance_role IS NOT NULL AND array_length(attendance_role, 1) > 0)
  )
);