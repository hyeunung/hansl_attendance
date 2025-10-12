#!/bin/bash

echo "🚀 한슬 앱 푸시 알림 종합 테스트"
echo "================================="
echo ""

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78"
SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"

# 테스트할 이메일 목록
EMAILS=(
    "scott@thefiveforest.com"
    "test@hansl.com"
    "admin@hansl.com"
)

echo -e "${BLUE}📧 테스트 대상 계정:${NC}"
for email in "${EMAILS[@]}"; do
    echo "   - $email"
done
echo ""

# 각 이메일에 대해 테스트
for email in "${EMAILS[@]}"; do
    echo -e "${YELLOW}📱 $email 계정 테스트${NC}"
    echo "----------------------------------------"
    
    # 1. 기본 알림 테스트
    echo -e "${GREEN}1️⃣ 기본 알림${NC}"
    result=$(curl -s -X POST \
        "$SUPABASE_URL/functions/v1/send_fcm_notification" \
        -H "Authorization: Bearer $SERVICE_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "targetEmail": "'$email'",
            "title": "🔔 한슬 테스트 알림",
            "body": "푸시 알림이 정상 작동합니다! ('"$(date +%H:%M:%S)"')",
            "notificationType": "test"
        }')
    
    success=$(echo $result | jq -r '.success')
    if [ "$success" = "true" ]; then
        echo -e "   ${GREEN}✅ 성공${NC}"
    else
        message=$(echo $result | jq -r '.message')
        echo -e "   ${RED}❌ 실패: $message${NC}"
    fi
    
    sleep 1
    
    # 2. 연차 승인 알림
    echo -e "${GREEN}2️⃣ 연차 승인${NC}"
    result=$(curl -s -X POST \
        "$SUPABASE_URL/functions/v1/send_fcm_notification" \
        -H "Authorization: Bearer $SERVICE_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "targetEmail": "'$email'",
            "title": "✅ 연차 승인 완료",
            "body": "2025-10-15 연차가 승인되었습니다",
            "notificationType": "leave_approved",
            "data": {
                "type": "leave_approval",
                "leave_id": "test_leave_123"
            }
        }')
    
    success=$(echo $result | jq -r '.success')
    if [ "$success" = "true" ]; then
        echo -e "   ${GREEN}✅ 성공${NC}"
    else
        echo -e "   ${RED}❌ 실패${NC}"
    fi
    
    sleep 1
    
    # 3. 발주 승인 요청
    echo -e "${GREEN}3️⃣ 발주 승인 요청${NC}"
    result=$(curl -s -X POST \
        "$SUPABASE_URL/functions/v1/send_fcm_notification" \
        -H "Authorization: Bearer $SERVICE_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "targetEmail": "'$email'",
            "title": "🆕 새 발주 승인 요청",
            "body": "노트북 구매 요청이 있습니다 (3,000,000원)",
            "notificationType": "purchase_request",
            "data": {
                "type": "purchase_approval_request",
                "purchase_id": "PO-2025-TEST"
            }
        }')
    
    success=$(echo $result | jq -r '.success')
    if [ "$success" = "true" ]; then
        echo -e "   ${GREEN}✅ 성공${NC}"
    else
        echo -e "   ${RED}❌ 실패${NC}"
    fi
    
    echo ""
done

echo -e "${BLUE}📊 테스트 요약${NC}"
echo "================================="
echo "1. FCM 토큰이 등록된 계정만 알림을 받습니다"
echo "2. 앱에 로그인하고 알림 권한을 허용해야 합니다"
echo "3. 실제 기기에서 확인이 필요합니다"
echo ""
echo -e "${YELLOW}💡 팁:${NC}"
echo "- iOS: 설정 > 알림 > 한슬에서 알림 권한 확인"
echo "- Android: 설정 > 앱 > 한슬 > 알림에서 권한 확인"
echo ""
echo "✅ 테스트 완료!"
