#!/bin/bash

echo "🔍 FCM 상세 테스트"
echo ""

# 직접 Edge Function 호출해서 상세 정보 확인
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78"

echo "1️⃣ 기존 send_fcm_notification 함수 테스트"
curl -s -X POST \
  "https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "테스트 알림",
    "body": "Service Key로 전송하는 테스트",
    "notificationType": "test"
  }' | jq .

echo ""
echo "2️⃣ Edge Function 로그 확인 (최근 5개)"
echo "실행: npx supabase functions logs send_fcm_notification"
echo ""

# 실제 FCM 응답이 무엇인지 확인하기 위한 디버그 함수 호출
echo "3️⃣ Firebase 디버그 함수 호출"
curl -s -X POST \
  "https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/test-firebase-debug" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .

echo ""
echo "✅ 테스트 완료"