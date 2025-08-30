-- ====================================================================
-- 초기 데이터베이스 스키마 생성
-- ====================================================================

-- 1. 직원 테이블 생성
-- ====================================================================
CREATE TABLE IF NOT EXISTS employees (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  department TEXT,
  position TEXT,
  hire_date DATE,
  phone TEXT,
  annual_leave_days INTEGER DEFAULT 15,
  remaining_annual_leave INTEGER DEFAULT 15,
  used_annual_leave INTEGER DEFAULT 0,
  annual_leave_granted INTEGER DEFAULT 0,
  attendance_role TEXT[],
  purchase_role TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 출근 기록 테이블 생성
-- ====================================================================
CREATE TABLE IF NOT EXISTS attendance_records (
  id BIGSERIAL PRIMARY KEY,
  employee_id TEXT NOT NULL,
  date DATE NOT NULL,
  check_in_time TIMESTAMPTZ,
  check_out_time TIMESTAMPTZ,
  work_hours DECIMAL(4,2),
  status TEXT DEFAULT 'present',
  location_latitude DECIMAL(10,8),
  location_longitude DECIMAL(11,8),
  check_in_address TEXT,
  check_out_address TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(employee_id, date)
);

-- 3. 연차/휴가 신청 테이블 생성
-- ====================================================================
CREATE TABLE IF NOT EXISTS leave (
  id BIGSERIAL PRIMARY KEY,
  user_email TEXT NOT NULL,
  name TEXT NOT NULL,
  department TEXT,
  position TEXT,
  type TEXT NOT NULL, -- 연차, 반차, 출장, 병가 등
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  days DECIMAL(3,1) NOT NULL,
  reason TEXT,
  status TEXT DEFAULT 'pending', -- pending, approved, rejected
  middle_manager_approval BOOLEAN DEFAULT FALSE,
  final_approval BOOLEAN DEFAULT FALSE,
  middle_manager_email TEXT,
  final_approver_email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 월별 출근 현황 테이블 생성
-- ====================================================================
CREATE TABLE IF NOT EXISTS monthly_attendance (
  id BIGSERIAL PRIMARY KEY,
  employee_id TEXT NOT NULL,
  year INTEGER NOT NULL,
  month INTEGER NOT NULL,
  total_work_days INTEGER DEFAULT 0,
  present_days INTEGER DEFAULT 0,
  absent_days INTEGER DEFAULT 0,
  late_days INTEGER DEFAULT 0,
  early_leave_days INTEGER DEFAULT 0,
  total_work_hours DECIMAL(6,2) DEFAULT 0,
  overtime_hours DECIMAL(6,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(employee_id, year, month)
);

-- 5. 인덱스 생성
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_employees_email ON employees(email);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department);
CREATE INDEX IF NOT EXISTS idx_attendance_records_employee_date ON attendance_records(employee_id, date);
CREATE INDEX IF NOT EXISTS idx_attendance_records_date ON attendance_records(date);
CREATE INDEX IF NOT EXISTS idx_leave_user_email ON leave(user_email);
CREATE INDEX IF NOT EXISTS idx_leave_dates ON leave(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_leave_status ON leave(status);
CREATE INDEX IF NOT EXISTS idx_monthly_attendance_employee ON monthly_attendance(employee_id, year, month);

-- 6. 기본 함수 생성
-- ====================================================================

-- 업데이트 시간 자동 갱신 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 각 테이블에 업데이트 트리거 적용
CREATE TRIGGER update_employees_updated_at 
    BEFORE UPDATE ON employees 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_attendance_records_updated_at 
    BEFORE UPDATE ON attendance_records 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_leave_updated_at 
    BEFORE UPDATE ON leave 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_monthly_attendance_updated_at 
    BEFORE UPDATE ON monthly_attendance 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 완료 메시지
SELECT '초기 데이터베이스 스키마가 성공적으로 생성되었습니다.' as message;
