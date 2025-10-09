#\!/bin/bash

echo "🔍 Supabase API 키 확인 중..."

# .env 파일에서 키 가져오기
if [ -f .env ]; then
  ANON_KEY=$(grep SUPABASE_ANON_KEY .env | cut -d '=' -f2 | tr -d '"')
  SERVICE_KEY=$(grep SUPABASE_SERVICE_ROLE_KEY .env | cut -d '=' -f2 | tr -d '"')
  URL=$(grep SUPABASE_URL .env | cut -d '=' -f2 | tr -d '"')
  
  echo "📋 로컬 .env 설정:"
  echo "   URL: ${URL:0:40}..."
  echo "   ANON_KEY: ${ANON_KEY:0:20}...${ANON_KEY: -10}"
  echo "   SERVICE_KEY: ${SERVICE_KEY:0:20}...${SERVICE_KEY: -10}"
fi

echo ""
echo "🌐 Supabase 원격 시크릿 확인..."

# Supabase에 설정된 키들 확인
supabase secrets list | grep -E "(SUPABASE_URL|SUPABASE_ANON_KEY|SUPABASE_SERVICE_ROLE_KEY)"

echo ""
echo "🔄 Edge Function 테스트 (ANON_KEY 사용)..."

# ANON_KEY로 Edge Function 호출 테스트
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"test"}' 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "   HTTP 상태 코드: $HTTP_CODE"
if [ "$HTTP_CODE" = "401" ]; then
  echo "   ❌ ANON_KEY 인증 실패\!"
elif [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ ANON_KEY 정상 작동"
else
  echo "   ⚠️ 예상치 못한 응답: $HTTP_CODE"
fi

echo ""
echo "💡 확인사항:"
echo "   1. Supabase 대시보드의 API 키와 일치하는지"
echo "   2. 키가 만료되지 않았는지"
echo "   3. RLS 정책이 변경되지 않았는지"
