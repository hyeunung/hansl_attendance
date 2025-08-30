-- leave 테이블 데이터 확인
SELECT COUNT(*) as total_count FROM leave;

-- 상태별 집계
SELECT status, COUNT(*) as count 
FROM leave 
GROUP BY status;

-- 타입별 집계
SELECT type, COUNT(*) as count 
FROM leave 
GROUP BY type;

-- 승인된 연차 확인
SELECT COUNT(*) as approved_annual_count 
FROM leave 
WHERE status = 'approved' 
AND type IN ('연차', 'annual', '연차휴가');

-- 샘플 데이터 5개
SELECT * FROM leave LIMIT 5;