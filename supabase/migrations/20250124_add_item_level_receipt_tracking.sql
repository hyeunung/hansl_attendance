-- 품목별 입고 상태 추가
ALTER TABLE purchase_request_items 
ADD COLUMN IF NOT EXISTS is_received BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS received_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS received_by TEXT;

-- 기존 데이터 업데이트 (전체 입고 완료된 경우 품목들도 완료 처리)
UPDATE purchase_request_items pri
SET is_received = true,
    received_date = pr.received_date
FROM purchase_requests pr
WHERE pri.request_id = pr.id
AND pr.is_received = true;

-- 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_purchase_request_items_is_received 
ON purchase_request_items(is_received);

-- 품목별 입고 완료 처리 함수
CREATE OR REPLACE FUNCTION mark_item_as_received(
    p_item_id UUID,
    p_user_name TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_request_id UUID;
    v_total_items INT;
    v_received_items INT;
BEGIN
    -- 품목 입고 완료 처리
    UPDATE purchase_request_items
    SET is_received = true,
        received_date = NOW(),
        received_by = p_user_name
    WHERE id = p_item_id
    RETURNING request_id INTO v_request_id;
    
    -- 해당 발주의 전체 품목 수와 입고 완료 품목 수 계산
    SELECT 
        COUNT(*),
        COUNT(CASE WHEN is_received THEN 1 END)
    INTO v_total_items, v_received_items
    FROM purchase_request_items
    WHERE request_id = v_request_id;
    
    -- 모든 품목이 입고 완료되면 발주 전체를 입고 완료로 처리
    IF v_total_items = v_received_items THEN
        UPDATE purchase_requests
        SET is_received = true,
            received_date = NOW()
        WHERE id = v_request_id;
    END IF;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS 정책 추가
ALTER TABLE purchase_request_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view purchase request items"
    ON purchase_request_items FOR SELECT
    USING (true);

CREATE POLICY "Authorized users can update item receipt status"
    ON purchase_request_items FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM employees e
            WHERE e.id = auth.uid()
            AND ('app_admin' = ANY(e.purchase_role) 
                 OR 'lead_buyer' = ANY(e.purchase_role))
        )
        OR EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = purchase_request_items.request_id
            AND pr.requester_email = (SELECT email FROM employees WHERE id = auth.uid())
        )
    );