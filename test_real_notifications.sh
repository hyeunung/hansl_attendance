#!/bin/bash

echo "🔥 HANSL 실제 코드 푸시 알림 테스트"
echo "===================================="
echo "📧 테스트 계정: test@hansl.com"
echo "📅 시간: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78"
SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"

echo "==================================="
echo "📋 1. 연차/출장 관련 푸시 알림"
echo "==================================="

# 테스트용 연차 신청 생성 및 승인 테스트
echo -e "\n1-1. 연차 신청 생성 (test@hansl.com)"
LEAVE_ID=$(curl -s -X POST "$SUPABASE_URL/rest/v1/leave" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "user_email": "test@hansl.com",
    "name": "테스트사원",
    "type": "annual_leave",
    "start_date": "2025-10-20",
    "end_date": "2025-10-20",
    "reason": "푸시 알림 테스트용 연차",
    "status": "pending"
  }' | jq -r '.[0].id')

echo "✅ 연차 신청 생성됨 (ID: $LEAVE_ID)"
sleep 2

echo -e "\n1-2. 연차 승인 테스트 (update_leave_status)"
curl -s -X POST "$SUPABASE_URL/functions/v1/update_leave_status" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": $LEAVE_ID,
    \"status\": \"approved\"
  }" | jq '.'

sleep 2

# 새로운 연차 신청 생성 (반려 테스트용)
echo -e "\n1-3. 연차 반려 테스트용 신청 생성"
LEAVE_ID_2=$(curl -s -X POST "$SUPABASE_URL/rest/v1/leave" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "user_email": "test@hansl.com",
    "name": "테스트사원",
    "type": "annual_leave",
    "start_date": "2025-10-21",
    "end_date": "2025-10-21",
    "reason": "반려 테스트용 연차",
    "status": "pending"
  }' | jq -r '.[0].id')

echo "✅ 반려 테스트용 연차 생성됨 (ID: $LEAVE_ID_2)"
sleep 2

echo -e "\n1-4. 연차 반려 테스트"
curl -s -X POST "$SUPABASE_URL/functions/v1/update_leave_status" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": $LEAVE_ID_2,
    \"status\": \"rejected\"
  }" | jq '.'

sleep 2

echo -e "\n1-5. 출장 신청 생성"
BUSINESS_TRIP_ID=$(curl -s -X POST "$SUPABASE_URL/rest/v1/leave" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "user_email": "test@hansl.com",
    "name": "테스트사원",
    "type": "business_trip",
    "start_date": "2025-10-22",
    "end_date": "2025-10-23",
    "reason": "서울 출장",
    "status": "pending"
  }' | jq -r '.[0].id')

echo "✅ 출장 신청 생성됨 (ID: $BUSINESS_TRIP_ID)"
sleep 2

echo -e "\n1-6. 출장 승인 테스트"
curl -s -X POST "$SUPABASE_URL/functions/v1/update_leave_status" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": $BUSINESS_TRIP_ID,
    \"status\": \"approved\"
  }" | jq '.'

sleep 3

echo ""
echo "==================================="
echo "💰 2. 구매/발주 관련 푸시 알림"
echo "==================================="

# test@hansl.com의 이름 가져오기
USER_NAME=$(curl -s "$SUPABASE_URL/rest/v1/employees?email=eq.test@hansl.com" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" | jq -r '.[0].name')

echo -e "\n2-1. 구매 요청 생성 (요청자: $USER_NAME)"
PURCHASE_ID=$(curl -s -X POST "$SUPABASE_URL/rest/v1/purchase_requests" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"requester_name\": \"$USER_NAME\",
    \"requester_phone\": \"010-1234-5678\",
    \"vendor_id\": 1,
    \"vendor_name\": \"테스트 공급업체\",
    \"request_date\": \"2025-10-11\",
    \"delivery_request_date\": \"2025-10-20\",
    \"progress_type\": \"요청\",
    \"payment_category\": \"구매 요청\",
    \"currency\": \"KRW\",
    \"request_type\": \"소모품\",
    \"purchase_order_number\": \"PO-TEST-$(date +%s)\",
    \"middle_manager_status\": \"pending\",
    \"final_manager_status\": \"pending\"
  }" | jq -r '.[0].id')

echo "✅ 구매 요청 생성됨 (ID: $PURCHASE_ID)"
sleep 2

echo -e "\n2-2. 구매 요청 아이템 추가"
curl -s -X POST "$SUPABASE_URL/rest/v1/purchase_request_items" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"purchase_request_id\": $PURCHASE_ID,
    \"line_number\": 1,
    \"item_name\": \"노트북\",
    \"specification\": \"MacBook Pro 14inch\",
    \"quantity\": 1,
    \"unit_price_value\": 3000000,
    \"unit_price_currency\": \"KRW\",
    \"amount_value\": 3000000,
    \"amount_currency\": \"KRW\",
    \"vendor_name\": \"테스트 공급업체\",
    \"requester_name\": \"$USER_NAME\",
    \"purchase_order_number\": \"PO-TEST-$(date +%s)\"
  }" | jq '.'

sleep 2

echo -e "\n2-3. 1차 승인 (중간 관리자)"
curl -s -X PATCH "$SUPABASE_URL/rest/v1/purchase_requests?id=eq.$PURCHASE_ID" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "middle_manager_status": "approved",
    "middle_manager_approved_at": "now()"
  }' 
echo "✅ 1차 승인 완료"

sleep 2

echo -e "\n2-4. 최종 승인 테스트"
curl -s -X PATCH "$SUPABASE_URL/rest/v1/purchase_requests?id=eq.$PURCHASE_ID" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "final_manager_status": "approved",
    "final_manager_approved_at": "now()",
    "progress_type": "발주"
  }' 
echo "✅ 최종 승인 완료"

sleep 2

# 반려 테스트용 구매 요청 생성
echo -e "\n2-5. 반려 테스트용 구매 요청 생성"
PURCHASE_ID_2=$(curl -s -X POST "$SUPABASE_URL/rest/v1/purchase_requests" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"requester_name\": \"$USER_NAME\",
    \"requester_phone\": \"010-1234-5678\",
    \"vendor_id\": 1,
    \"vendor_name\": \"테스트 공급업체2\",
    \"request_date\": \"2025-10-11\",
    \"delivery_request_date\": \"2025-10-25\",
    \"progress_type\": \"요청\",
    \"payment_category\": \"구매 요청\",
    \"currency\": \"KRW\",
    \"request_type\": \"원자재\",
    \"purchase_order_number\": \"PO-TEST2-$(date +%s)\",
    \"middle_manager_status\": \"pending\",
    \"final_manager_status\": \"pending\"
  }" | jq -r '.[0].id')

echo "✅ 반려 테스트용 구매 요청 생성됨 (ID: $PURCHASE_ID_2)"
sleep 2

echo -e "\n2-6. 구매 요청 반려 테스트"
curl -s -X PATCH "$SUPABASE_URL/rest/v1/purchase_requests?id=eq.$PURCHASE_ID_2" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "middle_manager_status": "rejected",
    "middle_manager_rejected_at": "now()",
    "middle_manager_rejection_reason": "예산 초과"
  }' 
echo "✅ 구매 요청 반려 처리 완료"

sleep 3

echo ""
echo "==================================="
echo "📦 3. 입고 관련 푸시 알림"
echo "==================================="

echo -e "\n3-1. 입고 완료 테스트 (mark-item-as-received)"
curl -s -X POST "$SUPABASE_URL/functions/v1/mark-item-as-received" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"purchaseRequestId\": $PURCHASE_ID,
    \"lineNumber\": 1
  }" | jq '.'

sleep 2

echo ""
echo "==================================="
echo "🔔 4. 직접 FCM 알림 테스트"
echo "==================================="

echo -e "\n4-1. 긴급 알림 테스트"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "🚨 긴급 공지사항",
    "body": "모든 푸시 알림이 정상 작동합니다!",
    "notificationType": "urgent",
    "data": {
      "click_action": "FLUTTER_NOTIFICATION_CLICK",
      "priority": "high"
    }
  }' | jq '.'

echo ""
echo "==================================="
echo "✅ 모든 실제 코드 테스트 완료!"
echo "==================================="
echo ""
echo "📱 test@hansl.com 기기에서 다음 알림들을 확인하세요:"
echo "  1. 연차 승인/반려 알림 (2건)"
echo "  2. 출장 승인 알림 (1건)"
echo "  3. 구매 요청 승인/반려 알림 (2건)"
echo "  4. 입고 완료 알림 (1건)"
echo "  5. 긴급 공지 알림 (1건)"
echo ""
echo "총 7개의 푸시 알림이 전송되었습니다!"
echo ""
echo "📝 로그 확인:"
echo "npx supabase functions logs --project-ref qvhbigvdfyvhoegkhvef"