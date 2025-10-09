#!/bin/bash

echo "======================================"
echo "Firebase 키 재설정 (기존 파일 사용)"
echo "======================================"
echo ""
echo "기존 Firebase 서비스 계정 JSON 파일 경로를 입력하세요:"
echo "(보통 ~/Downloads 폴더에 있습니다)"
echo ""

# 일반적인 경로 제안
echo "예시:"
echo "  ~/Downloads/hansl-firebase-adminsdk-xxxxx-xxxxxxxxxx.json"
echo "  ~/Desktop/firebase-service-account.json"
echo ""

read -p "JSON 파일 경로: " json_path

# ~ 를 실제 경로로 변환
json_path="${json_path/#\~/$HOME}"

if [ ! -f "$json_path" ]; then
    echo "❌ 파일을 찾을 수 없습니다: $json_path"
    exit 1
fi

echo ""
echo "파일 찾음: $json_path"
echo "파일 크기: $(wc -c < "$json_path") bytes"

# JSON 내용 읽기
json_content=$(cat "$json_path")

# 프로젝트 ID 확인
project_id=$(echo "$json_content" | python3 -c "import sys, json; print(json.load(sys.stdin).get('project_id', 'unknown'))")
echo "프로젝트 ID: $project_id"

echo ""
echo "Supabase Secrets 업데이트 중..."
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$json_content" --project-ref qvhbigvdfyvhoegkhvef

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 성공적으로 재설정되었습니다!"
    echo ""
    echo "Edge Function 재시작을 위해 1-2분 기다린 후 테스트하세요."
    echo ""
    echo "테스트 명령:"
    echo "  bash test_fcm_direct.sh"
else
    echo "❌ 업데이트 실패"
fi