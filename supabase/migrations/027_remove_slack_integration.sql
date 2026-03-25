-- 027_remove_slack_integration.sql
-- 슬랙 관련 모든 기능 제거

-- 1. 슬랙 관련 트리거 제거
DO $$
BEGIN
  IF to_regclass('public.purchase_requests') IS NOT NULL THEN
    EXECUTE 'DROP TRIGGER IF EXISTS final_managers_approval_notify_trigger ON public.purchase_requests';
    EXECUTE 'DROP TRIGGER IF EXISTS trigger_lead_buyer_notification_unified ON public.purchase_requests';
    EXECUTE 'DROP TRIGGER IF EXISTS trigger_purchase_request_payment_notification ON public.purchase_requests';
    EXECUTE 'DROP TRIGGER IF EXISTS payment_completion_trigger ON public.purchase_requests';
  END IF;
END
$$;

-- 2. 슬랙 관련 함수 제거 (CASCADE 추가)
DROP FUNCTION IF EXISTS process_middle_manager_notification_delayed(UUID) CASCADE;
DROP FUNCTION IF EXISTS notify_middle_manager_explicit(UUID) CASCADE;
DROP FUNCTION IF EXISTS on_purchase_request_item_insert() CASCADE;
DROP FUNCTION IF EXISTS notify_middle_manager_on_last_item_insert() CASCADE;
DROP FUNCTION IF EXISTS notify_purchase_request_payment() CASCADE;
DROP FUNCTION IF EXISTS notify_final_managers_on_approval() CASCADE;
DROP FUNCTION IF EXISTS notify_lead_buyer_unified() CASCADE;
DROP FUNCTION IF EXISTS test_expanded_notification(UUID) CASCADE;
DROP FUNCTION IF EXISTS send_improved_middle_manager_notification(UUID) CASCADE;
DROP FUNCTION IF EXISTS test_simple_block_kit() CASCADE;
DROP FUNCTION IF EXISTS test_minimal_block_kit() CASCADE;
DROP FUNCTION IF EXISTS test_simple_notification() CASCADE;
DROP FUNCTION IF EXISTS debug_block_kit_message(UUID) CASCADE;
DROP FUNCTION IF EXISTS test_real_file_attachment() CASCADE;
DROP FUNCTION IF EXISTS test_file_attachment(UUID) CASCADE;
DROP FUNCTION IF EXISTS test_text_toggle(UUID) CASCADE;
DROP FUNCTION IF EXISTS send_attachment_middle_manager_notification() CASCADE;
DROP FUNCTION IF EXISTS send_collapsible_middle_manager_notification(UUID) CASCADE;
DROP FUNCTION IF EXISTS send_file_attachment_notification(TEXT) CASCADE;
DROP FUNCTION IF EXISTS send_payment_completion_notifications() CASCADE;
DROP FUNCTION IF EXISTS send_text_only_middle_manager_notification(UUID) CASCADE;
DROP FUNCTION IF EXISTS send_toggle_middle_manager_notification(UUID) CASCADE;
DROP FUNCTION IF EXISTS test_real_block_kit() CASCADE;
DROP FUNCTION IF EXISTS test_real_block_kit_builder() CASCADE;
DROP FUNCTION IF EXISTS test_toggle_expanded(UUID) CASCADE;

-- 3. employees 테이블에서 slack_id 컬럼 제거 (있다면)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employees' 
        AND column_name = 'slack_id'
    ) THEN
        ALTER TABLE employees DROP COLUMN slack_id;
    END IF;
END $$;

-- 4. 슬랙 관련 Edge Functions 제거 (만약 DB에 저장된 것이 있다면)
-- functions 테이블이 존재하지 않으므로 건너뜀

-- 5. 슬랙 관련 환경변수나 설정이 DB에 저장되어 있다면 제거
-- app_settings 테이블이 존재하지 않으므로 건너뜀

-- 6. http_post_wrapper 함수가 슬랙 전용이었다면 제거
DROP FUNCTION IF EXISTS http_post_wrapper(TEXT, JSONB, TEXT);

-- 7. 통지 관련 함수 중 슬랙을 참조하는 것들 확인 및 제거
-- notify_purchase_status_change 함수 확인
DROP FUNCTION IF EXISTS notify_purchase_status_change() CASCADE;

-- 8. 관련 트리거 제거 (CASCADE로 인해 이미 제거되었을 수 있음)
DO $$
BEGIN
  IF to_regclass('public.purchase_requests') IS NOT NULL THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trigger_notify_purchase_status ON public.purchase_requests';
  END IF;
END
$$;

-- 완료 메시지
DO $$
BEGIN
    RAISE NOTICE '슬랙 통합 관련 모든 요소가 성공적으로 제거되었습니다.';
END $$;
