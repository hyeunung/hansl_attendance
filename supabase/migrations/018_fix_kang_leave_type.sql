-- 강영은님의 2025년 8월 18일 연차를 오후반차로 수정
UPDATE leave 
SET 
    type = 'half_afternoon',
    days = 0.5,
    updated_at = NOW()
WHERE 
    name = '강영은' 
    AND start_date = '2025-08-18'
    AND type = 'annual';