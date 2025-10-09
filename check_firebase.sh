#\!/bin/bash

echo "🔍 Firebase 서비스 계정 확인 중..."

# Supabase에서 Firebase 서비스 계정 정보 가져오기
SERVICE_ACCOUNT=$(supabase secrets get FIREBASE_SERVICE_ACCOUNT_JSON 2>/dev/null)

if [ -z "$SERVICE_ACCOUNT" ]; then
  echo "❌ Firebase 서비스 계정을 가져올 수 없습니다"
  exit 1
fi

# JSON 파싱해서 project_id 확인
PROJECT_ID=$(echo "$SERVICE_ACCOUNT" | jq -r '.project_id' 2>/dev/null)
CLIENT_EMAIL=$(echo "$SERVICE_ACCOUNT" | jq -r '.client_email' 2>/dev/null)

echo "📱 Firebase 프로젝트 정보:"
echo "   Project ID: $PROJECT_ID"
echo "   Service Account: $CLIENT_EMAIL"

# private_key가 있는지 확인
PRIVATE_KEY=$(echo "$SERVICE_ACCOUNT" | jq -r '.private_key' 2>/dev/null)
if [ -n "$PRIVATE_KEY" ]; then
  echo "   ✅ Private Key 존재함"
else
  echo "   ❌ Private Key 없음"
fi

echo ""
echo "💡 Firebase Console에서 다음을 확인하세요:"
echo "   1. https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk"
echo "   2. 서비스 계정이 활성화되어 있는지"
echo "   3. Cloud Messaging API가 활성화되어 있는지"
