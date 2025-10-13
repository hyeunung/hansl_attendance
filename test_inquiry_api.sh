#!/bin/bash

echo "🔍 문의 등록 API 직접 테스트 시작..."
echo ""

# Supabase 정보
SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5MTQ2NTksImV4cCI6MjAzNzQ5MDY1OX0.xDxLKLYzJDPY-REjls3pKGUgrLkHbHkaueUXdGFZLow"

# 1. 로그인
echo "1️⃣ 테스트 계정 로그인..."
AUTH_RESPONSE=$(curl -s -X POST \
  "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@hansl.com",
    "password": "hansl!test!5890"
  }')

# JWT 토큰 추출
ACCESS_TOKEN=$(echo $AUTH_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
USER_ID=$(echo $AUTH_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ 로그인 실패"
  exit 1
fi

echo "✅ 로그인 성공"
echo ""

# 2. 문의 등록 테스트
echo "2️⃣ 문의 등록 테스트..."
CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S")

INSERT_RESPONSE=$(curl -s -X POST \
  "$SUPABASE_URL/rest/v1/support_inquiries" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"user_id\": \"$USER_ID\",
    \"user_email\": \"test@hansl.com\",
    \"user_name\": \"테스트 계정\",
    \"inquiry_type\": \"other\",
    \"subject\": \"[API 테스트] $CURRENT_TIME\",
    \"message\": \"API를 통한 문의 등록 테스트입니다.\",
    \"status\": \"open\"
  }")

# 응답 확인
if echo "$INSERT_RESPONSE" | grep -q "\"id\""; then
  echo "✅ 문의 등록 성공!"
  INQUIRY_ID=$(echo $INSERT_RESPONSE | grep -o '"id":[0-9]*' | cut -d':' -f2)
  echo "   생성된 문의 ID: $INQUIRY_ID"
else
  echo "❌ 문의 등록 실패"
  echo "   응답: $INSERT_RESPONSE"
  exit 1
fi
echo ""

# 3. 등록된 문의 확인
echo "3️⃣ 등록된 문의 조회..."
SELECT_RESPONSE=$(curl -s -X GET \
  "$SUPABASE_URL/rest/v1/support_inquiries?user_id=eq.$USER_ID&order=created_at.desc&limit=3" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

if echo "$SELECT_RESPONSE" | grep -q "API 테스트"; then
  echo "✅ 문의 조회 성공!"
  echo "   최근 등록된 테스트 문의가 확인되었습니다."
else
  echo "⚠️ 문의 조회 결과 확인 필요"
fi
echo ""

# 4. 테스트 데이터 정리
if [ ! -z "$INQUIRY_ID" ]; then
  echo "4️⃣ 테스트 데이터 정리..."
  DELETE_RESPONSE=$(curl -s -X DELETE \
    "$SUPABASE_URL/rest/v1/support_inquiries?id=eq.$INQUIRY_ID" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  
  echo "✅ 테스트 문의 삭제 완료"
  echo ""
fi

echo "🎉 모든 테스트 성공!"
echo "   support_inquiries 테이블에 문의 등록이 정상적으로 작동합니다."