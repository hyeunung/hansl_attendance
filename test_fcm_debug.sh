#!/bin/bash

echo "🔍 FCM 디버깅 테스트"
echo "=================================================="
echo ""

# 설정
PROJECT_REF="qvhbigvdfyvhoegkhvef"
SUPABASE_URL="https://${PROJECT_REF}.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/send_fcm_notification"
TEST_EMAIL="test@hansl.com"

# 1. 환경변수 확인
echo "1️⃣ 환경변수 확인..."
echo "   SUPABASE_URL: ${SUPABASE_URL}"
echo "   SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."
echo ""

# 2. 가장 간단한 테스트
echo "2️⃣ 최소 데이터로 테스트..."
RESPONSE=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"user\",
    \"user_email\": \"${TEST_EMAIL}\",
    \"title\": \"Test\",
    \"body\": \"Test message\"
  }")

echo "응답: $RESPONSE"
echo ""

# 3. data 필드 없이 테스트
echo "3️⃣ data 필드 없이 테스트..."
RESPONSE2=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"user\",
    \"user_email\": \"${TEST_EMAIL}\",
    \"title\": \"No Data Test\",
    \"body\": \"Testing without data field\"
  }")

echo "응답: $RESPONSE2"
echo ""

# 4. 문자열 data로 테스트
echo "4️⃣ 문자열 data 필드로 테스트..."
RESPONSE3=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"type\": \"user\",
    \"user_email\": \"${TEST_EMAIL}\",
    \"title\": \"String Data Test\",
    \"body\": \"Testing with string data\",
    \"data\": {
      \"type\": \"test\",
      \"message\": \"hello\"
    }
  }")

echo "응답: $RESPONSE3"
echo ""

echo "✅ 테스트 완료"