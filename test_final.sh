#\!/bin/bash

# Edge Function 직접 호출 테스트
echo "📱 푸시 알림 최종 테스트..."

# Supabase 정보
SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"
ANON_KEY=$(grep SUPABASE_ANON_KEY .env | cut -d '=' -f2 | tr -d '"')

# 테스트용 사용자 정보
TEST_NAME="이호석"
TEST_DEPT="개발3팀"

echo "🔍 테스트 정보:"
echo "   이름: $TEST_NAME"
echo "   부서: $TEST_DEPT"
echo ""

# Edge Function 직접 호출
echo "📮 Edge Function 호출 중..."
curl -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"admin\",
    \"title\": \"🔔 푸시 알림 테스트\",
    \"body\": \"${TEST_NAME}님이 연차를 신청했습니다\",
    \"data\": {
      \"type\": \"leave_request\",
      \"requester_name\": \"${TEST_NAME}\"
    },
    \"requester_department\": \"${TEST_DEPT}\",
    \"requester_name\": \"${TEST_NAME}\",
    \"is_manager_request\": false
  }" | jq '.'

echo ""
echo "✅ 테스트 완료. 휴대폰에서 알림을 확인하세요."
