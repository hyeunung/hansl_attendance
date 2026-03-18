-- ============================================================================
-- 거래명세서 등록(INSERT) 시 lead buyer + app_admin 푸시 알림
-- 작성일: 2026-01-30
--
-- 동작:
-- - transaction_statements에 새 행이 INSERT되면
--   Edge Function(/functions/v1/send_fcm_notification)을 호출하여
--   purchase_role 기반(lead buyer + app_admin)으로 FCM 푸시를 발송한다.
--
-- 참고:
-- - 중복 방지: 10초 내 동일 statement_id 알림이 이미 있으면 재발송하지 않음
-- - Edge Function type: transaction_statement_created
-- ============================================================================

CREATE OR REPLACE FUNCTION send_transaction_statement_created_notification()
RETURNS TRIGGER AS $$
DECLARE
    anon_key TEXT;
    supabase_url TEXT;
    notification_sent BOOLEAN;
BEGIN
    -- 중복 방지 체크 (10초 이내 동일 statement_id)
    SELECT EXISTS(
        SELECT 1 FROM notifications
        WHERE type = 'transaction_statement_created'
        AND data->>'statement_id' = NEW.id::text
        AND created_at > NOW() - INTERVAL '10 seconds'
    ) INTO notification_sent;

    IF notification_sent THEN
        RAISE NOTICE 'Transaction statement notification already sent for statement_id=%', NEW.id;
        RETURN NEW;
    END IF;

    -- app_settings에서 필요한 값 가져오기
    SELECT value INTO anon_key FROM app_settings WHERE key = 'supabase_anon_key';
    SELECT value INTO supabase_url FROM app_settings WHERE key = 'supabase_url';

    IF anon_key IS NULL OR supabase_url IS NULL THEN
        RAISE NOTICE 'Missing app_settings for transaction statement notification';
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
            'type', 'transaction_statement_created',
            'skip_db_notification', false,
            'data', jsonb_build_object(
                'statement_id', NEW.id,
                'image_url', NEW.image_url,
                'file_name', NEW.file_name,
                'uploaded_at', NEW.uploaded_at,
                'uploaded_by_name', NEW.uploaded_by_name
            )
        )
    );

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in send_transaction_statement_created_notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'transaction_statements'
  ) THEN
    DROP TRIGGER IF EXISTS transaction_statement_created_notification ON transaction_statements;
    CREATE TRIGGER transaction_statement_created_notification
      AFTER INSERT ON transaction_statements
      FOR EACH ROW
      EXECUTE FUNCTION send_transaction_statement_created_notification();

    ALTER TABLE transaction_statements ENABLE TRIGGER transaction_statement_created_notification;
    RAISE NOTICE '✅ transaction_statement_created_notification trigger enabled';
  ELSE
    RAISE NOTICE '⚠️ transaction_statements table not found; trigger not created';
  END IF;
END $$;

