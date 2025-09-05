-- 월별 출근 현황 테이블 생성 (누락된 테이블) - 기존 테이블이 있는 경우 새 컬럼만 추가
DO $$
BEGIN
  -- 기존 테이블이 없으면 생성
  IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'monthly_attendance') THEN
    CREATE TABLE monthly_attendance (
      id BIGSERIAL PRIMARY KEY,
      employee_id TEXT NOT NULL,
      year INTEGER NOT NULL,
      month INTEGER NOT NULL,
      work_days INTEGER DEFAULT 0,
      attendance_days INTEGER DEFAULT 0,
      is_full_attendance BOOLEAN DEFAULT false,
      earned_leave_days NUMERIC(3,1) DEFAULT 0,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(employee_id, year, month)
    );
  ELSE
    -- 기존 테이블에 새 컬럼 추가
    IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'monthly_attendance' AND column_name = 'work_days') THEN
      ALTER TABLE monthly_attendance ADD COLUMN work_days INTEGER DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'monthly_attendance' AND column_name = 'attendance_days') THEN
      ALTER TABLE monthly_attendance ADD COLUMN attendance_days INTEGER DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'monthly_attendance' AND column_name = 'is_full_attendance') THEN
      ALTER TABLE monthly_attendance ADD COLUMN is_full_attendance BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'monthly_attendance' AND column_name = 'earned_leave_days') THEN
      ALTER TABLE monthly_attendance ADD COLUMN earned_leave_days NUMERIC(3,1) DEFAULT 0;
    END IF;
  END IF;
END
$$;

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_monthly_attendance_employee ON monthly_attendance(employee_id, year, month);
CREATE INDEX IF NOT EXISTS idx_monthly_attendance_year_month ON monthly_attendance(year, month);

-- RLS 정책 설정
ALTER TABLE monthly_attendance ENABLE ROW LEVEL SECURITY;

-- 본인 데이터 조회 가능 (TEXT 타입으로 변환)
CREATE POLICY "monthly_attendance_select_own" ON monthly_attendance FOR SELECT
  USING (employee_id = (
    SELECT id::TEXT FROM employees WHERE email = auth.email() LIMIT 1
  ));

-- 관리자는 모든 데이터 조회 가능
CREATE POLICY "monthly_attendance_select_admin" ON monthly_attendance FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM employees
    WHERE email = auth.email()
    AND 'admin' = ANY(attendance_role)
  ));

-- Service role만 업데이트/삽입 가능 (Edge Function에서 사용)
CREATE POLICY "monthly_attendance_service_all" ON monthly_attendance
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- 권한 설정
GRANT SELECT ON monthly_attendance TO authenticated;
GRANT ALL ON monthly_attendance TO service_role;