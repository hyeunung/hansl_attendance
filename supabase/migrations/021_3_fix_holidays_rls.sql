-- 기존 RLS 정책 삭제
DROP POLICY IF EXISTS "Anyone can view holidays" ON public.holidays;
DROP POLICY IF EXISTS "Only admins can manage holidays" ON public.holidays;

-- 새로운 RLS 정책: 모든 사용자가 조회 가능 (인증 여부 관계없이)
CREATE POLICY "Everyone can view holidays" ON public.holidays
    FOR SELECT
    TO public
    USING (true);

-- admin만 수정 가능 (기존과 동일)
CREATE POLICY "Only admins can manage holidays" ON public.holidays
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.employees
            WHERE employees.email = auth.jwt() ->> 'email'
            AND 'admin' = ANY(employees.attendance_role)
        )
    );