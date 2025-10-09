#\!/bin/bash

echo "🔍 Firebase 문제 디버깅..."
echo ""

# 1. 최근 Edge Function 로그 확인
echo "📋 최근 Edge Function 로그 (Firebase 관련):"
supabase functions logs send_fcm_notification --limit 5 | grep -E "(Firebase|FCM|401|UNAUTHENTICATED|service account)" | head -20

echo ""
echo "🔍 가능한 원인들:"
echo "1. ❓ Firebase 프로젝트의 Cloud Messaging API가 비활성화됨"
echo "   → https://console.cloud.google.com/apis/library/fcm.googleapis.com"
echo ""
echo "2. ❓ Firebase 프로젝트 할당량 초과"
echo "   → 무료 플랜: 하루 1,000건 제한"
echo ""  
echo "3. ❓ Firebase 서비스 계정 키가 만료됨"
echo "   → Firebase Console에서 새 키 생성 필요"
echo ""
echo "4. ❓ Supabase secrets의 JSON이 손상됨"
echo "   → Secrets 재설정 필요"
echo ""

echo "💡 즉시 확인할 사항:"
echo "1. Firebase Console → 프로젝트 설정 → Cloud Messaging 탭"
echo "   - Server Key가 활성화되어 있는지"
echo "   - API가 활성화되어 있는지"
echo ""
echo "2. Google Cloud Console → APIs & Services"
echo "   - Firebase Cloud Messaging API 상태 확인"
echo "   - 할당량 확인"
