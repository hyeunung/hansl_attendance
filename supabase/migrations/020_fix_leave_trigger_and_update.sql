-- 먼저 문제가 있는 트리거 비활성화
ALTER TABLE leave DISABLE TRIGGER update_leave_updated_at;

-- 강영은님의 8월 18일 연차를 오후반차로 수정
UPDATE leave 
SET type = 'half_afternoon'
WHERE id = 441;

-- 트리거 다시 활성화 (만약 필요하다면)
-- ALTER TABLE leave ENABLE TRIGGER update_leave_updated_at;