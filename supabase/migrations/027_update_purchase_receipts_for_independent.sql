-- ====================================================================
-- purchase_receipts 테이블을 독립적인 영수증 시스템으로 확장
-- ====================================================================

-- 1. purchase_receipts 테이블에 독립적 업로드를 위한 컬럼 추가
ALTER TABLE purchase_receipts 
ADD COLUMN IF NOT EXISTS description TEXT,           -- 영수증 설명
ADD COLUMN IF NOT EXISTS category TEXT DEFAULT '일반', -- 카테고리 (일반, 출장, 회의비 등)
ADD COLUMN IF NOT EXISTS tags TEXT[],              -- 태그 배열
ADD COLUMN IF NOT EXISTS is_independent BOOLEAN DEFAULT FALSE; -- 독립적 업로드 여부

-- 2. 기존 컬럼을 NULL 허용으로 변경 (독립적 업로드 지원)
ALTER TABLE purchase_receipts 
ALTER COLUMN purchase_request_id DROP NOT NULL,
ALTER COLUMN item_id DROP NOT NULL;

-- 3. 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_purchase_receipts_uploaded_by ON purchase_receipts(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_purchase_receipts_category ON purchase_receipts(category);
CREATE INDEX IF NOT EXISTS idx_purchase_receipts_is_independent ON purchase_receipts(is_independent);
CREATE INDEX IF NOT EXISTS idx_purchase_receipts_uploaded_at ON purchase_receipts(uploaded_at);

-- 4. RLS 정책 업데이트 (독립적 영수증도 접근 가능하도록)
-- 기존 정책 제거
DROP POLICY IF EXISTS "Users can view their own receipts" ON purchase_receipts;
DROP POLICY IF EXISTS "Users can upload receipts" ON purchase_receipts;
DROP POLICY IF EXISTS "Users can delete their own receipts" ON purchase_receipts;

-- 새로운 정책 생성
CREATE POLICY "Users can view receipts"
ON purchase_receipts FOR SELECT
USING (
  auth.email() = uploaded_by OR 
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND ('app_admin' = ANY(purchase_role) OR 'lead_buyer' = ANY(purchase_role))
  )
);

CREATE POLICY "Users can upload receipts"
ON purchase_receipts FOR INSERT
WITH CHECK (auth.email() = uploaded_by);

CREATE POLICY "Users can delete their own receipts"
ON purchase_receipts FOR DELETE
USING (
  auth.email() = uploaded_by OR
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND 'app_admin' = ANY(purchase_role)
  )
);

CREATE POLICY "Users can update their own receipts"
ON purchase_receipts FOR UPDATE
USING (
  auth.email() = uploaded_by OR
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email() 
    AND 'app_admin' = ANY(purchase_role)
  )
);

-- 완료 메시지
SELECT 'purchase_receipts 테이블이 독립적인 영수증 시스템으로 확장되었습니다.' as message;