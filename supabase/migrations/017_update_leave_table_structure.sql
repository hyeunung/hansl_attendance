-- leave 테이블에 누락된 칼럼들 추가
ALTER TABLE leave 
ADD COLUMN IF NOT EXISTS start_period TEXT DEFAULT 'full',  -- full, morning, afternoon
ADD COLUMN IF NOT EXISTS end_period TEXT DEFAULT 'full';     -- full, morning, afternoon

-- days 칼럼이 없다면 추가
ALTER TABLE leave 
ADD COLUMN IF NOT EXISTS days DECIMAL(3,1);

-- days 값 자동 계산 (기존 데이터)
UPDATE leave 
SET days = CASE 
    WHEN start_period = 'full' AND end_period = 'full' THEN 
        (end_date - start_date + 1)::DECIMAL(3,1)
    WHEN (start_period = 'morning' OR start_period = 'afternoon') AND 
         (end_period = 'morning' OR end_period = 'afternoon') AND 
         start_date = end_date THEN 
        0.5
    ELSE 
        (end_date - start_date + 1)::DECIMAL(3,1)
END
WHERE days IS NULL;

-- 강영은님의 8월 18일 연차 데이터 확인 및 수정
UPDATE leave 
SET 
    start_period = 'afternoon',
    end_period = 'afternoon',
    days = 0.5,
    updated_at = NOW()
WHERE 
    name = '강영은' 
    AND start_date = '2025-08-18'
    AND type = 'annual';

-- 만약 데이터가 없다면 추가
INSERT INTO leave (
    user_email,
    name,
    type,
    start_date,
    end_date,
    start_period,
    end_period,
    days,
    reason,
    status,
    middle_manager_approval,
    final_approval,
    created_at,
    updated_at
)
SELECT 
    'young-eun.kang@hansl.com',
    '강영은',
    'annual',
    '2025-08-18',
    '2025-08-18',
    'afternoon',
    'afternoon',
    0.5,
    '개인 사유',
    'approved',
    true,
    true,
    NOW(),
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM leave 
    WHERE name = '강영은' 
    AND start_date = '2025-08-18'
    AND type = 'annual'
);