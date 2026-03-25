-- ====================================================================
-- purchase_request_items 테이블에서 영수증 관련 컬럼 제거
-- 영수증 시스템을 purchase_receipts 테이블로 완전 분리
-- ====================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'purchase_request_items'
  ) THEN
    -- 1. 기존 영수증 관련 컬럼 제거
    EXECUTE '
      ALTER TABLE public.purchase_request_items
      DROP COLUMN IF EXISTS receipt_image_url,
      DROP COLUMN IF EXISTS receipt_uploaded_at,
      DROP COLUMN IF EXISTS receipt_uploaded_by
    ';

    -- 2. 관련 인덱스 제거 (존재하는 경우)
    EXECUTE 'DROP INDEX IF EXISTS public.idx_purchase_request_items_receipt_uploaded_by';
    EXECUTE 'DROP INDEX IF EXISTS public.idx_purchase_request_items_receipt_uploaded_at';
  END IF;
END
$$;

-- 3. 트리거나 함수에서 영수증 관련 로직 제거 (필요시)
-- mark_item_as_received 함수는 그대로 유지 (영수증과 무관하게 입고 처리)

-- 완료 메시지
SELECT '영수증 관련 컬럼이 purchase_request_items 테이블에서 제거되었습니다. 
이제 영수증은 purchase_receipts 테이블에서만 관리됩니다.' as message;
