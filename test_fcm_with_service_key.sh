#!/bin/bash

# Service Key를 사용한 FCM 푸시 알림 테스트 스크립트
# Anon Key 대신 Service Role Key 사용

# 환경 변수 설정
source .env

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Supabase 설정
SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"
SERVICE_KEY="${SUPABASE_SERVICE_KEY}"

echo -e "${BLUE}=== FCM 푸시 알림 테스트 (Service Key 사용) ===${NC}"
echo -e "${YELLOW}사용 중인 Service Key (첫 50자): ${SERVICE_KEY:0:50}...${NC}"
echo ""

# 테스트 함수
test_fcm_notification() {
    local test_name="$1"
    local title="$2"
    local body="$3"
    local target_email="$4"
    local notification_type="$5"
    
    echo -e "${BLUE}--- $test_name 테스트 ---${NC}"
    echo "대상: $target_email"
    echo "타입: $notification_type"
    
    # Service Key를 사용한 API 호출
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        "$SUPABASE_URL/functions/v1/send_fcm_notification" \
        -H "Authorization: Bearer $SERVICE_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"$title\",
            \"body\": \"$body\",
            \"targetEmail\": \"$target_email\",
            \"notificationType\": \"$notification_type\",
            \"data\": {
                \"click_action\": \"FLUTTER_NOTIFICATION_CLICK\",
                \"sound\": \"default\",
                \"priority\": \"high\"
            }
        }")
    
    # HTTP 상태 코드 추출
    http_code=$(echo "$response" | tail -n1)
    body_response=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ 성공! HTTP: $http_code${NC}"
        echo "응답: $body_response"
    else
        echo -e "${RED}❌ 실패! HTTP: $http_code${NC}"
        echo "에러: $body_response"
    fi
    
    echo ""
    sleep 2
}

# 다양한 시나리오 테스트
echo -e "${YELLOW}1. 일반 알림 테스트${NC}"
test_fcm_notification \
    "일반 알림" \
    "서비스 키 테스트" \
    "Service Role Key를 사용한 푸시 알림 테스트입니다." \
    "test@hansl.com" \
    "general"

echo -e "${YELLOW}2. 연차 승인 알림 테스트${NC}"
test_fcm_notification \
    "연차 승인" \
    "연차 신청이 승인되었습니다" \
    "2025-01-27 연차가 승인되었습니다. (Service Key)" \
    "test@hansl.com" \
    "leave_approved"

echo -e "${YELLOW}3. 출근 알림 테스트${NC}"
test_fcm_notification \
    "출근 알림" \
    "출근 시간입니다" \
    "09:00 출근 시간입니다. 출근 처리를 해주세요. (Service Key)" \
    "test@hansl.com" \
    "attendance_reminder"

echo -e "${YELLOW}4. 구매 승인 요청 테스트${NC}"
test_fcm_notification \
    "구매 승인" \
    "구매 승인 요청" \
    "노트북 구매 승인이 필요합니다. (Service Key)" \
    "test@hansl.com" \
    "purchase_approval"

echo -e "${YELLOW}5. 긴급 알림 테스트${NC}"
test_fcm_notification \
    "긴급 알림" \
    "🚨 긴급 공지사항" \
    "즉시 확인이 필요한 긴급 사항입니다. (Service Key)" \
    "test@hansl.com" \
    "urgent"

# Edge Function 로그 확인
echo -e "${BLUE}=== Edge Function 로그 확인 ===${NC}"
echo "최근 로그를 확인하려면 다음 명령어를 실행하세요:"
echo -e "${GREEN}npx supabase functions logs send_fcm_notification --project-ref qvhbigvdfyvhoegkhvef${NC}"

echo ""
echo -e "${BLUE}=== 테스트 완료 ===${NC}"
echo -e "${YELLOW}참고사항:${NC}"
echo "1. Service Role Key는 모든 RLS 정책을 우회합니다"
echo "2. Production에서는 보안상 Service Key 사용을 최소화해야 합니다"
echo "3. 테스트 계정(test@hansl.com)의 기기에서 알림을 확인하세요"