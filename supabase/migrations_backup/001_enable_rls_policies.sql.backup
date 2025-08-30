-- ====================================================================
-- RLS 정책 설정 (모바일 앱 보안 강화)
-- 브랜치 DB 전용: mobile-app-secure
-- ====================================================================

-- 1. 직원 정보 테이블 보안 강화
-- ====================================================================
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- 자신의 정보만 조회 가능
CREATE POLICY "users_can_view_own_profile" ON employees
FOR SELECT 
USING (auth.email() = email);

-- 관리자는 모든 직원 정보 조회 가능 (attendance_role에 'admin' 포함)
CREATE POLICY "admins_can_view_all_employees" ON employees
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND 'admin' = ANY(attendance_role)
  )
);

-- 부서 관리자는 자신이 담당하는 부서 직원 정보만 조회 가능
CREATE POLICY "managers_can_view_their_department" ON employees
FOR SELECT 
USING (
  -- 개발팀 매니저: 개발1팀, 개발2팀
  (EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND '개발팀_manager' = ANY(attendance_role)
  ) AND department IN ('개발1팀', '개발2팀'))
  OR
  -- 개발3팀 매니저: 개발3팀
  (EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND '개발3팀_manager' = ANY(attendance_role)
  ) AND department = '개발3팀')
  OR
  -- 연구소 매니저: 연구소
  (EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND '연구소_manager' = ANY(attendance_role)
  ) AND department = '연구소')
  OR
  -- 경영지원팀 매니저: 경영지원팀
  (EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND '경영지원팀_manager' = ANY(attendance_role)
  ) AND department = '경영지원팀')
  OR
  -- CAD 매니저: CAD
  (EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND 'CAD_manager' = ANY(attendance_role)
  ) AND department = 'CAD')
);

-- 직원 정보 수정은 관리자만 가능
CREATE POLICY "only_admins_can_update_employees" ON employees
FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND 'admin' = ANY(attendance_role)
  )
);

-- 2. 출근 기록 테이블 보안 강화
-- ====================================================================
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;

-- 자신의 출근 기록만 생성/수정 가능
CREATE POLICY "users_can_manage_own_attendance" ON attendance_records
FOR ALL 
USING (
  employee_id = (
    SELECT id::text FROM employees 
    WHERE email = auth.email()
  )
);

-- 관리자는 모든 출근 기록 조회 가능
CREATE POLICY "admins_can_view_all_attendance" ON attendance_records
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND 'admin' = ANY(attendance_role)
  )
);

-- 부서 관리자는 자신이 담당하는 부서 직원의 출근 기록만 조회 가능
CREATE POLICY "managers_can_view_department_attendance" ON attendance_records
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM employees e1, employees e2
    WHERE e1.email = auth.email()  -- 현재 로그인 사용자
    AND e2.id::text = attendance_records.employee_id  -- 출근 기록 소유자
    AND e1.attendance_role IS NOT NULL
    AND (
      -- 개발팀 매니저
      ('개발팀_manager' = ANY(e1.attendance_role) AND e2.department IN ('개발1팀', '개발2팀'))
      OR
      -- 개발3팀 매니저
      ('개발3팀_manager' = ANY(e1.attendance_role) AND e2.department = '개발3팀')
      OR
      -- 연구소 매니저
      ('연구소_manager' = ANY(e1.attendance_role) AND e2.department = '연구소')
      OR
      -- 경영지원팀 매니저
      ('경영지원팀_manager' = ANY(e1.attendance_role) AND e2.department = '경영지원팀')
      OR
      -- CAD 매니저
      ('CAD_manager' = ANY(e1.attendance_role) AND e2.department = 'CAD')
    )
  )
);

-- 3. 연차/출장 신청 테이블 보안 강화
-- ====================================================================
ALTER TABLE leave ENABLE ROW LEVEL SECURITY;

-- 자신의 연차 신청만 생성/조회 가능
CREATE POLICY "users_can_manage_own_leave" ON leave
FOR ALL 
USING (user_email = auth.email());

-- 관리자는 모든 연차 신청 조회/수정 가능
CREATE POLICY "admins_can_manage_all_leave" ON leave
FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND 'admin' = ANY(attendance_role)
  )
);

-- 부서 관리자는 자신이 담당하는 부서 직원의 연차 신청만 조회/승인 가능
CREATE POLICY "managers_can_manage_department_leave" ON leave
FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM employees e1, employees e2
    WHERE e1.email = auth.email()  -- 현재 로그인 사용자 (관리자)
    AND e2.email = leave.user_email  -- 연차 신청자
    AND e1.attendance_role IS NOT NULL
    AND (
      -- 개발팀 매니저
      ('개발팀_manager' = ANY(e1.attendance_role) AND e2.department IN ('개발1팀', '개발2팀'))
      OR
      -- 개발3팀 매니저
      ('개발3팀_manager' = ANY(e1.attendance_role) AND e2.department = '개발3팀')
      OR
      -- 연구소 매니저
      ('연구소_manager' = ANY(e1.attendance_role) AND e2.department = '연구소')
      OR
      -- 경영지원팀 매니저
      ('경영지원팀_manager' = ANY(e1.attendance_role) AND e2.department = '경영지원팀')
      OR
      -- CAD 매니저
      ('CAD_manager' = ANY(e1.attendance_role) AND e2.department = 'CAD')
    )
  )
);

-- 4. 구매 요청 테이블 보안 강화 (있다면)
-- ====================================================================
-- purchase_requests 테이블이 존재한다면 적용
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'purchase_requests') THEN
    EXECUTE 'ALTER TABLE purchase_requests ENABLE ROW LEVEL SECURITY';
    
    -- 중간 관리자만 조회/수정 가능
    EXECUTE 'CREATE POLICY "middle_managers_can_manage_purchases" ON purchase_requests
    FOR ALL 
    USING (
      EXISTS (
        SELECT 1 FROM employees 
        WHERE email = auth.email() 
        AND purchase_role IS NOT NULL
        AND (''middle_manager'' = ANY(purchase_role) OR ''final_approver'' = ANY(purchase_role) OR ''app_admin'' = ANY(purchase_role))
      )
    )';
  END IF;
END $$;

-- 5. 보안 강화를 위한 추가 설정
-- ====================================================================

-- 인증되지 않은 사용자의 접근 차단
ALTER DEFAULT PRIVILEGES REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON SEQUENCES FROM anon;

-- 인증된 사용자의 기본 권한 제한
ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES REVOKE INSERT, UPDATE, DELETE ON TABLES FROM authenticated;

-- 로그 기록을 위한 감사 테이블 (선택사항)
CREATE TABLE IF NOT EXISTS security_audit_log (
  id BIGSERIAL PRIMARY KEY,
  user_email TEXT,
  action TEXT,
  table_name TEXT,
  record_id TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  ip_address INET,
  user_agent TEXT
);

-- 감사 로그는 관리자만 조회 가능
ALTER TABLE security_audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "only_admins_can_view_audit_log" ON security_audit_log
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND 'admin' = ANY(attendance_role)
  )
);

-- 6. Edge Functions 보안 설정
-- ====================================================================

-- Edge Functions에서 사용할 보안 함수들
CREATE OR REPLACE FUNCTION auth.is_admin()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND 'admin' = ANY(attendance_role)
  );
$$;

CREATE OR REPLACE FUNCTION auth.is_manager_for_department(dept TEXT)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND attendance_role IS NOT NULL
    AND (
      ('개발팀_manager' = ANY(attendance_role) AND dept IN ('개발1팀', '개발2팀'))
      OR ('개발3팀_manager' = ANY(attendance_role) AND dept = '개발3팀')
      OR ('연구소_manager' = ANY(attendance_role) AND dept = '연구소')
      OR ('경영지원팀_manager' = ANY(attendance_role) AND dept = '경영지원팀')
      OR ('CAD_manager' = ANY(attendance_role) AND dept = 'CAD')
    )
  );
$$;

-- 완료 메시지
SELECT 'RLS 정책이 모바일 앱 브랜치에 성공적으로 적용되었습니다.' as message; 