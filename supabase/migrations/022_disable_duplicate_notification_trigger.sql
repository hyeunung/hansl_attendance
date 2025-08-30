-- 중복 알림 방지: 데이터베이스 트리거 비활성화
-- Flutter 앱에서 이미 알림을 보내고 있으므로 트리거 제거

-- 기존 트리거 제거
DROP TRIGGER IF EXISTS leave_notification_trigger ON leave;

-- 함수도 제거 (혼동 방지)
DROP FUNCTION IF EXISTS send_leave_notification();

-- 로그 메시지
SELECT '✅ 중복 알림 트리거 제거 완료' as result;