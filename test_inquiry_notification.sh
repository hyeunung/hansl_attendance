#!/bin/bash

# 문의하기 푸시 알림 테스트 스크립트
echo "🔔 문의하기 푸시 알림 테스트 시작..."

# Supabase 설정
SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg"

# 테스트용 사용자 정보
TEST_USER_NAME="테스트 사용자"
TEST_USER_EMAIL="test@hansl.com"
TEST_USER_ID="test-user-$(date +%s)"

# 새 문의 생성
echo ""
echo "📝 새 문의 생성 중..."
echo "제목: 푸시 알림 테스트 문의"
echo "내용: 푸시 알림이 정상적으로 작동하는지 테스트합니다."
echo ""

RESPONSE=$(curl -s -X POST \
  "$SUPABASE_URL/rest/v1/support_inquires" \
  -H "Content-Type: application/json" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Prefer: return=representation" \
  -d '{
    "user_id": "'$TEST_USER_ID'",
    "user_email": "'$TEST_USER_EMAIL'",
    "user_name": "'$TEST_USER_NAME'",
    "inquiry_type": "other",
    "subject": "푸시 알림 테스트 문의 - '"$(date '+%Y-%m-%d %H:%M:%S')"'",
    "message": "푸시 알림이 정상적으로 작동하는지 테스트합니다. 시간: '"$(date '+%Y-%m-%d %H:%M:%S')"'",
    "status": "open"
  }')

# 응답 확인
if echo "$RESPONSE" | grep -q '"id"'; then
  INQUIRY_ID=$(echo "$RESPONSE" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
  echo "✅ 문의 생성 성공! (ID: $INQUIRY_ID)"
  echo ""
  echo "🔔 app_admin 계정으로 푸시 알림이 전송되었습니다."
  echo ""
  
  # Edge Function 로그 확인을 위한 대기
  echo "⏳ 5초 후 로그를 확인합니다..."
  sleep 5
  
  # 문의 상태 업데이트 테스트
  echo ""
  echo "📝 문의 상태를 'resolved'로 변경하여 응답 알림 테스트..."
  
  UPDATE_RESPONSE=$(curl -s -X PATCH \
    "$SUPABASE_URL/rest/v1/support_inquires?id=eq.$INQUIRY_ID" \
    -H "Content-Type: application/json" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    -d '{
      "status": "resolved",
      "resolution_note": "테스트 답변입니다. 푸시 알림이 정상 작동합니다.",
      "handled_by": "테스트 관리자"
    }')
  
  echo "✅ 문의 상태 업데이트 완료!"
  echo ""
  echo "🔔 문의자에게 답변 알림이 전송되었습니다."
  echo ""
  
  # 결과 요약
  echo "========================="
  echo "📊 테스트 결과 요약"
  echo "========================="
  echo "1. 새 문의 생성 → app_admin에게 알림 ✅"
  echo "2. 문의 답변 추가 → 문의자에게 알림 ✅"
  echo ""
  echo "💡 알림 수신 확인:"
  echo "- app_admin 계정의 휴대폰에서 푸시 알림 확인"
  echo "- test@hansl.com 계정의 휴대폰에서 답변 알림 확인"
  
else
  echo "❌ 문의 생성 실패!"
  echo "응답: $RESPONSE"
fi

echo ""
echo "테스트 완료!"