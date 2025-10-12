#!/bin/bash

echo "🔥 HANSL 실제 푸시 알림 완전 테스트"
echo "===================================="
echo "📧 테스트 계정: test@hansl.com"
echo "📅 시간: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78"
SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"

echo "========================================="
echo "🔔 1. send_fcm_notification 직접 테스트"
echo "========================================="

echo -e "\n1-1. 기본 테스트 알림"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "✅ 테스트 시작",
    "body": "Firebase 키 교체 후 정상 작동 확인!",
    "notificationType": "test"
  }' | jq '.'

sleep 1

echo -e "\n1-2. 연차 승인 알림"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "✅ 연차 승인",
    "body": "10/20 연차가 승인되었습니다",
    "notificationType": "leave_approved",
    "data": {
      "type": "leave",
      "status": "approved",
      "leave_id": "645"
    }
  }' | jq '.'

sleep 1

echo -e "\n1-3. 연차 반려 알림"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "❌ 연차 반려",
    "body": "연차가 반려되었습니다 (업무 일정)",
    "notificationType": "leave_rejected",
    "data": {
      "type": "leave",
      "status": "rejected",
      "reason": "업무 일정"
    }
  }' | jq '.'

sleep 1

echo -e "\n1-4. 출장 승인 알림"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "✅ 출장 승인",
    "body": "서울 출장이 승인되었습니다",
    "notificationType": "business_trip_approved",
    "data": {
      "type": "business_trip",
      "status": "approved",
      "destination": "서울"
    }
  }' | jq '.'

sleep 1

echo -e "\n1-5. 구매 요청 승인 알림"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "💰 구매 승인",
    "body": "노트북 구매가 승인되었습니다",
    "notificationType": "purchase_approved",
    "data": {
      "type": "purchase",
      "status": "approved",
      "item": "노트북"
    }
  }' | jq '.'

sleep 1

echo -e "\n1-6. 구매 요청 반려 알림"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "❌ 구매 반려",
    "body": "구매 요청이 반려되었습니다 (예산 초과)",
    "notificationType": "purchase_rejected",
    "data": {
      "type": "purchase",
      "status": "rejected",
      "reason": "예산 초과"
    }
  }' | jq '.'

sleep 1

echo -e "\n1-7. 출근 알림"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "🏢 출근 알림",
    "body": "출근 체크를 해주세요",
    "notificationType": "attendance_reminder",
    "data": {
      "type": "check_in"
    }
  }' | jq '.'

sleep 1

echo -e "\n1-8. 퇴근 알림"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "🏠 퇴근 알림",
    "body": "퇴근 체크를 해주세요",
    "notificationType": "attendance_reminder",
    "data": {
      "type": "check_out"
    }
  }' | jq '.'

sleep 1

echo -e "\n1-9. 입고 완료 알림"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "📦 입고 완료",
    "body": "노트북이 입고되었습니다",
    "notificationType": "item_received",
    "data": {
      "type": "receiving",
      "item": "노트북",
      "status": "completed"
    }
  }' | jq '.'

sleep 1

echo -e "\n1-10. 긴급 공지"
curl -s -X POST "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "🚨 긴급 공지",
    "body": "내일 오전 10시 전체 회의",
    "notificationType": "urgent_notice",
    "data": {
      "type": "announcement",
      "priority": "high"
    }
  }' | jq '.'

echo ""
echo "========================================="
echo "📊 테스트 결과 요약"
echo "========================================="
echo ""
echo "✅ 10개 알림 유형 테스트 완료:"
echo "  1. 기본 테스트 알림"
echo "  2. 연차 승인 알림"
echo "  3. 연차 반려 알림"
echo "  4. 출장 승인 알림"
echo "  5. 구매 요청 승인 알림"
echo "  6. 구매 요청 반려 알림"
echo "  7. 출근 알림"
echo "  8. 퇴근 알림"
echo "  9. 입고 완료 알림"
echo "  10. 긴급 공지 알림"
echo ""
echo "📱 test@hansl.com 기기에서 위 10개의 알림을 모두 확인하세요!"
echo ""
echo "🔑 사용된 기능:"
echo "  - Edge Function: send_fcm_notification"
echo "  - Firebase 키: 27bf4ce73f (새로 교체된 키)"
echo "  - Service Role Key 사용"
echo ""
echo "📝 Edge Function 로그 확인:"
echo "npx supabase functions logs send_fcm_notification --project-ref qvhbigvdfyvhoegkhvef"