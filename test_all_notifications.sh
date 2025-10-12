#\!/bin/bash

echo "🚀 HANSL 푸시 알림 종합 테스트"
echo "================================="
echo "📧 대상: test@hansl.com"
echo "📅 시간: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78"
SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"

echo "1️⃣ 기본 FCM 테스트"
echo "-------------------"
curl -s -X POST \
  "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "📢 기본 알림 테스트",
    "body": "Firebase 키 교체 후 정상 작동 확인",
    "notificationType": "test"
  }' | jq '.'

sleep 2

echo -e "\n2️⃣ 연차 승인 알림 테스트"
echo "------------------------"
curl -s -X POST \
  "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "✅ 연차 승인 완료",
    "body": "2025-01-27 연차가 승인되었습니다",
    "notificationType": "leave_approved",
    "data": {
      "type": "leave_approval",
      "leave_id": "test_123",
      "status": "approved"
    }
  }' | jq '.'

sleep 2

echo -e "\n3️⃣ 연차 반려 알림 테스트"
echo "------------------------"
curl -s -X POST \
  "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "❌ 연차 반려",
    "body": "2025-01-28 연차가 반려되었습니다. 사유: 업무 일정",
    "notificationType": "leave_rejected",
    "data": {
      "type": "leave_rejection",
      "leave_id": "test_124",
      "status": "rejected",
      "reason": "업무 일정으로 인한 반려"
    }
  }' | jq '.'

sleep 2

echo -e "\n4️⃣ 구매 요청 승인 알림"
echo "----------------------"
curl -s -X POST \
  "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "💰 구매 요청 승인",
    "body": "노트북 구매 요청이 승인되었습니다",
    "notificationType": "purchase_approved",
    "data": {
      "type": "purchase_approval",
      "purchase_id": "PO-2025-001",
      "status": "approved"
    }
  }' | jq '.'

sleep 2

echo -e "\n5️⃣ 출근 알림 테스트"
echo "-------------------"
curl -s -X POST \
  "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "🏢 출근 알림",
    "body": "출근 시간입니다. 출근 체크를 해주세요",
    "notificationType": "attendance_reminder",
    "data": {
      "type": "check_in_reminder"
    }
  }' | jq '.'

sleep 2

echo -e "\n6️⃣ 퇴근 알림 테스트"
echo "-------------------"
curl -s -X POST \
  "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "🏠 퇴근 알림",
    "body": "퇴근 시간입니다. 퇴근 체크를 해주세요",
    "notificationType": "attendance_reminder",
    "data": {
      "type": "check_out_reminder"
    }
  }' | jq '.'

sleep 2

echo -e "\n7️⃣ 긴급 공지 알림"
echo "-----------------"
curl -s -X POST \
  "$SUPABASE_URL/functions/v1/send_fcm_notification" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetEmail": "test@hansl.com",
    "title": "🚨 긴급 공지",
    "body": "내일 오전 10시 전체 회의가 있습니다",
    "notificationType": "announcement",
    "data": {
      "type": "urgent_announcement",
      "priority": "high"
    }
  }' | jq '.'

echo -e "\n✅ 모든 테스트 완료\!"
echo "===================="
echo "📱 test@hansl.com 계정의 기기에서 알림을 확인하세요"
echo ""

# Edge Function 로그 확인 방법 안내
echo "📝 로그 확인 명령어:"
echo "npx supabase functions logs send_fcm_notification --project-ref qvhbigvdfyvhoegkhvef"
