#!/bin/bash

echo "🚀 관리자 푸시 알림 테스트 (Release Mode)"
echo "=================================================="
echo ""

# 설정
PROJECT_REF="qvhbigvdfyvhoegkhvef"
SUPABASE_URL="https://${PROJECT_REF}.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/send_fcm_notification"
TEST_EMAIL="test@hansl.com"

echo "📋 테스트 정보:"
echo "  - 요청자 계정: ${TEST_EMAIL}"
echo "  - 알림 대상: 관리자들 (attendance_role 기반)"
echo "  - 테스트 모드: Release Mode"
echo "  - 시작 시간: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. 연차 신청 알림 (test@hansl.com이 신청 → 관리자에게 알림)
echo "1️⃣ 연차 신청 알림 테스트 (test@hansl.com → 관리자)..."
LEAVE_REQUEST=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"admin\",
    \"title\": \"📅 연차 신청\",
    \"body\": \"test님이 10월 7일 연차를 신청했습니다.\",
    \"data\": {
      \"type\": \"leave_request\",
      \"requester_email\": \"${TEST_EMAIL}\",
      \"requester_name\": \"test\",
      \"leave_date\": \"2025-10-07\",
      \"timestamp\": \"$(date +%s)\"
    },
    \"requester_department\": \"개발1팀\",
    \"requester_email\": \"${TEST_EMAIL}\"
  }")

echo "결과: $(echo $LEAVE_REQUEST | jq -r '.message' 2>/dev/null || echo '테스트 실패')"
echo "대상자: $(echo $LEAVE_REQUEST | jq -r '.details.recipients[]' 2>/dev/null | tr '\n' ', ')"
SUCCESS=$(echo $LEAVE_REQUEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TOTAL=$(echo $LEAVE_REQUEST | jq -r '.details.total' 2>/dev/null || echo '0')
echo "성공률: ${SUCCESS}/${TOTAL}"
echo ""

sleep 2

# 2. 출장 신청 알림 (test@hansl.com이 신청 → 관리자에게 알림)
echo "2️⃣ 출장 신청 알림 테스트 (test@hansl.com → 관리자)..."
TRIP_REQUEST=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"admin\",
    \"title\": \"🚗 출장 신청\",
    \"body\": \"test님이 서울 출장을 신청했습니다.\",
    \"data\": {
      \"type\": \"business_trip\",
      \"requester_email\": \"${TEST_EMAIL}\",
      \"requester_name\": \"test\",
      \"destination\": \"서울\",
      \"start_date\": \"2025-10-08\",
      \"end_date\": \"2025-10-09\",
      \"timestamp\": \"$(date +%s)\"
    },
    \"requester_department\": \"개발1팀\",
    \"requester_email\": \"${TEST_EMAIL}\"
  }")

echo "결과: $(echo $TRIP_REQUEST | jq -r '.message' 2>/dev/null || echo '테스트 실패')"
echo "대상자: $(echo $TRIP_REQUEST | jq -r '.details.recipients[]' 2>/dev/null | tr '\n' ', ')"
SUCCESS=$(echo $TRIP_REQUEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TOTAL=$(echo $TRIP_REQUEST | jq -r '.details.total' 2>/dev/null || echo '0')
echo "성공률: ${SUCCESS}/${TOTAL}"
echo ""

sleep 2

# 3. 구매 요청 알림 (test@hansl.com이 신청 → 구매 담당자에게 알림)
echo "3️⃣ 구매 요청 알림 테스트 (test@hansl.com → 구매 담당자)..."
PURCHASE_REQUEST=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"purchase_requests\",
    \"title\": \"💳 새로운 구매 요청\",
    \"body\": \"test님이 노트북 구매를 요청했습니다.\",
    \"data\": {
      \"type\": \"purchase_request\",
      \"requester_email\": \"${TEST_EMAIL}\",
      \"requester_name\": \"test\",
      \"timestamp\": \"$(date +%s)\"
    },
    \"requester_name\": \"test\",
    \"purchase_order_number\": \"PO-TEST-$(date +%Y%m%d%H%M%S)\",
    \"payment_category\": \"구매 요청\",
    \"vendor_name\": \"테스트 업체\"
  }")

echo "결과: $(echo $PURCHASE_REQUEST | jq -r '.message' 2>/dev/null || echo '테스트 실패')"
echo "대상자: $(echo $PURCHASE_REQUEST | jq -r '.details.recipients[]' 2>/dev/null | tr '\n' ', ')"
SUCCESS=$(echo $PURCHASE_REQUEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TOTAL=$(echo $PURCHASE_REQUEST | jq -r '.details.total' 2>/dev/null || echo '0')
echo "성공률: ${SUCCESS}/${TOTAL}"
echo ""

# 결과 집계
echo "=================================================="
echo "📊 테스트 결과 요약"
echo "=================================================="

# 각 테스트 결과 파싱
LEAVE_SUCCESS=$(echo $LEAVE_REQUEST | jq -r '.details.successful' 2>/dev/null || echo '0')
LEAVE_TOTAL=$(echo $LEAVE_REQUEST | jq -r '.details.total' 2>/dev/null || echo '0')

TRIP_SUCCESS=$(echo $TRIP_REQUEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TRIP_TOTAL=$(echo $TRIP_REQUEST | jq -r '.details.total' 2>/dev/null || echo '0')

PURCHASE_SUCCESS=$(echo $PURCHASE_REQUEST | jq -r '.details.successful' 2>/dev/null || echo '0')
PURCHASE_TOTAL=$(echo $PURCHASE_REQUEST | jq -r '.details.total' 2>/dev/null || echo '0')

TOTAL_SUCCESS=$((LEAVE_SUCCESS + TRIP_SUCCESS + PURCHASE_SUCCESS))
TOTAL_ATTEMPTS=$((LEAVE_TOTAL + TRIP_TOTAL + PURCHASE_TOTAL))

echo "📱 연차 신청: ${LEAVE_SUCCESS}/${LEAVE_TOTAL} 성공"
echo "🚗 출장 신청: ${TRIP_SUCCESS}/${TRIP_TOTAL} 성공"
echo "💳 구매 요청: ${PURCHASE_SUCCESS}/${PURCHASE_TOTAL} 성공"
echo ""
echo "전체: ${TOTAL_SUCCESS}/${TOTAL_ATTEMPTS} 성공"

if [ "$TOTAL_ATTEMPTS" -gt 0 ]; then
    SUCCESS_RATE=$((TOTAL_SUCCESS * 100 / TOTAL_ATTEMPTS))
    echo "📈 성공률: ${SUCCESS_RATE}%"
else
    echo "📈 성공률: 0%"
fi
echo ""

if [ "$TOTAL_SUCCESS" -eq "$TOTAL_ATTEMPTS" ] && [ "$TOTAL_ATTEMPTS" -gt 0 ]; then
    echo "🎉 모든 관리자 푸시 알림이 정상 작동합니다!"
elif [ "$TOTAL_SUCCESS" -gt 0 ]; then
    echo "⚠️ 일부 관리자 푸시 알림만 작동합니다. 추가 점검이 필요합니다."
else
    echo "❌ 모든 관리자 푸시 알림이 실패했습니다."
fi

echo ""
echo "📱 테스트 완료 시간: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "💡 설명: test@hansl.com이 연차/출장/구매를 신청하면"
echo "     해당 부서 관리자 및 담당자들에게 푸시 알림이 전송됩니다."