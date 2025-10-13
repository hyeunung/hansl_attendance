#!/bin/bash

echo "🔔 문의하기 푸시 알림 테스트"
echo "================================="
echo ""

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Supabase 설정
PROJECT_ID="qvhbigvdfyvhoegkhvef"

echo "📝 테스트 1: 새 문의 생성 (app_admin에게 알림)"
echo "------------------------------------------------"

# SQL로 직접 문의 생성
npx supabase db execute --project-ref $PROJECT_ID --sql "
INSERT INTO support_inquires (
  user_id,
  user_email, 
  user_name,
  inquiry_type,
  subject,
  message,
  status
) VALUES (
  '5030c4ac-dc25-457e-bf0d-259533663335'::uuid,
  'test@hansl.com',
  'test',
  'other',
  '푸시 테스트 - ' || to_char(now() AT TIME ZONE 'Asia/Seoul', 'HH24:MI:SS'),
  '문의 생성 시 app_admin에게 푸시 알림이 전송되는지 테스트',
  'open'
) RETURNING id, subject;
"

echo -e "${GREEN}✅ 문의 생성 완료${NC}"
echo ""
echo "⏳ 5초 대기 후 Edge Function 로그 확인..."
sleep 5

echo ""
echo "📊 Edge Function 실행 로그:"
echo "------------------------------------------------"
npx supabase functions logs notify_new_inquiry --project-ref $PROJECT_ID --tail 5

echo ""
echo "📝 테스트 2: 문의 답변 추가 (문의자에게 알림)"
echo "------------------------------------------------"

# 가장 최근 문의 ID 가져오기
INQUIRY_ID=$(npx supabase db execute --project-ref $PROJECT_ID --sql "
SELECT id FROM support_inquires 
WHERE user_email = 'test@hansl.com' 
ORDER BY created_at DESC 
LIMIT 1;
" | grep -o '[0-9]*' | head -1)

echo "문의 ID: $INQUIRY_ID"

# 문의 상태 업데이트
npx supabase db execute --project-ref $PROJECT_ID --sql "
UPDATE support_inquires 
SET 
  status = 'resolved',
  resolution_note = '테스트 답변입니다. 문의자에게 푸시 알림이 전송됩니다.',
  handled_by = 'admin',
  processed_at = now()
WHERE id = $INQUIRY_ID;
"

echo -e "${GREEN}✅ 문의 답변 추가 완료${NC}"
echo ""
echo "⏳ 5초 대기 후 Edge Function 로그 확인..."
sleep 5

echo ""
echo "📊 Edge Function 실행 로그:"
echo "------------------------------------------------"
npx supabase functions logs notify_inquiry_response --project-ref $PROJECT_ID --tail 5

echo ""
echo "================================="
echo "📱 테스트 결과 확인 방법:"
echo "================================="
echo "1. app_admin 계정 휴대폰: '새로운 문의가 접수되었습니다' 알림 확인"
echo "2. test@hansl.com 계정 휴대폰: '문의 답변이 도착했습니다' 알림 확인"
echo ""
echo -e "${YELLOW}💡 알림이 오지 않는다면:${NC}"
echo "   - 해당 계정의 FCM 토큰이 등록되어 있는지 확인"
echo "   - 앱이 백그라운드 또는 포그라운드 상태인지 확인"
echo "   - 휴대폰의 알림 설정이 켜져 있는지 확인"
echo ""
echo "테스트 완료!"