-- ============================================================
-- Baseline tables for support inquiries and holidays
-- ============================================================
-- roles 통합 마이그레이션에서 참조하는 테이블이 없는 환경을 보정한다.

CREATE TABLE IF NOT EXISTS public.holidays (
  id BIGSERIAL PRIMARY KEY,
  date DATE UNIQUE,
  name TEXT,
  is_holiday BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_inquires (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID,
  requester_id UUID,
  user_email TEXT,
  title TEXT,
  content TEXT,
  status TEXT DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_inquiry_messages (
  id BIGSERIAL PRIMARY KEY,
  inquiry_id BIGINT,
  sender_email TEXT,
  sender_role TEXT,
  message TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
