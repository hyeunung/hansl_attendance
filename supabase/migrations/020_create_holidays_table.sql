-- 공휴일 테이블 생성
CREATE TABLE IF NOT EXISTS public.holidays (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    is_alternative BOOLEAN DEFAULT FALSE, -- 대체공휴일 여부
    year INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_holidays_date ON public.holidays(date);
CREATE INDEX IF NOT EXISTS idx_holidays_year ON public.holidays(year);

-- RLS 정책 설정
ALTER TABLE public.holidays ENABLE ROW LEVEL SECURITY;

-- 모든 로그인 사용자가 조회 가능
CREATE POLICY "Anyone can view holidays" ON public.holidays
    FOR SELECT
    TO authenticated
    USING (true);

-- admin만 수정 가능
CREATE POLICY "Only admins can manage holidays" ON public.holidays
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.employees
            WHERE employees.email = auth.jwt() ->> 'email'
            AND employees.attendance_role = 'admin'
        )
    );

-- 2025년 한국 공휴일 데이터 삽입
INSERT INTO public.holidays (date, name, is_alternative, year) VALUES
    ('2025-01-01', '신정', false, 2025),
    ('2025-01-28', '설날 연휴', false, 2025),
    ('2025-01-29', '설날', false, 2025),
    ('2025-01-30', '설날 연휴', false, 2025),
    ('2025-03-01', '삼일절', false, 2025),
    ('2025-05-05', '어린이날', false, 2025),
    ('2025-05-06', '어린이날 대체공휴일', true, 2025),
    ('2025-06-06', '현충일', false, 2025),
    ('2025-08-15', '광복절', false, 2025),
    ('2025-10-03', '개천절', false, 2025),
    ('2025-10-05', '추석 연휴', false, 2025),
    ('2025-10-06', '추석', false, 2025),
    ('2025-10-07', '추석 연휴', false, 2025),
    ('2025-10-08', '추석 대체공휴일', true, 2025),
    ('2025-10-09', '한글날', false, 2025),
    ('2025-12-25', '크리스마스', false, 2025)
ON CONFLICT (date) DO NOTHING;