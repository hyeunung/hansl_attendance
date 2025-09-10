-- 028_remove_remaining_slack_functions.sql
-- 남아있는 슬랙 관련 함수들 제거

-- bigint 파라미터를 가진 함수들 제거
DROP FUNCTION IF EXISTS debug_block_kit_message(bigint) CASCADE;
DROP FUNCTION IF EXISTS send_collapsible_middle_manager_notification(bigint) CASCADE;
DROP FUNCTION IF EXISTS send_improved_middle_manager_notification(bigint) CASCADE;
DROP FUNCTION IF EXISTS send_text_only_middle_manager_notification(bigint) CASCADE;
DROP FUNCTION IF EXISTS send_toggle_middle_manager_notification(bigint) CASCADE;
DROP FUNCTION IF EXISTS test_expanded_notification(bigint) CASCADE;
DROP FUNCTION IF EXISTS test_file_attachment(bigint) CASCADE;
DROP FUNCTION IF EXISTS test_text_toggle(bigint) CASCADE;
DROP FUNCTION IF EXISTS test_toggle_expanded(bigint) CASCADE;

-- integer 파라미터를 가진 함수들 제거
DROP FUNCTION IF EXISTS notify_middle_manager_explicit(integer) CASCADE;
DROP FUNCTION IF EXISTS process_middle_manager_notification_delayed(integer) CASCADE;

-- 완료 메시지
DO $$
BEGIN
    RAISE NOTICE '남아있던 슬랙 관련 함수들이 모두 제거되었습니다.';
END $$;

