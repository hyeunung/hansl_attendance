#!/bin/bash

# Supabase Edge Function 직접 테스트 스크립트

SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjY0Njg5OTgsImV4cCI6MjA0MjA0NDk5OH0.Y0eqT7F9rJJnEqYP9DLSvnKJG97S0DW0HuLKBEy2VYo"

echo "📋 구매 요청 알림 테스트"
echo "========================="

# 구매 요청 알림 테스트 (purchase_requests 타입)
echo "1. 구매 요청 알림 테스트 (purchase_requests 타입)..."
curl -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "purchase_requests",
    "purchase_order_number": "CURL-TEST-'$(date +%H%M%S)'",
    "requester_name": "CURL 테스터",
    "vendor_name": "테스트 공급업체",
    "payment_category": "구매 요청",
    "skip_db_notification": false
  }' \
  -s | jq .

echo ""
echo "========================="
echo "테스트 완료"