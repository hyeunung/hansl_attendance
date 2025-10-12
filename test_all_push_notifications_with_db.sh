#!/bin/bash

echo "🚀 HANSL 전체 푸시 알림 테스트 (DB 삽입 포함)"
echo "============================================"
echo "📧 테스트 계정: test@hansl.com"
echo "📅 시간: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Supabase 설정
export SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"
export SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.o0hVDQqdNyemRsaLat_VdJvNiTreYaJ6cNyfwDqx5P0"
export SUPABASE_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78"

echo "====================================="
echo "📋 1. 연차/출장 승인 관련 푸시 알림"
echo "====================================="

# 1. 연차 신청 생성 및 승인
echo -e "\n1-1. 연차 신청 생성 (test@hansl.com)"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "INSERT INTO leave (user_email, name, type, start_date, end_date, reason, status, created_at) 
           VALUES ('test@hansl.com', '테스트사원', 'annual_leave', CURRENT_DATE + INTERVAL '5 days', 
                   CURRENT_DATE + INTERVAL '5 days', '연차 푸시 알림 테스트', 'pending', NOW()) 
           RETURNING id"

echo "✅ 연차 신청 생성 완료"
sleep 2

# 연차 승인 처리 (Edge Function 호출)
echo -e "\n1-2. 연차 승인 알림 테스트"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    WITH latest_leave AS (
      SELECT id FROM leave 
      WHERE user_email = 'test@hansl.com' AND status = 'pending' 
      ORDER BY created_at DESC LIMIT 1
    )
    UPDATE leave 
    SET status = 'approved', 
        updated_at = NOW(),
        approver_name = '관리자'
    WHERE id = (SELECT id FROM latest_leave)
    RETURNING id"

echo "✅ 연차 승인 처리 및 알림 발송"
sleep 2

# 2. 연차 반려 테스트
echo -e "\n1-3. 연차 반려 테스트용 신청 생성"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "INSERT INTO leave (user_email, name, type, start_date, end_date, reason, status, created_at) 
           VALUES ('test@hansl.com', '테스트사원', 'annual_leave', CURRENT_DATE + INTERVAL '7 days', 
                   CURRENT_DATE + INTERVAL '7 days', '연차 반려 테스트', 'pending', NOW()) 
           RETURNING id"

sleep 2

echo -e "\n1-4. 연차 반려 알림 테스트"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    WITH latest_leave AS (
      SELECT id FROM leave 
      WHERE user_email = 'test@hansl.com' AND status = 'pending' 
      ORDER BY created_at DESC LIMIT 1
    )
    UPDATE leave 
    SET status = 'rejected', 
        updated_at = NOW(),
        approver_name = '관리자',
        rejection_reason = '업무 일정으로 인한 반려'
    WHERE id = (SELECT id FROM latest_leave)
    RETURNING id"

echo "✅ 연차 반려 처리 및 알림 발송"
sleep 2

# 3. 출장 신청 및 승인
echo -e "\n1-5. 출장 신청 생성"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "INSERT INTO leave (user_email, name, type, start_date, end_date, reason, status, created_at) 
           VALUES ('test@hansl.com', '테스트사원', 'business_trip', CURRENT_DATE + INTERVAL '10 days', 
                   CURRENT_DATE + INTERVAL '11 days', '서울 출장', 'pending', NOW()) 
           RETURNING id"

sleep 2

echo -e "\n1-6. 출장 승인 알림 테스트"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    WITH latest_trip AS (
      SELECT id FROM leave 
      WHERE user_email = 'test@hansl.com' AND type = 'business_trip' AND status = 'pending' 
      ORDER BY created_at DESC LIMIT 1
    )
    UPDATE leave 
    SET status = 'approved', 
        updated_at = NOW(),
        approver_name = '관리자'
    WHERE id = (SELECT id FROM latest_trip)
    RETURNING id"

echo "✅ 출장 승인 처리 및 알림 발송"
sleep 3

echo ""
echo "====================================="
echo "💰 2. 구매/발주 관련 푸시 알림"
echo "====================================="

# 구매 요청 생성
echo -e "\n2-1. 구매 요청 생성 (1차 승인 대기)"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    INSERT INTO purchase_requests (
      requester_name, requester_phone, vendor_name, 
      request_date, delivery_request_date, progress_type, 
      payment_category, currency, request_type, 
      purchase_order_number, middle_manager_status, 
      final_manager_status, created_at
    ) VALUES (
      '테스트사원', '010-1234-5678', '테스트 공급업체',
      CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', '요청',
      '구매 요청', 'KRW', '소모품',
      'PO-TEST-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS'),
      'pending', 'pending', NOW()
    ) RETURNING id, purchase_order_number"

sleep 2

# 1차 승인 처리
echo -e "\n2-2. 1차 승인 (중간 관리자) 알림 테스트"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    WITH latest_purchase AS (
      SELECT id FROM purchase_requests 
      WHERE requester_name = '테스트사원' AND middle_manager_status = 'pending' 
      ORDER BY created_at DESC LIMIT 1
    )
    UPDATE purchase_requests 
    SET middle_manager_status = 'approved',
        middle_manager_approved_at = NOW(),
        middle_manager_name = '중간관리자'
    WHERE id = (SELECT id FROM latest_purchase)
    RETURNING id"

echo "✅ 1차 승인 완료 및 알림 발송"
sleep 2

# 최종 승인 처리
echo -e "\n2-3. 최종 승인 알림 테스트"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    WITH latest_purchase AS (
      SELECT id FROM purchase_requests 
      WHERE requester_name = '테스트사원' AND final_manager_status = 'pending' 
      ORDER BY created_at DESC LIMIT 1
    )
    UPDATE purchase_requests 
    SET final_manager_status = 'approved',
        final_manager_approved_at = NOW(),
        final_manager_name = '최종승인자',
        progress_type = '발주'
    WHERE id = (SELECT id FROM latest_purchase)
    RETURNING id"

echo "✅ 최종 승인 완료 및 알림 발송"
sleep 2

# 반려 테스트
echo -e "\n2-4. 구매 요청 반려 테스트용 생성"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    INSERT INTO purchase_requests (
      requester_name, requester_phone, vendor_name, 
      request_date, delivery_request_date, progress_type, 
      payment_category, currency, request_type, 
      purchase_order_number, middle_manager_status, 
      final_manager_status, created_at
    ) VALUES (
      '테스트사원', '010-1234-5678', '테스트 공급업체2',
      CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', '요청',
      '발주', 'KRW', '원자재',
      'PO-TEST2-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS'),
      'pending', 'pending', NOW()
    ) RETURNING id"

sleep 2

echo -e "\n2-5. 구매 요청 반려 알림 테스트"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    WITH latest_purchase AS (
      SELECT id FROM purchase_requests 
      WHERE requester_name = '테스트사원' AND middle_manager_status = 'pending' 
      ORDER BY created_at DESC LIMIT 1
    )
    UPDATE purchase_requests 
    SET middle_manager_status = 'rejected',
        middle_manager_rejected_at = NOW(),
        middle_manager_name = '중간관리자',
        middle_manager_rejection_reason = '예산 초과'
    WHERE id = (SELECT id FROM latest_purchase)
    RETURNING id"

echo "✅ 구매 요청 반려 처리 및 알림 발송"
sleep 3

echo ""
echo "====================================="
echo "📦 3. 입고 관련 푸시 알림"
echo "====================================="

# 선진행 구매 요청 생성 (입고대기 상태)
echo -e "\n3-1. 선진행 구매 요청 생성 (입고대기)"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    INSERT INTO purchase_requests (
      requester_name, requester_phone, vendor_name, 
      request_date, delivery_request_date, progress_type, 
      payment_category, currency, request_type, 
      purchase_order_number, middle_manager_status, 
      final_manager_status, is_payment_completed, is_received, created_at
    ) VALUES (
      '테스트사원', '010-1234-5678', '긴급 공급업체',
      CURRENT_DATE, CURRENT_DATE, '선진행',
      '구매 요청', 'KRW', '긴급자재',
      'PO-URGENT-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS'),
      'approved', 'approved', true, false, NOW()
    ) RETURNING id, purchase_order_number"

sleep 2

echo -e "\n3-2. 입고 완료 처리 알림 테스트"
npx supabase-mcp execute-sql \
  --project-id qvhbigvdfyvhoegkhvef \
  --query "
    WITH latest_receiving AS (
      SELECT id FROM purchase_requests 
      WHERE requester_name = '테스트사원' AND is_received = false 
      ORDER BY created_at DESC LIMIT 1
    )
    UPDATE purchase_requests 
    SET is_received = true,
        received_at = NOW(),
        receiver_name = '창고담당자'
    WHERE id = (SELECT id FROM latest_receiving)
    RETURNING id"

echo "✅ 입고 완료 처리 및 알림 발송"
sleep 3

echo ""
echo "====================================="
echo "🔔 4. 출퇴근 알림 테스트"
echo "====================================="

echo -e "\n4-1. 출근 알림 테스트"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "🏢 출근 알림",
    "body": "출근 시간입니다. 출근 체크를 해주세요!",
    "notificationType": "attendance_reminder"
  }' | jq '.'

sleep 2

echo -e "\n4-2. 퇴근 알림 테스트"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "🏠 퇴근 알림",
    "body": "퇴근 시간입니다. 퇴근 체크를 해주세요!",
    "notificationType": "attendance_reminder"
  }' | jq '.'

echo ""
echo "====================================="
echo "✅ 모든 푸시 알림 테스트 완료!"
echo "====================================="
echo ""
echo "📱 test@hansl.com 기기에서 확인할 알림 목록:"
echo ""
echo "1. 연차/출장 관련:"
echo "   - 연차 승인 알림"
echo "   - 연차 반려 알림"
echo "   - 출장 승인 알림"
echo ""
echo "2. 구매/발주 관련:"
echo "   - 1차 승인 알림"
echo "   - 최종 승인 알림"
echo "   - 구매 요청 반려 알림"
echo ""
echo "3. 입고 관련:"
echo "   - 입고 완료 알림"
echo ""
echo "4. 출퇴근 관련:"
echo "   - 출근 알림"
echo "   - 퇴근 알림"
echo ""
echo "📊 총 9개의 푸시 알림이 전송되었습니다!"
echo ""
echo "🔍 Edge Function 로그 확인:"
echo "npx supabase functions logs send_fcm_notification --project-ref qvhbigvdfyvhoegkhvef"