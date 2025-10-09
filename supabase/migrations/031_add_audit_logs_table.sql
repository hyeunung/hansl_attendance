-- audit_logs 테이블 생성 (구매 완료 처리 등의 감사 로그)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 인덱스 추가
CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at DESC);

-- RLS 정책
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- app_admin만 볼 수 있도록
CREATE POLICY "App admins can view audit logs" ON public.audit_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE employees.id = auth.uid()
      AND 'app_admin' = ANY(employees.purchase_role)
    )
  );

-- 시스템만 insert 가능 (Edge Function을 통해서만)
CREATE POLICY "System can insert audit logs" ON public.audit_logs
  FOR INSERT
  WITH CHECK (true);

COMMENT ON TABLE public.audit_logs IS '시스템 감사 로그 테이블';
COMMENT ON COLUMN public.audit_logs.action IS '수행된 작업 (mark_as_purchased, mark_as_received 등)';
COMMENT ON COLUMN public.audit_logs.target_type IS '대상 타입 (purchase_request 등)';
COMMENT ON COLUMN public.audit_logs.target_id IS '대상 ID (발주번호 등)';
COMMENT ON COLUMN public.audit_logs.details IS '상세 정보 (JSON 형태)';