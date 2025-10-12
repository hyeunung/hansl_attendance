-- 발주 관련 테이블 생성 (이미 있다면 무시됨)

-- 1. purchase_requests 테이블 생성
CREATE TABLE IF NOT EXISTS purchase_requests (
  id BIGSERIAL PRIMARY KEY,
  purchase_order_number TEXT UNIQUE NOT NULL,
  request_date DATE NOT NULL,
  delivery_request_date DATE,
  progress_type TEXT NOT NULL,
  is_payment_completed BOOLEAN DEFAULT FALSE,
  payment_category TEXT NOT NULL,
  currency TEXT DEFAULT 'KRW',
  request_type TEXT,
  vendor_name TEXT NOT NULL,
  vendor_payment_schedule TEXT,
  requester_name TEXT NOT NULL,
  requester_email TEXT,
  item_name TEXT,
  specification TEXT,
  quantity INTEGER,
  unit_price_value DECIMAL(15,2),
  amount_value DECIMAL(15,2),
  remark TEXT,
  project_vendor TEXT,
  sales_order_number TEXT,
  project_item TEXT,
  line_number INTEGER,
  contact_name TEXT,
  middle_manager_status TEXT DEFAULT 'pending',
  final_manager_status TEXT DEFAULT 'pending',
  payment_completed_at TIMESTAMPTZ,
  is_received BOOLEAN DEFAULT FALSE,
  received_at TIMESTAMPTZ,
  link TEXT,
  is_po_download BOOLEAN DEFAULT FALSE,
  
  -- 승인 관련 필드
  middle_manager_approved_at TIMESTAMPTZ,
  middle_manager_comment TEXT,
  middle_manager_rejected_at TIMESTAMPTZ,
  middle_manager_rejection_reason TEXT,
  
  final_manager_approved_at TIMESTAMPTZ,
  final_manager_rejected_at TIMESTAMPTZ,
  final_manager_rejection_reason TEXT,
  
  raw_material_manager_status TEXT DEFAULT 'pending',
  raw_material_manager_approved_at TIMESTAMPTZ,
  raw_material_manager_rejected_at TIMESTAMPTZ,
  raw_material_manager_rejection_reason TEXT,
  
  consumable_manager_status TEXT DEFAULT 'pending',
  consumable_manager_approved_at TIMESTAMPTZ,
  consumable_manager_rejected_at TIMESTAMPTZ,
  consumable_manager_rejection_reason TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. purchase_request_items 테이블 생성
CREATE TABLE IF NOT EXISTS purchase_request_items (
  id BIGSERIAL PRIMARY KEY,
  purchase_order_number TEXT NOT NULL,
  item_name TEXT NOT NULL,
  vendor_name TEXT,
  specification TEXT,
  quantity INTEGER NOT NULL,
  unit_price_value DECIMAL(15,2) NOT NULL,
  amount_value DECIMAL(15,2) NOT NULL,
  line_number INTEGER NOT NULL,
  is_payment_completed BOOLEAN DEFAULT FALSE,
  is_received BOOLEAN DEFAULT FALSE,
  payment_completed_at TIMESTAMPTZ,
  received_at TIMESTAMPTZ,
  remark TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(purchase_order_number, line_number)
);

-- 3. 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_purchase_requests_po ON purchase_requests(purchase_order_number);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_status ON purchase_requests(middle_manager_status, final_manager_status);
CREATE INDEX IF NOT EXISTS idx_purchase_request_items_po ON purchase_request_items(purchase_order_number);

-- 4. RLS 정책 (필요시)
ALTER TABLE purchase_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_request_items ENABLE ROW LEVEL SECURITY;

-- 간단한 읽기 정책 (인증된 사용자는 모두 볼 수 있음)
CREATE POLICY "Users can view purchase requests" ON purchase_requests
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can view purchase items" ON purchase_request_items
  FOR SELECT TO authenticated USING (true);

-- 5. 테이블 존재 확인
SELECT 
  'purchase_requests' as table_name,
  EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'purchase_requests'
  ) as exists
UNION ALL
SELECT 
  'purchase_request_items',
  EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'purchase_request_items'
  );
