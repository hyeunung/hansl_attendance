-- Add optimistic locking to prevent concurrent receipt processing conflicts

-- Add version column for optimistic locking (if not exists)
ALTER TABLE purchase_request_items 
ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 0;

-- Add index for better performance
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'purchase_request_items'
      AND column_name = 'request_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_purchase_request_items_request_received ON public.purchase_request_items(request_id, is_received)';
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'purchase_request_items'
      AND column_name = 'purchase_request_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_purchase_request_items_request_received ON public.purchase_request_items(purchase_request_id, is_received)';
  END IF;
END
$$;