-- leave 테이블의 문제가 있는 트리거 삭제
DROP TRIGGER IF EXISTS update_leave_updated_at ON leave;

-- 강영은님의 8월 18일 연차를 오후반차로 수정
UPDATE leave 
SET type = 'half_pm'
WHERE id = 441;