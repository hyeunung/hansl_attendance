-- 알림 테이블 생성
CREATE TABLE IF NOT EXISTS public.notifications (
    id SERIAL PRIMARY KEY,
    user_email TEXT NOT NULL REFERENCES public.employees(email) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL, -- 'leave_request', 'business_trip', 'leave_result' 등
    data JSONB, -- 추가 데이터 (requester_email, status 등)
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_notifications_user_email ON public.notifications(user_email);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- RLS 정책
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 알림만 조회 가능
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT
    USING (auth.jwt() ->> 'email' = user_email);

-- 사용자는 자신의 알림 읽음 상태만 업데이트 가능
CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE
    USING (auth.jwt() ->> 'email' = user_email);

-- 서비스 역할은 모든 알림 생성 가능 (Edge Function용)
CREATE POLICY "Service role can insert notifications" ON public.notifications
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- 사용자는 자신의 알림만 삭제 가능
CREATE POLICY "Users can delete own notifications" ON public.notifications
    FOR DELETE
    USING (auth.jwt() ->> 'email' = user_email);

-- 읽지 않은 알림 개수를 반환하는 함수
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_email TEXT)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM public.notifications
        WHERE user_email = p_user_email
        AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 알림을 읽음 처리하는 함수
CREATE OR REPLACE FUNCTION mark_notification_as_read(p_notification_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_email TEXT;
BEGIN
    -- 현재 사용자 이메일 가져오기
    v_user_email := auth.jwt() ->> 'email';
    
    -- 알림을 읽음 처리
    UPDATE public.notifications
    SET is_read = TRUE,
        read_at = NOW()
    WHERE id = p_notification_id
    AND user_email = v_user_email
    AND is_read = FALSE;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 모든 알림을 읽음 처리하는 함수
CREATE OR REPLACE FUNCTION mark_all_notifications_as_read()
RETURNS INTEGER AS $$
DECLARE
    v_user_email TEXT;
    v_count INTEGER;
BEGIN
    -- 현재 사용자 이메일 가져오기
    v_user_email := auth.jwt() ->> 'email';
    
    -- 읽지 않은 알림 개수 저장
    SELECT COUNT(*) INTO v_count
    FROM public.notifications
    WHERE user_email = v_user_email
    AND is_read = FALSE;
    
    -- 모든 알림을 읽음 처리
    UPDATE public.notifications
    SET is_read = TRUE,
        read_at = NOW()
    WHERE user_email = v_user_email
    AND is_read = FALSE;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;