-- Fix mark_item_as_received function parameter type
-- The purchase_request_items.id column is BIGINT, not UUID

DROP FUNCTION IF EXISTS mark_item_as_received(UUID, TEXT);

CREATE OR REPLACE FUNCTION mark_item_as_received(
    p_item_id BIGINT,  -- Changed from UUID to BIGINT
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
    
    -- 업데이트된 행이 없으면 FALSE 반환
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
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
        -- 에러 로깅 (선택사항)
        RAISE NOTICE 'Error in mark_item_as_received: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 함수 권한 설정
GRANT EXECUTE ON FUNCTION mark_item_as_received(BIGINT, TEXT) TO authenticated;