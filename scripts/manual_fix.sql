-- 트리거 삭제하고 데이터 수정하는 SQL
-- Supabase Dashboard SQL Editor에서 실행해주세요

-- 1. 문제가 있는 트리거 삭제
DROP TRIGGER IF EXISTS update_leave_updated_at ON leave;

-- 2. 강영은님의 8월 18일 연차를 오후반차로 수정  
UPDATE leave 
SET type = 'half_pm'
WHERE id = 441;

-- 3. 결과 확인
SELECT id, name, type, start_date, end_date 
FROM leave 
WHERE id = 441;