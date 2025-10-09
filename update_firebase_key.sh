#!/bin/bash

echo "======================================"
echo "Firebase 서비스 계정 키 업데이트 스크립트"
echo "======================================"
echo ""
echo "1. Firebase Console에서 새 서비스 계정 키를 다운로드하셨나요?"
echo "   https://console.firebase.google.com/project/[YOUR_PROJECT]/settings/serviceaccounts/adminsdk"
echo ""
echo "2. 다운로드한 JSON 파일의 전체 경로를 입력하세요:"
read -p "JSON 파일 경로: " json_path

if [ ! -f "$json_path" ]; then
    echo "❌ 파일을 찾을 수 없습니다: $json_path"
    exit 1
fi

# JSON 파일 내용 읽기
json_content=$(cat "$json_path")

# 올바른 형식인지 간단히 확인
if [[ ! "$json_content" == *"private_key"* ]]; then
    echo "❌ 올바른 Firebase 서비스 계정 JSON 파일이 아닙니다."
    exit 1
fi

echo ""
echo "3. Supabase에 업데이트 중..."

# Supabase secrets 업데이트
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$json_content" --project-ref qvhbigvdfyvhoegkhvef

if [ $? -eq 0 ]; then
    echo "✅ Firebase 서비스 계정 키가 성공적으로 업데이트되었습니다!"
    echo ""
    echo "4. Edge Function이 자동으로 재시작됩니다."
    echo "5. 1-2분 후 푸시 알림을 테스트해보세요."
else
    echo "❌ 업데이트 실패. Supabase CLI 로그인 상태를 확인하세요."
    echo "   supabase login"
fi