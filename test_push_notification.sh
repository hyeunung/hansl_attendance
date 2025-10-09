#!/bin/bash

echo "📱 iOS 실제 기기 푸시 알림 테스트 시작..."

# Supabase Edge Function을 통한 푸시 알림 전송
curl -X POST \
  "https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjUwMTEwMDQsImV4cCI6MjA0MDU4NzAwNH0.XljPIFR_vCCR_DZ2Ic_5SK-NRMoVJaHe3Kb9C_P2KXY" \
  -d '{
    "to": "test_device",
    "notification": {
      "title": "🔔 테스트 푸시 알림",
      "body": "iOS 실제 기기 푸시 알림 테스트 - '"$(date +%H:%M:%S)"'"
    },
    "data": {
      "type": "test",
      "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
      "message": "디버그 모드 실제 기기 테스트"
    }
  }' \
  --verbose

echo ""
echo "✅ 푸시 알림 전송 요청 완료"
echo "📱 아이폰에서 알림이 오는지 확인해주세요!"