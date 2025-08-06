-- 005_add_monthly_attendance_table.sql
-- 월별 만근 기록 테이블 생성 (신입 직원 연차 계산용)

-- 1. 월별 만근 기록 테이블 생성
CREATE TABLE monthly_attendance (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER REFERENCES employees(id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
  is_full_attendance BOOLEAN DEFAULT FALSE,
  earned_leave_days INTEGER DEFAULT 0,
  work_days INTEGER DEFAULT 0, -- 해당 월의 총 근무일수
  attendance_days INTEGER DEFAULT 0, -- 실제 출근일수
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- 중복 방지: 직원별 년월 조합 유니크
  UNIQUE(employee_id, year, month)
);

-- 2. 인덱스 생성 (성능 최적화)
CREATE INDEX idx_monthly_attendance_employee_year ON monthly_attendance(employee_id, year);
CREATE INDEX idx_monthly_attendance_year_month ON monthly_attendance(year, month);
CREATE INDEX idx_monthly_attendance_full_attendance ON monthly_attendance(is_full_attendance);

-- 3. 업데이트 트리거 생성
CREATE OR REPLACE FUNCTION update_monthly_attendance_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_monthly_attendance_timestamp
  BEFORE UPDATE ON monthly_attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_monthly_attendance_timestamp();

-- 4. RLS (Row Level Security) 정책 설정
ALTER TABLE monthly_attendance ENABLE ROW LEVEL SECURITY;

-- 모든 직원이 자신의 기록만 조회 가능
CREATE POLICY "직원은 자신의 월별 출근 기록만 조회 가능" ON monthly_attendance
  FOR SELECT USING (
    employee_id IN (
      SELECT id FROM employees 
      WHERE email = auth.jwt() ->> 'email'
    )
  );

-- 관리자는 모든 기록 조회 가능
CREATE POLICY "관리자는 모든 월별 출근 기록 조회 가능" ON monthly_attendance
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM employees 
      WHERE email = auth.jwt() ->> 'email' 
      AND (is_admin = true OR role = 'Manager')
    )
  );

-- 시스템(서비스 역할)은 모든 작업 가능
CREATE POLICY "서비스 역할은 월별 출근 기록 모든 작업 가능" ON monthly_attendance
  FOR ALL USING (auth.role() = 'service_role');

-- 완료 메시지
SELECT '✅ monthly_attendance 테이블이 생성되었습니다.' as message;