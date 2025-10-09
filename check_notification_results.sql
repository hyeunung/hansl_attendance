-- 발주 알림 테스트 결과 확인 쿼리 모음

-- 1. 최근 10분간 생성된 알림 확인
SELECT 
    TO_CHAR(created_at, 'HH24:MI:SS') as "시간",
    user_email as "수신자",
    title as "제목",
    SUBSTRING(body, 1, 50) || '...' as "내용",
    data->>'purchase_order_number' as "발주번호",
    is_read as "읽음"
FROM notifications
WHERE created_at > NOW() - INTERVAL '10 minutes'
  AND (
    type LIKE '%purchase%' 
    OR data->>'type' LIKE '%purchase%'
    OR title LIKE '%발주%'
    OR title LIKE '%구매%'
  )
ORDER BY created_at DESC;

-- 2. 역할별 알림 수신 현황
SELECT 
    e.name as "이름",
    e.email as "이메일",
    e.purchase_role as "역할",
    COUNT(n.id) as "받은알림수"
FROM employees e
LEFT JOIN notifications n ON e.email = n.user_email 
    AND n.created_at > NOW() - INTERVAL '10 minutes'
    AND (n.type LIKE '%purchase%' OR n.data->>'type' LIKE '%purchase%')
WHERE e.purchase_role IS NOT NULL 
  AND array_length(e.purchase_role, 1) > 0
GROUP BY e.name, e.email, e.purchase_role
ORDER BY COUNT(n.id) DESC;

-- 3. 발주번호별 알림 발송 현황
SELECT 
    pr.purchase_order_number as "발주번호",
    pr.payment_category as "카테고리",
    pr.requester_name as "요청자",
    COUNT(DISTINCT n.id) as "알림수",
    STRING_AGG(DISTINCT n.user_email, ', ') as "수신자들"
FROM purchase_requests pr
LEFT JOIN notifications n ON n.data->>'purchase_order_number' = pr.purchase_order_number
WHERE pr.created_at > NOW() - INTERVAL '10 minutes'
GROUP BY pr.purchase_order_number, pr.payment_category, pr.requester_name
ORDER BY pr.created_at DESC;

-- 4. 알림 타입별 통계
SELECT 
    COALESCE(data->>'type', type) as "알림타입",
    COUNT(*) as "건수",
    STRING_AGG(DISTINCT title, ' / ') as "제목들"
FROM notifications
WHERE created_at > NOW() - INTERVAL '10 minutes'
  AND (type LIKE '%purchase%' OR data->>'type' LIKE '%purchase%' OR title LIKE '%발주%' OR title LIKE '%구매%')
GROUP BY COALESCE(data->>'type', type)
ORDER BY COUNT(*) DESC;

-- 5. FCM 토큰 상태 확인 (알림 받을 수 있는 사용자)
SELECT 
    name as "이름",
    email as "이메일",
    purchase_role as "발주역할",
    CASE 
        WHEN fcm_token IS NOT NULL AND fcm_token != '' THEN '✅ 알림가능'
        ELSE '❌ 토큰없음'
    END as "FCM상태",
    CASE 
        WHEN fcm_token IS NOT NULL THEN SUBSTRING(fcm_token, 1, 20) || '...'
        ELSE NULL
    END as "토큰일부"
FROM employees
WHERE purchase_role IS NOT NULL 
  AND array_length(purchase_role, 1) > 0
ORDER BY 
    CASE WHEN fcm_token IS NOT NULL THEN 0 ELSE 1 END,
    name;
