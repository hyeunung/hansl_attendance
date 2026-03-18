-- ============================================================================
-- 거래명세서 상태가 확인필요(extracted)로 변경될 때 lead buyer + app_admin 푸시 알림
-- 작성일: 2026-02-02
--
-- 동작:
-- - transaction_statements.status가 'extracted'로 변경되는 순간(UPDATE)에만
--   Edge Function(/functions/v1/send_fcm_notification)을 호출하여
--   purchase_role 기반(lead buyer + app_admin)으로 FCM 푸시를 발송한다.
--
-- 참고:
-- - 기존 INSERT(등록 즉시) 알림 트리거는 제거(비활성화)한다.
-- - 중복 방지: 10초 내 동일 statement_id 알림이 이미 있으면 재발송하지 않음
-- - Edge Function type: transaction_statement_extracted
-- ============================================================================

-- 0) 기존 '등록 즉시' 트리거 제거 (존재 시)
DROP TRIGGER IF EXISTS transaction_statement_created_notification ON transaction_statements;
DROP FUNCTION IF EXISTS send_transaction_statement_created_notification();

-- 1) 확인필요(extracted) 알림 트리거 함수
CREATE OR REPLACE FUNCTION send_transaction_statement_extracted_notification()
RETURNS TRIGGER AS $$
DECLARE
    anon_key TEXT;
    supabase_url TEXT;
    notification_sent BOOLEAN;
BEGIN
    -- status가 extracted로 변경된 경우만 처리
    IF NEW.status IS DISTINCT FROM 'extracted' THEN
        RETURN NEW;
    END IF;

    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW;
    END IF;

    -- 중복 방지 체크 (10초 이내 동일 statement_id)
    SELECT EXISTS(
        SELECT 1 FROM notifications
        WHERE type = 'transaction_statement_extracted'
        AND data->>'statement_id' = NEW.id::text
        AND created_at > NOW() - INTERVAL '10 seconds'
    ) INTO notification_sent;

    IF notification_sent THEN
        RAISE NOTICE 'Transaction statement extracted notification already sent for statement_id=%', NEW.id;
        RETURN NEW;
    END IF;

    -- app_settings에서 필요한 값 가져오기
    SELECT value INTO anon_key FROM app_settings WHERE key = 'supabase_anon_key';
    SELECT value INTO supabase_url FROM app_settings WHERE key = 'supabase_url';

    IF anon_key IS NULL OR supabase_url IS NULL THEN
        RAISE NOTICE 'Missing app_settings for transaction statement extracted notification';
        RETURN NEW;
    END IF;

    -- Edge Function 호출
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
            'type', 'transaction_statement_extracted',
            'skip_db_notification', false,
            'data', jsonb_build_object(
                'statement_id', NEW.id,
                'image_url', NEW.image_url,
                'file_name', NEW.file_name,
                'uploaded_at', NEW.uploaded_at,
                'uploaded_by_name', NEW.uploaded_by_name,
                'vendor_name', NEW.vendor_name,
                'grand_total', NEW.grand_total
            )
        )
    );

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in send_transaction_statement_extracted_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2) 트리거 생성/활성화
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'transaction_statements'
  ) THEN
    DROP TRIGGER IF EXISTS transaction_statement_extracted_notification ON transaction_statements;
    CREATE TRIGGER transaction_statement_extracted_notification
      AFTER UPDATE ON transaction_statements
      FOR EACH ROW
      EXECUTE FUNCTION send_transaction_statement_extracted_notification();

    ALTER TABLE transaction_statements ENABLE TRIGGER transaction_statement_extracted_notification;
    RAISE NOTICE '✅ transaction_statement_extracted_notification trigger enabled';
  ELSE
    RAISE NOTICE '⚠️ transaction_statements table not found; trigger not created';
  END IF;
END $$;

