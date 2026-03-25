-- ================================================================
-- 2차 마이그레이션: roles 통합 칼럼 완전 전환
-- 통합 권한 체계(roles/superadmin)로 전환
-- ================================================================

-- ============================================================
-- 1. RLS 정책 업데이트
-- ============================================================

-- 1-1. purchase_receipts 테이블 (3개 정책)
DROP POLICY IF EXISTS "Users can view receipts" ON purchase_receipts;
DROP POLICY IF EXISTS "Users can delete their own receipts" ON purchase_receipts;
DROP POLICY IF EXISTS "Users can update their own receipts" ON purchase_receipts;

CREATE POLICY "Users can view receipts"
ON purchase_receipts FOR SELECT
USING (
  auth.email() = uploaded_by OR
  EXISTS (
    SELECT 1 FROM employees
    WHERE email = auth.email()
    AND ('superadmin' = ANY(roles) OR 'lead_buyer' = ANY(roles))
  )
);

CREATE POLICY "Users can delete their own receipts"
ON purchase_receipts FOR DELETE
USING (
  auth.email() = uploaded_by OR
  EXISTS (
    SELECT 1 FROM employees
    WHERE email = auth.email()
    AND 'superadmin' = ANY(roles)
  )
);

CREATE POLICY "Users can update their own receipts"
ON purchase_receipts FOR UPDATE
USING (
  auth.email() = uploaded_by OR
  EXISTS (
    SELECT 1 FROM employees
    WHERE email = auth.email()
    AND 'superadmin' = ANY(roles)
  )
);

-- 1-2. support_inquires 테이블 (3개 정책 - 20251027 버전 대체)
DROP POLICY IF EXISTS "select_inquiries_policy" ON support_inquires;
DROP POLICY IF EXISTS "insert_inquiries_policy" ON support_inquires;
DROP POLICY IF EXISTS "update_inquiries_policy" ON support_inquires;
DROP POLICY IF EXISTS "delete_inquiries_policy" ON support_inquires;
-- 구버전 정책도 정리
DROP POLICY IF EXISTS "Users can view inquiries" ON support_inquires;
DROP POLICY IF EXISTS "Authenticated users can create inquiries" ON support_inquires;
DROP POLICY IF EXISTS "App admins can update inquiries" ON support_inquires;
DROP POLICY IF EXISTS "Users can delete their own inquiries" ON support_inquires;

CREATE POLICY "select_inquiries_policy" ON support_inquires FOR SELECT USING (
  auth.uid() = user_id
  OR auth.uid() = requester_id
  OR EXISTS (
    SELECT 1 FROM employees
    WHERE employees.email = auth.email()
      AND 'superadmin' = ANY(employees.roles)
  )
);

-- INSERT 정책: superadmin이 아닌 사용자만 문의 작성 가능
CREATE POLICY "insert_inquiries_policy" ON support_inquires FOR INSERT
WITH CHECK (
    NOT EXISTS (
        SELECT 1 FROM employees e
        WHERE e.email = auth.email()
        AND 'superadmin' = ANY(e.roles)
    )
);

CREATE POLICY "update_inquiries_policy" ON support_inquires FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM employees
    WHERE employees.email = auth.email()
      AND 'superadmin' = ANY(employees.roles)
  )
);

CREATE POLICY "delete_inquiries_policy" ON support_inquires FOR DELETE USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM employees
    WHERE employees.email = auth.email()
      AND 'superadmin' = ANY(employees.roles)
  )
);

-- 1-3. holidays 테이블
DROP POLICY IF EXISTS "Only admins can manage holidays" ON public.holidays;

CREATE POLICY "Only admins can manage holidays" ON public.holidays
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.employees
            WHERE employees.email = auth.jwt() ->> 'email'
            AND 'admin' = ANY(employees.roles)
        )
    );

-- 1-4. monthly_attendance 테이블
DROP POLICY IF EXISTS "monthly_attendance_select_admin" ON monthly_attendance;

CREATE POLICY "monthly_attendance_select_admin" ON monthly_attendance FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM employees
    WHERE email = auth.email()
    AND 'admin' = ANY(roles)
  ));

-- 1-5. audit_logs, leave_requests 테이블은 현재 DB에 존재하지 않으므로 생략

-- ============================================================
-- 2. 트리거 함수 업데이트
-- ============================================================

-- 2-1. notify_purchase_status_change() — 통합 권한 체계 반영
CREATE OR REPLACE FUNCTION notify_purchase_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_total_amount numeric;
  v_requester_name text;
  v_requester_email text;
  v_payment_category text;
  v_target_roles text[];
  v_notification_title text;
  v_notification_body text;
  v_notification_type text;
  v_user record;
  v_fcm_tokens text[];
  v_rejection_reason text;
BEGIN
  -- 발주 정보 가져오기
  v_requester_name := NEW.requester_name;
  v_payment_category := NEW.payment_category;
  v_requester_email := NEW.requester_email;

  -- 총 금액 계산
  SELECT COALESCE(SUM(amount_value), 0) INTO v_total_amount
  FROM purchase_request_items
  WHERE purchase_order_number = NEW.purchase_order_number;

  -- Case 1: 신규 발주 요청 (INSERT 시) - 1차 승인자에게
  IF TG_OP = 'INSERT' AND NEW.middle_manager_status = 'pending' THEN
    v_target_roles := ARRAY['middle_manager'];
    v_notification_title := '🆕 새 발주 승인 요청';
    v_notification_body := format('%s님이 %s 발주(%s)를 요청했습니다. 금액: %s원',
      v_requester_name,
      v_payment_category,
      NEW.purchase_order_number,
      to_char(v_total_amount, 'FM999,999,999')
    );
    v_notification_type := 'purchase_request';

  -- Case 2: 1차 승인 완료 -> payment_category에 따른 최종 승인자에게
  ELSIF TG_OP = 'UPDATE' AND
        NEW.middle_manager_status = 'approved' AND
        OLD.middle_manager_status = 'pending' THEN
    -- payment_category에 따라 대상 역할 결정
    IF v_payment_category = '발주' THEN
      v_target_roles := ARRAY['raw_material_manager', 'superadmin'];
    ELSIF v_payment_category IN ('구매 요청', '구매요청') THEN
      v_target_roles := ARRAY['consumable_manager', 'superadmin'];
    ELSE -- 기타
      v_target_roles := ARRAY['final_manager', 'superadmin'];
    END IF;

    v_notification_title := '🔍 최종 발주 승인 요청';
    v_notification_body := format('%s님의 %s(%s)가 1차 승인되었습니다. 최종 승인이 필요합니다.',
      v_requester_name,
      v_payment_category,
      NEW.purchase_order_number
    );
    v_notification_type := 'final_approval_request';

  -- Case 3: 최종 승인 완료 시 알림들
  ELSIF TG_OP = 'UPDATE' AND
        ((v_payment_category = '발주' AND NEW.raw_material_manager_status = 'approved' AND OLD.raw_material_manager_status IN ('pending', NULL)) OR
         (v_payment_category IN ('구매 요청', '구매요청') AND NEW.consumable_manager_status = 'approved' AND OLD.consumable_manager_status IN ('pending', NULL)) OR
         (v_payment_category NOT IN ('발주', '구매 요청', '구매요청') AND NEW.final_manager_status = 'approved' AND OLD.final_manager_status IN ('pending', NULL))) THEN

    -- 3-1: 신청자에게 승인 완료 알림
    IF v_requester_email IS NOT NULL THEN
      SELECT fcm_token INTO v_user.fcm_token
      FROM employees
      WHERE email = v_requester_email
        AND fcm_token IS NOT NULL
        AND fcm_token != '';

      IF v_user.fcm_token IS NOT NULL THEN
        PERFORM net.http_post(
          url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
          ),
          body := jsonb_build_object(
            'type', 'custom',
            'title', '✅ 발주 승인 완료',
            'body', format('발주 요청(%s)이 최종 승인되었습니다.', NEW.purchase_order_number),
            'data', jsonb_build_object(
              'type', 'purchase_approved',
              'purchase_order_number', NEW.purchase_order_number,
              'payment_category', v_payment_category
            ),
            'user_email', v_requester_email,
            'fcm_tokens', ARRAY[v_user.fcm_token],
            'skip_db_notification', true
          )::jsonb
        );
      END IF;
    END IF;

    -- 3-2: Lead Buyer에게 구매대기 알림
    IF v_payment_category IN ('구매 요청', '구매요청') AND
       NEW.is_payment_completed = false AND
       (NEW.progress_type ILIKE '%선진행%' OR
        (NEW.progress_type ILIKE '%일반%' AND
         (NEW.consumable_manager_status = 'approved' OR NEW.final_manager_status = 'approved'))) THEN

      v_notification_title := '🛒 새로운 구매대기 항목';
      v_notification_body := format('%s님의 구매 요청(%s)이 구매대기 목록에 추가되었습니다.',
          v_requester_name,
          NEW.purchase_order_number
      );

      SELECT ARRAY_AGG(fcm_token) INTO v_fcm_tokens
      FROM employees
      WHERE 'lead buyer' = ANY(roles)
        AND fcm_token IS NOT NULL
        AND fcm_token != '';

      IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
        PERFORM net.http_post(
          url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
          ),
          body := jsonb_build_object(
            'type', 'custom',
            'title', v_notification_title,
            'body', v_notification_body,
            'data', jsonb_build_object(
              'type', 'purchase_request',
              'purchase_order_number', NEW.purchase_order_number,
              'payment_category', v_payment_category,
              'requester_name', v_requester_name
            ),
            'fcm_tokens', v_fcm_tokens
          )::jsonb
        );
      END IF;
    END IF;

    RETURN NEW;

  -- Case 4: 선진행 구매 요청 생성 시 Lead Buyer에게 즉시 알림
  ELSIF TG_OP = 'INSERT' AND
        v_payment_category IN ('구매 요청', '구매요청') AND
        NEW.is_payment_completed = false AND
        NEW.progress_type ILIKE '%선진행%' THEN

    -- Lead Buyer들의 FCM 토큰 수집
    SELECT ARRAY_AGG(fcm_token) INTO v_fcm_tokens
    FROM employees
    WHERE 'lead buyer' = ANY(roles)
      AND fcm_token IS NOT NULL
      AND fcm_token != '';

    IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
      PERFORM net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
        ),
        body := jsonb_build_object(
          'type', 'custom',
          'title', '🛒 [선진행] 새로운 구매대기 항목',
          'body', format('%s님의 선진행 구매 요청(%s)이 구매대기 목록에 추가되었습니다.',
            v_requester_name,
            NEW.purchase_order_number
          ),
          'data', jsonb_build_object(
            'type', 'purchase_request',
            'purchase_order_number', NEW.purchase_order_number,
            'payment_category', v_payment_category,
            'requester_name', v_requester_name,
            'progress_type', NEW.progress_type
          ),
          'fcm_tokens', v_fcm_tokens
        )::jsonb
      );
    END IF;

    -- 선진행도 1차 승인자에게는 알림
    v_target_roles := ARRAY['middle_manager'];
    v_notification_title := '🆕 [선진행] 새 발주 승인 요청';
    v_notification_body := format('%s님이 선진행 %s(%s)를 요청했습니다. 금액: %s원',
      v_requester_name,
      v_payment_category,
      NEW.purchase_order_number,
      to_char(v_total_amount, 'FM999,999,999')
    );
    v_notification_type := 'new_purchase_request';

  -- Case 5: 1차 반려 (middle_manager가 반려)
  ELSIF TG_OP = 'UPDATE' AND
        NEW.middle_manager_status = 'rejected' AND
        OLD.middle_manager_status = 'pending' THEN

    v_rejection_reason := COALESCE(NEW.middle_manager_comment, NEW.middle_manager_rejection_reason, '사유 없음');

    IF v_requester_email IS NOT NULL THEN
      SELECT fcm_token INTO v_user.fcm_token
      FROM employees
      WHERE email = v_requester_email
        AND fcm_token IS NOT NULL
        AND fcm_token != '';

      IF v_user.fcm_token IS NOT NULL THEN
        PERFORM net.http_post(
          url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
          ),
          body := jsonb_build_object(
            'type', 'custom',
            'title', '❌ 발주 반려',
            'body', format('발주 요청(%s)이 1차 승인에서 반려되었습니다. 사유: %s',
              NEW.purchase_order_number,
              v_rejection_reason
            ),
            'data', jsonb_build_object(
              'type', 'purchase_rejected',
              'purchase_order_number', NEW.purchase_order_number,
              'payment_category', v_payment_category,
              'rejection_reason', v_rejection_reason,
              'rejected_by', 'middle_manager'
            ),
            'user_email', v_requester_email,
            'fcm_tokens', ARRAY[v_user.fcm_token]
          )::jsonb
        );
      END IF;
    END IF;

    RETURN NEW;

  -- Case 6: 최종 반려
  ELSIF TG_OP = 'UPDATE' AND
        ((v_payment_category = '발주' AND NEW.raw_material_manager_status = 'rejected' AND OLD.raw_material_manager_status IN ('pending', NULL)) OR
         (v_payment_category IN ('구매 요청', '구매요청') AND NEW.consumable_manager_status = 'rejected' AND OLD.consumable_manager_status IN ('pending', NULL)) OR
         (v_payment_category NOT IN ('발주', '구매 요청', '구매요청') AND NEW.final_manager_status = 'rejected' AND OLD.final_manager_status IN ('pending', NULL))) THEN

    IF v_payment_category = '발주' THEN
      v_rejection_reason := COALESCE(NEW.raw_material_manager_rejection_reason, '사유 없음');
    ELSIF v_payment_category IN ('구매 요청', '구매요청') THEN
      v_rejection_reason := COALESCE(NEW.consumable_manager_rejection_reason, '사유 없음');
    ELSE
      v_rejection_reason := COALESCE(NEW.final_manager_rejection_reason, '사유 없음');
    END IF;

    IF v_requester_email IS NOT NULL THEN
      SELECT fcm_token INTO v_user.fcm_token
      FROM employees
      WHERE email = v_requester_email
        AND fcm_token IS NOT NULL
        AND fcm_token != '';

      IF v_user.fcm_token IS NOT NULL THEN
        PERFORM net.http_post(
          url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
          ),
          body := jsonb_build_object(
            'type', 'custom',
            'title', '❌ 발주 최종 반려',
            'body', format('발주 요청(%s)이 최종 승인에서 반려되었습니다. 사유: %s',
              NEW.purchase_order_number,
              v_rejection_reason
            ),
            'data', jsonb_build_object(
              'type', 'purchase_rejected',
              'purchase_order_number', NEW.purchase_order_number,
              'payment_category', v_payment_category,
              'rejection_reason', v_rejection_reason,
              'rejected_by', CASE
                WHEN v_payment_category = '발주' THEN 'raw_material_manager'
                WHEN v_payment_category IN ('구매 요청', '구매요청') THEN 'consumable_manager'
                ELSE 'final_manager'
              END
            ),
            'user_email', v_requester_email,
            'fcm_tokens', ARRAY[v_user.fcm_token]
          )::jsonb
        );
      END IF;
    END IF;

    RETURN NEW;

  ELSE
    RETURN NEW;
  END IF;

  -- 대상 역할이 설정된 경우 알림 전송
  IF v_target_roles IS NOT NULL THEN
    SELECT ARRAY_AGG(fcm_token) INTO v_fcm_tokens
    FROM employees e
    WHERE e.roles && v_target_roles
      AND e.fcm_token IS NOT NULL
      AND e.fcm_token != '';

    IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
      PERFORM net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
        ),
        body := jsonb_build_object(
          'type', 'admin',
          'title', v_notification_title,
          'body', v_notification_body,
          'data', jsonb_build_object(
            'type', v_notification_type,
            'purchase_order_number', NEW.purchase_order_number,
            'requester_name', v_requester_name,
            'payment_category', v_payment_category
          ),
          'fcm_tokens', v_fcm_tokens
        )::jsonb
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION notify_purchase_status_change() IS '발주/구매 요청의 모든 상태 변경 알림을 처리하는 통합 함수 (roles 통합 칼럼 사용)';

-- 2-2. notify_inquiry_status_change() — 통합 권한 체계 반영
CREATE OR REPLACE FUNCTION notify_inquiry_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_supabase_url text;
  v_service_key text;
  v_admin_tokens text[];
  v_inquiry_id text;
  v_user_name text;
  v_title text;
  v_status text;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
    SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';

    v_inquiry_id := NEW.id::text;
    v_user_name := NEW.user_name;
    v_title := NEW.title;
    v_status := NEW.status;

    -- superadmin 권한을 가진 사용자들의 FCM 토큰 조회
    SELECT ARRAY_AGG(DISTINCT fcm_token) INTO v_admin_tokens
    FROM employees
    WHERE 'superadmin' = ANY(roles)
    AND fcm_token IS NOT NULL
    AND fcm_token != '';

    IF array_length(v_admin_tokens, 1) > 0 THEN
      PERFORM net.http_post(
        url := v_supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || v_service_key,
          'Content-Type', 'application/json'
        )::jsonb,
        body := jsonb_build_object(
          'type', 'admin',
          'title', '📝 문의사항 상태 변경',
          'body', format('%s님의 문의사항이 %s 상태로 변경되었습니다.', v_user_name, v_status),
          'fcm_tokens', v_admin_tokens,
          'data', jsonb_build_object(
            'type', 'inquiry_status_change',
            'inquiry_id', v_inquiry_id,
            'user_name', v_user_name,
            'title', v_title,
            'status', v_status
          ),
          'skip_db_notification', true
        )::jsonb
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2-3. notify_new_inquiry_to_admins() — 통합 권한 체계 반영
CREATE OR REPLACE FUNCTION notify_new_inquiry_to_admins()
RETURNS TRIGGER AS $$
DECLARE
  v_supabase_url text;
  v_service_key text;
  v_admin_tokens text[];
  v_inquiry_id text;
  v_user_name text;
  v_title text;
  v_content text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
    SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';

    v_inquiry_id := NEW.id::text;
    v_user_name := NEW.user_name;
    v_title := NEW.title;
    v_content := LEFT(NEW.content, 100);

    -- superadmin 권한을 가진 사용자들의 FCM 토큰 조회
    SELECT ARRAY_AGG(DISTINCT fcm_token) INTO v_admin_tokens
    FROM employees
    WHERE 'superadmin' = ANY(roles)
    AND fcm_token IS NOT NULL
    AND fcm_token != '';

    IF array_length(v_admin_tokens, 1) > 0 THEN
      PERFORM net.http_post(
        url := v_supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || v_service_key,
          'Content-Type', 'application/json'
        )::jsonb,
        body := jsonb_build_object(
          'type', 'admin',
          'title', '🆕 새로운 문의사항',
          'body', format('%s님이 새로운 문의사항을 등록했습니다: %s', v_user_name, v_title),
          'fcm_tokens', v_admin_tokens,
          'data', jsonb_build_object(
            'type', 'new_inquiry',
            'inquiry_id', v_inquiry_id,
            'user_name', v_user_name,
            'title', v_title,
            'content', v_content
          ),
          'skip_db_notification', true
        )::jsonb
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 3. 웹앱 RLS 정책 업데이트 (통합 권한 체계)
-- ============================================================

-- 3-1. leave 테이블 (공가 제한 정책)
DROP POLICY IF EXISTS "leave_restrict_gongga_select" ON "leave";
DROP POLICY IF EXISTS "leave_restrict_gongga_update" ON "leave";

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'leave' AND policyname = 'leave_restrict_gongga_select'
  ) THEN
    CREATE POLICY leave_restrict_gongga_select
      ON public."leave"
      AS RESTRICTIVE
      FOR SELECT
      TO public
      USING (
        NOT (
          COALESCE(type, '') ILIKE '%공가%'
          OR COALESCE(reason, '') ILIKE '%공가%'
        )
        OR EXISTS (
          SELECT 1 FROM public.employees e
          WHERE e.email = auth.email()
            AND 'superadmin' = ANY(COALESCE(e.roles, ARRAY[]::text[]))
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'leave' AND policyname = 'leave_restrict_gongga_update'
  ) THEN
    CREATE POLICY leave_restrict_gongga_update
      ON public."leave"
      AS RESTRICTIVE
      FOR UPDATE
      TO public
      USING (
        NOT (
          COALESCE(type, '') ILIKE '%공가%'
          OR COALESCE(reason, '') ILIKE '%공가%'
        )
        OR EXISTS (
          SELECT 1 FROM public.employees e
          WHERE e.email = auth.email()
            AND 'superadmin' = ANY(COALESCE(e.roles, ARRAY[]::text[]))
        )
      )
      WITH CHECK (
        NOT (
          COALESCE(type, '') ILIKE '%공가%'
          OR COALESCE(reason, '') ILIKE '%공가%'
        )
        OR EXISTS (
          SELECT 1 FROM public.employees e
          WHERE e.email = auth.email()
            AND 'superadmin' = ANY(COALESCE(e.roles, ARRAY[]::text[]))
        )
      );
  END IF;
END $$;

-- 3-2. support_inquiry_messages 테이블 (SELECT, INSERT admin, DELETE)
DROP POLICY IF EXISTS "select_support_inquiry_messages" ON support_inquiry_messages;
DROP POLICY IF EXISTS "insert_support_inquiry_messages_admin" ON support_inquiry_messages;
DROP POLICY IF EXISTS "delete_support_inquiry_messages" ON support_inquiry_messages;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='support_inquiry_messages' AND policyname='select_support_inquiry_messages'
  ) THEN
    CREATE POLICY select_support_inquiry_messages
      ON public.support_inquiry_messages
      FOR SELECT
      TO public
      USING (
        auth.email() = (SELECT si.user_email FROM public.support_inquires si WHERE si.id = inquiry_id)
        OR EXISTS (
          SELECT 1 FROM public.employees e
          WHERE e.email = auth.email()
            AND 'superadmin' = ANY(e.roles)
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='support_inquiry_messages' AND policyname='insert_support_inquiry_messages_admin'
  ) THEN
    CREATE POLICY insert_support_inquiry_messages_admin
      ON public.support_inquiry_messages
      FOR INSERT
      TO public
      WITH CHECK (
        sender_role = 'admin'
        AND sender_email = auth.email()
        AND EXISTS (
          SELECT 1 FROM public.employees e
          WHERE e.email = auth.email()
            AND 'superadmin' = ANY(e.roles)
        )
        AND (SELECT si.status FROM public.support_inquires si WHERE si.id = inquiry_id) NOT IN ('resolved','closed')
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='support_inquiry_messages' AND policyname='delete_support_inquiry_messages'
  ) THEN
    CREATE POLICY delete_support_inquiry_messages
      ON public.support_inquiry_messages
      FOR DELETE
      TO public
      USING (
        EXISTS (
          SELECT 1 FROM public.employees e
          WHERE e.email = auth.email()
            AND 'superadmin' = ANY(e.roles)
        )
      );
  END IF;
END $$;

-- 3-3. support_inquires 테이블 DELETE 정책 (웹앱 추가분)
DROP POLICY IF EXISTS "delete_support_inquires" ON support_inquires;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='support_inquires' AND policyname='delete_support_inquires'
  ) THEN
    CREATE POLICY delete_support_inquires
      ON public.support_inquires
      FOR DELETE
      TO public
      USING (
        auth.uid() = user_id
        OR EXISTS (
          SELECT 1 FROM public.employees e
          WHERE e.email = auth.email()
            AND 'superadmin' = ANY(e.roles)
        )
      );
  END IF;
END $$;

-- ============================================================
-- 4. 웹앱 트리거 함수 업데이트
-- ============================================================

-- 4-1. handle_support_inquiry_message_insert() — 통합 권한 체계 반영
CREATE OR REPLACE FUNCTION public.handle_support_inquiry_message_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_key TEXT;
  v_user_email TEXT;
  v_user_name TEXT;
  v_subject TEXT;
  v_status TEXT;
  v_admin RECORD;
  v_title TEXT;
  v_body TEXT;
BEGIN
  SELECT value INTO v_supabase_url FROM public.app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_service_key FROM public.app_settings WHERE key = 'supabase_service_role_key';

  IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT si.user_email, si.user_name, si.subject, si.status
    INTO v_user_email, v_user_name, v_subject, v_status
  FROM public.support_inquires si
  WHERE si.id = NEW.inquiry_id;

  IF NEW.sender_role = 'admin' THEN
    IF v_status = 'open' THEN
      UPDATE public.support_inquires
      SET status = 'in_progress',
          handled_by = COALESCE(handled_by, NEW.sender_email)
      WHERE id = NEW.inquiry_id;
    END IF;

    v_title := '문의 답변이 도착했습니다';
    v_body := LEFT(COALESCE(NEW.message,''), 120);

    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send_fcm_notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_key
      ),
      body := jsonb_build_object(
        'type', 'inquiry_message',
        'targetEmail', v_user_email,
        'title', v_title,
        'body', v_body,
        'data', jsonb_build_object(
          'type', 'inquiry_message',
          'inquiryId', NEW.inquiry_id::text,
          'messageId', NEW.id::text,
          'senderRole', NEW.sender_role,
          'senderEmail', NEW.sender_email
        ),
        'skip_db_notification', false
      )
    );

  ELSIF NEW.sender_role = 'user' THEN
    v_title := '문의에 새 메시지가 있습니다';

    FOR v_admin IN
      SELECT e.email
      FROM public.employees e
      WHERE 'superadmin' = ANY(e.roles)
        AND e.email IS NOT NULL
        AND e.email <> ''
    LOOP
      PERFORM net.http_post(
        url := v_supabase_url || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_service_key
        ),
        body := jsonb_build_object(
          'type', 'inquiry_message',
          'targetEmail', v_admin.email,
          'title', v_title,
          'body', format('[%s] %s', COALESCE(v_user_name, ''), LEFT(COALESCE(NEW.message,''), 120)),
          'data', jsonb_build_object(
            'type', 'inquiry_message',
            'inquiryId', NEW.inquiry_id::text,
            'messageId', NEW.id::text,
            'senderRole', NEW.sender_role,
            'senderEmail', NEW.sender_email
          ),
          'skip_db_notification', false
        )
      );
    END LOOP;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- 4-2. resolve_inquiry() — 통합 권한 체계 반영
CREATE OR REPLACE FUNCTION public.resolve_inquiry(p_inquiry_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_key TEXT;
  v_user_email TEXT;
  v_inquiry_type TEXT;
  v_payload JSONB;
  v_request_id BIGINT;
  v_is_admin BOOLEAN;
  v_msg_id BIGINT;
  v_item JSONB;
  v_item_id BIGINT;
  v_new_qty NUMERIC;
  v_new_price NUMERIC;
  v_new_amount NUMERIC;
  v_change_type TEXT;
  v_requested_date TEXT;
BEGIN
  -- 권한 체크: superadmin (roles 통합 칼럼)
  SELECT EXISTS(
    SELECT 1 FROM public.employees e
    WHERE e.email = auth.email()
      AND 'superadmin' = ANY(e.roles)
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT si.user_email, si.inquiry_type, si.inquiry_payload, si.purchase_request_id
    INTO v_user_email, v_inquiry_type, v_payload, v_request_id
  FROM public.support_inquires si
  WHERE si.id = p_inquiry_id;

  IF v_user_email IS NULL THEN
    RAISE EXCEPTION 'inquiry not found';
  END IF;

  v_payload := COALESCE(v_payload, '{}'::jsonb);

  IF v_inquiry_type = 'delivery_date_change' THEN
    IF v_request_id IS NULL THEN RAISE EXCEPTION 'purchase_request_id missing'; END IF;
    v_requested_date := v_payload->>'requested_date';
    IF v_requested_date IS NULL OR v_requested_date = '' THEN RAISE EXCEPTION 'requested_date missing'; END IF;
    UPDATE public.purchase_requests
    SET revised_delivery_request_date = v_requested_date::date,
        delivery_revision_requested = TRUE,
        delivery_revision_requested_at = now(),
        delivery_revision_requested_by = auth.email(),
        updated_at = now()
    WHERE id = v_request_id;

  ELSIF v_inquiry_type = 'quantity_change' THEN
    IF v_request_id IS NULL THEN RAISE EXCEPTION 'purchase_request_id missing'; END IF;
    IF jsonb_array_length(COALESCE(v_payload->'items', '[]'::jsonb)) = 0 THEN RAISE EXCEPTION 'items missing'; END IF;
    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(v_payload->'items', '[]'::jsonb))
    LOOP
      v_item_id := (v_item->>'item_id')::bigint;
      v_new_qty := (v_item->>'new_quantity')::numeric;
      IF v_item_id IS NULL OR v_new_qty IS NULL THEN CONTINUE; END IF;
      UPDATE public.purchase_request_items
      SET quantity = v_new_qty, amount_value = COALESCE(unit_price_value, 0) * v_new_qty, updated_at = now()
      WHERE id = v_item_id AND purchase_request_id = v_request_id;
    END LOOP;
    UPDATE public.purchase_requests
    SET total_amount = COALESCE((SELECT SUM(amount_value) FROM public.purchase_request_items WHERE purchase_request_id = v_request_id), 0), updated_at = now()
    WHERE id = v_request_id;

  ELSIF v_inquiry_type = 'price_change' THEN
    IF v_request_id IS NULL THEN RAISE EXCEPTION 'purchase_request_id missing'; END IF;
    IF jsonb_array_length(COALESCE(v_payload->'items', '[]'::jsonb)) = 0 THEN RAISE EXCEPTION 'items missing'; END IF;
    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(v_payload->'items', '[]'::jsonb))
    LOOP
      v_item_id := (v_item->>'item_id')::bigint;
      v_change_type := COALESCE(v_item->>'change_type', 'unit_price');
      IF v_change_type = 'amount' THEN
        v_new_amount := (v_item->>'new_amount')::numeric;
        IF v_item_id IS NULL OR v_new_amount IS NULL THEN CONTINUE; END IF;
        UPDATE public.purchase_request_items
        SET amount_value = v_new_amount,
            unit_price_value = CASE WHEN COALESCE(quantity, 0) > 0 THEN v_new_amount / quantity ELSE unit_price_value END,
            updated_at = now()
        WHERE id = v_item_id AND purchase_request_id = v_request_id;
      ELSE
        v_new_price := (v_item->>'new_unit_price')::numeric;
        IF v_item_id IS NULL OR v_new_price IS NULL THEN CONTINUE; END IF;
        UPDATE public.purchase_request_items
        SET unit_price_value = v_new_price, amount_value = COALESCE(quantity, 0) * v_new_price, updated_at = now()
        WHERE id = v_item_id AND purchase_request_id = v_request_id;
      END IF;
    END LOOP;
    UPDATE public.purchase_requests
    SET total_amount = COALESCE((SELECT SUM(amount_value) FROM public.purchase_request_items WHERE purchase_request_id = v_request_id), 0), updated_at = now()
    WHERE id = v_request_id;

  ELSIF v_inquiry_type = 'delete' THEN
    IF v_request_id IS NULL THEN RAISE EXCEPTION 'purchase_request_id missing'; END IF;
    UPDATE public.support_inquires SET purchase_request_id = NULL WHERE purchase_request_id = v_request_id;
    DELETE FROM public.purchase_request_items WHERE purchase_request_id = v_request_id;
    DELETE FROM public.purchase_requests WHERE id = v_request_id;
  END IF;

  UPDATE public.support_inquires SET status = 'resolved', processed_at = now() WHERE id = p_inquiry_id;

  INSERT INTO public.support_inquiry_messages(inquiry_id, sender_role, sender_email, message, attachments)
  VALUES (p_inquiry_id, 'system', 'system', '완료되었습니다', '[]'::jsonb)
  RETURNING id INTO v_msg_id;

  SELECT value INTO v_supabase_url FROM public.app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_service_key FROM public.app_settings WHERE key = 'supabase_service_role_key';

  IF v_supabase_url IS NOT NULL AND v_service_key IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send_fcm_notification',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_service_key),
      body := jsonb_build_object(
        'type', 'inquiry_resolved', 'targetEmail', v_user_email,
        'title', '문의가 완료 처리되었습니다', 'body', '완료되었습니다',
        'data', jsonb_build_object('type', 'inquiry_resolved', 'inquiryId', p_inquiry_id::text, 'messageId', v_msg_id::text),
        'skip_db_notification', false
      )
    );
  END IF;
END;
$$;

-- ============================================================
-- 5. RLS 정책 업데이트
-- ============================================================
DROP POLICY IF EXISTS attendance_update_policy ON attendance_records;
CREATE POLICY attendance_update_policy ON attendance_records FOR UPDATE USING (
  employee_id IN (SELECT id::text FROM employees WHERE email = auth.email())
  OR EXISTS (SELECT 1 FROM employees e WHERE e.email = auth.email() AND 'admin' = ANY(COALESCE(e.roles, ARRAY[]::text[])))
);

DROP POLICY IF EXISTS leave_delete_policy ON "leave";
CREATE POLICY leave_delete_policy ON "leave" FOR DELETE USING (
  EXISTS (SELECT 1 FROM employees e WHERE e.email = auth.email() AND 'admin' = ANY(COALESCE(e.roles, ARRAY[]::text[])))
);

DROP POLICY IF EXISTS leave_select_policy ON "leave";
CREATE POLICY leave_select_policy ON "leave" FOR SELECT USING (
  user_email = auth.email() OR
  EXISTS (SELECT 1 FROM employees e WHERE e.email = auth.email() AND 'admin' = ANY(COALESCE(e.roles, ARRAY[]::text[]))) OR
  auth.email() = 'hyun-woong.jeong@hansl.com'
);

DROP POLICY IF EXISTS leave_update_policy ON "leave";
CREATE POLICY leave_update_policy ON "leave" FOR UPDATE USING (
  user_email = auth.email() OR
  EXISTS (SELECT 1 FROM employees e WHERE e.email = auth.email() AND 'admin' = ANY(COALESCE(e.roles, ARRAY[]::text[])))
);

-- ============================================================
-- 완료 메시지
-- ============================================================
SELECT '2차 마이그레이션 완료: 통합 권한 체계 적용' as message;
