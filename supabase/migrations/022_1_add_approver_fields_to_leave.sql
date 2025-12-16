-- 승인자/반려자 정보를 leave 테이블에 추가
ALTER TABLE leave 
ADD COLUMN IF NOT EXISTS approved_by TEXT,
ADD COLUMN IF NOT EXISTS rejected_by TEXT,
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ;

-- 인덱스 추가 (검색 성능 향상)
CREATE INDEX IF NOT EXISTS idx_leave_approved_by ON leave(approved_by);
CREATE INDEX IF NOT EXISTS idx_leave_rejected_by ON leave(rejected_by);

-- 기존 승인된 데이터에 대해 기본값 설정 (선택사항)
-- UPDATE leave 
-- SET approved_by = 'System' 
-- WHERE status = 'approved' AND approved_by IS NULL;