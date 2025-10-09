-- 발주 관련 권한을 가진 사용자 확인
-- FCM 토큰이 있는 사용자만 알림을 받을 수 있음

-- 1. middle_manager 권한 사용자 (1차 승인자)
SELECT 
    name,
    email,
    purchase_role,
    CASE WHEN fcm_token IS NOT NULL AND fcm_token != '' THEN '✅ 알림 가능' ELSE '❌ FCM 토큰 없음' END as notification_status
FROM employees
WHERE 'middle_manager' = ANY(purchase_role)
ORDER BY name;

-- 2. consumable_manager 권한 사용자 (구매요청 최종승인자)
SELECT 
    name,
    email,
    purchase_role,
    CASE WHEN fcm_token IS NOT NULL AND fcm_token != '' THEN '✅ 알림 가능' ELSE '❌ FCM 토큰 없음' END as notification_status
FROM employees
WHERE 'consumable_manager' = ANY(purchase_role)
ORDER BY name;

-- 3. raw_material_manager 권한 사용자 (발주 최종승인자)
SELECT 
    name,
    email,
    purchase_role,
    CASE WHEN fcm_token IS NOT NULL AND fcm_token != '' THEN '✅ 알림 가능' ELSE '❌ FCM 토큰 없음' END as notification_status
FROM employees
WHERE 'raw_material_manager' = ANY(purchase_role)
ORDER BY name;

-- 4. lead buyer 권한 사용자 (구매대기 담당자)
SELECT 
    name,
    email,
    purchase_role,
    CASE WHEN fcm_token IS NOT NULL AND fcm_token != '' THEN '✅ 알림 가능' ELSE '❌ FCM 토큰 없음' END as notification_status
FROM employees
WHERE 'lead buyer' = ANY(purchase_role)
ORDER BY name;

-- 5. app_admin 권한 사용자 (모든 알림 수신)
SELECT 
    name,
    email,
    purchase_role,
    CASE WHEN fcm_token IS NOT NULL AND fcm_token != '' THEN '✅ 알림 가능' ELSE '❌ FCM 토큰 없음' END as notification_status
FROM employees
WHERE 'app_admin' = ANY(purchase_role)
ORDER BY name;
