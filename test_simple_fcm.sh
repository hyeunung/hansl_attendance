#!/bin/bash

# 간단한 FCM 테스트

echo "🚀 간단한 FCM 테스트 시작"
echo ""

# Service Key 사용
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78"

echo "📤 test-fcm-simple 함수 호출중..."
response=$(curl -s -w "\n%{http_code}" \
  -X POST \
  "https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/test-fcm-simple" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{}")

# HTTP 상태 코드와 응답 본문 분리
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Status: $http_code"
echo ""
echo "Response:"
echo "$body" | jq . 2>/dev/null || echo "$body"

echo ""
echo "✅ 테스트 완료"