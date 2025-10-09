#!/bin/bash

echo "🚀 푸시 알림 테스트 (Release Mode) - test@hansl.com"
echo "=================================================="
echo ""

# 설정
PROJECT_REF="qvhbigvdfyvhoegkhvef"
SUPABASE_URL="https://${PROJECT_REF}.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/send_fcm_notification"
TEST_EMAIL="test@hansl.com"

echo "📋 테스트 정보:"
echo "  - 테스트 계정: ${TEST_EMAIL}"
echo "  - 테스트 모드: Release Mode"
echo "  - 시작 시간: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. 기본 사용자 알림 테스트
echo "1️⃣ 기본 푸시 알림 테스트..."
BASIC_TEST=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"user\",
    \"user_email\": \"${TEST_EMAIL}\",
    \"title\": \"📱 테스트 알림\",
    \"body\": \"Release Mode 푸시 알림 테스트입니다.\",
    \"data\": {
      \"type\": \"test_notification\",
      \"timestamp\": \"$(date +%s)\"
    }
  }")

echo "결과: $(echo $BASIC_TEST | jq -r '.message' 2>/dev/null || echo '테스트 실패')"
SUCCESS=$(echo $BASIC_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TOTAL=$(echo $BASIC_TEST | jq -r '.details.total' 2>/dev/null || echo '1')
echo "성공률: ${SUCCESS}/${TOTAL}"
echo ""

sleep 2

# 2. 연차 신청 알림 테스트
echo "2️⃣ 연차 신청 알림 테스트..."
LEAVE_TEST=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"user\",
    \"user_email\": \"${TEST_EMAIL}\",
    \"title\": \"📅 연차 승인 완료\",
    \"body\": \"10월 7일 연차 신청이 승인되었습니다.\",
    \"data\": {
      \"type\": \"leave_result\",
      \"status\": \"approved\",
      \"timestamp\": \"$(date +%s)\"
    }
  }")

echo "결과: $(echo $LEAVE_TEST | jq -r '.message' 2>/dev/null || echo '테스트 실패')"
SUCCESS=$(echo $LEAVE_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TOTAL=$(echo $LEAVE_TEST | jq -r '.details.total' 2>/dev/null || echo '1')
echo "성공률: ${SUCCESS}/${TOTAL}"
echo ""

sleep 2

# 3. 출장 신청 알림 테스트
echo "3️⃣ 출장 신청 알림 테스트..."
TRIP_TEST=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"user\",
    \"user_email\": \"${TEST_EMAIL}\",
    \"title\": \"🚗 출장 승인 요청\",
    \"body\": \"서울 출장 신청을 검토해주세요.\",
    \"data\": {
      \"type\": \"business_trip\",
      \"location\": \"서울\",
      \"timestamp\": \"$(date +%s)\"
    }
  }")

echo "결과: $(echo $TRIP_TEST | jq -r '.message' 2>/dev/null || echo '테스트 실패')"
SUCCESS=$(echo $TRIP_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TOTAL=$(echo $TRIP_TEST | jq -r '.details.total' 2>/dev/null || echo '1')
echo "성공률: ${SUCCESS}/${TOTAL}"
echo ""

sleep 2

# 4. 구매 요청 알림 테스트
echo "4️⃣ 구매 요청 알림 테스트..."
PURCHASE_TEST=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"user\",
    \"user_email\": \"${TEST_EMAIL}\",
    \"title\": \"💳 구매 승인 완료\",
    \"body\": \"노트북 구매 요청이 승인되었습니다.\",
    \"data\": {
      \"type\": \"purchase_approved\",
      \"purchase_order_number\": \"PO-2025-10-001\",
      \"timestamp\": \"$(date +%s)\"
    }
  }")

echo "결과: $(echo $PURCHASE_TEST | jq -r '.message' 2>/dev/null || echo '테스트 실패')"
SUCCESS=$(echo $PURCHASE_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TOTAL=$(echo $PURCHASE_TEST | jq -r '.details.total' 2>/dev/null || echo '1')
echo "성공률: ${SUCCESS}/${TOTAL}"
echo ""

sleep 2

# 5. 긴급 알림 테스트
echo "5️⃣ 긴급 알림 테스트..."
URGENT_TEST=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"user\",
    \"user_email\": \"${TEST_EMAIL}\",
    \"title\": \"🚨 긴급 공지\",
    \"body\": \"시스템 점검이 10분 후 시작됩니다.\",
    \"data\": {
      \"type\": \"emergency\",
      \"priority\": \"high\",
      \"timestamp\": \"$(date +%s)\"
    }
  }")

echo "결과: $(echo $URGENT_TEST | jq -r '.message' 2>/dev/null || echo '테스트 실패')"
SUCCESS=$(echo $URGENT_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TOTAL=$(echo $URGENT_TEST | jq -r '.details.total' 2>/dev/null || echo '1')
echo "성공률: ${SUCCESS}/${TOTAL}"
echo ""

# 결과 집계
echo "="
echo "📊 테스트 결과 요약"
echo "=================================================="

# 각 테스트 결과 파싱
BASIC_SUCCESS=$(echo $BASIC_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')
LEAVE_SUCCESS=$(echo $LEAVE_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')
TRIP_SUCCESS=$(echo $TRIP_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')
PURCHASE_SUCCESS=$(echo $PURCHASE_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')
URGENT_SUCCESS=$(echo $URGENT_TEST | jq -r '.details.successful' 2>/dev/null || echo '0')

TOTAL_SUCCESS=$((BASIC_SUCCESS + LEAVE_SUCCESS + TRIP_SUCCESS + PURCHASE_SUCCESS + URGENT_SUCCESS))
TOTAL_TESTS=5

echo "✅ 성공: ${TOTAL_SUCCESS}개"
echo "❌ 실패: $((TOTAL_TESTS - TOTAL_SUCCESS))개"
echo "📈 성공률: $((TOTAL_SUCCESS * 100 / TOTAL_TESTS))%"
echo ""

if [ "$TOTAL_SUCCESS" -eq "$TOTAL_TESTS" ]; then
    echo "🎉 모든 푸시 알림이 정상 작동합니다!"
elif [ "$TOTAL_SUCCESS" -gt 0 ]; then
    echo "⚠️ 일부 푸시 알림만 작동합니다. 추가 점검이 필요합니다."
else
    echo "❌ 모든 푸시 알림이 실패했습니다. Firebase 설정을 확인하세요."
fi

echo ""
echo "📱 테스트 완료 시간: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "💡 팁: 실제 디바이스에서 HANSL 앱을 Release Mode로 실행 중인지 확인하세요."
echo "     알림이 도착하면 알림을 탭하여 앱이 올바르게 열리는지도 확인하세요."