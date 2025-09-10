-- 발주 승인 관련 누락된 컬럼 추가
-- Supabase SQL Editor에서 바로 실행하세요!

-- 1. purchase_requests 테이블에 누락된 컬럼들 추가
ALTER TABLE purchase_requests 
ADD COLUMN IF NOT EXISTS middle_manager_approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS middle_manager_rejected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS middle_manager_rejection_reason TEXT,
ADD COLUMN IF NOT EXISTS final_manager_approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS final_manager_rejected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS final_manager_rejection_reason TEXT,
ADD COLUMN IF NOT EXISTS raw_material_manager_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS raw_material_manager_approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS raw_material_manager_rejected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS raw_material_manager_rejection_reason TEXT,
ADD COLUMN IF NOT EXISTS consumable_manager_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS consumable_manager_approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS consumable_manager_rejected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS consumable_manager_rejection_reason TEXT;

-- 2. 기존 데이터 업데이트 (승인된 건은 시간 설정)
UPDATE purchase_requests 
SET middle_manager_approved_at = updated_at
WHERE middle_manager_status = 'approved' 
  AND middle_manager_approved_at IS NULL;

UPDATE purchase_requests 
SET final_manager_approved_at = updated_at
WHERE final_manager_status = 'approved' 
  AND final_manager_approved_at IS NULL;

-- 3. 확인
SELECT 
  purchase_order_number,
  middle_manager_status,
  middle_manager_approved_at,
  final_manager_status,
  final_manager_approved_at
FROM purchase_requests
ORDER BY created_at DESC
LIMIT 5;