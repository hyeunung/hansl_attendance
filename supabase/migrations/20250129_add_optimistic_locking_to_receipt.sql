-- Add optimistic locking to prevent concurrent receipt processing conflicts

-- Add version column for optimistic locking (if not exists)
ALTER TABLE purchase_request_items 
ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 0;

-- Create improved function with optimistic locking
CREATE OR REPLACE FUNCTION mark_item_as_received_with_lock(
    p_item_id BIGINT,
    p_user_name TEXT,
    p_expected_version INTEGER DEFAULT 0
) RETURNS JSON AS $$
DECLARE
    v_request_id UUID;
    v_total_items INT;
    v_received_items INT;
    v_current_version INT;
    v_already_received BOOLEAN;
BEGIN
    -- Check current state and version
    SELECT version, is_received, request_id
    INTO v_current_version, v_already_received, v_request_id
    FROM purchase_request_items
    WHERE id = p_item_id
    FOR UPDATE; -- Row-level lock
    
    -- Check if already received
    IF v_already_received THEN
        RETURN json_build_object(
            'success', false,
            'error', 'already_received',
            'message', '이미 입고 처리된 품목입니다'
        );
    END IF;
    
    -- Check version for concurrent modification
    IF v_current_version != p_expected_version THEN
        RETURN json_build_object(
            'success', false,
            'error', 'version_mismatch',
            'message', '다른 사용자가 수정중입니다. 새로고침 후 다시 시도하세요'
        );
    END IF;
    
    -- Update item with version increment
    UPDATE purchase_request_items
    SET is_received = true,
        received_date = NOW(),
        received_by = p_user_name,
        version = version + 1
    WHERE id = p_item_id
    AND version = p_expected_version;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'update_failed',
            'message', '업데이트 실패. 새로고침 후 다시 시도하세요'
        );
    END IF;
    
    -- Calculate total and received items
    SELECT 
        COUNT(*),
        COUNT(CASE WHEN is_received THEN 1 END)
    INTO v_total_items, v_received_items
    FROM purchase_request_items
    WHERE request_id = v_request_id;
    
    -- Update purchase request if all items received
    IF v_total_items = v_received_items THEN
        UPDATE purchase_requests
        SET is_received = true,
            received_date = NOW()
        WHERE id = v_request_id;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'message', '입고 처리 완료',
        'total_items', v_total_items,
        'received_items', v_received_items,
        'all_received', v_total_items = v_received_items
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'exception',
            'message', SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION mark_item_as_received_with_lock(BIGINT, TEXT, INTEGER) TO authenticated;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_purchase_request_items_request_received 
ON purchase_request_items(request_id, is_received);