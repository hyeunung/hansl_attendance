#!/bin/bash

echo "🔍 Google Cloud 인증 직접 테스트"
echo "================================="
echo ""

# gcloud CLI로 현재 서비스 계정 확인
echo "1️⃣ Google Cloud CLI로 서비스 계정 확인:"
if command -v gcloud >/dev/null 2>&1; then
    echo "현재 프로젝트:"
    gcloud config get-value project
    echo ""
    echo "서비스 계정 목록:"
    gcloud iam service-accounts list --project=hansl-attendance 2>/dev/null || echo "  프로젝트 접근 권한이 없거나 gcloud 로그인이 필요합니다"
else
    echo "  gcloud CLI가 설치되어 있지 않습니다"
fi

echo ""
echo "2️⃣ Firebase Admin SDK 권한 확인:"
echo "  필요한 권한:"
echo "  • Firebase Admin SDK Administrator"
echo "  • Firebase Cloud Messaging API 사용 설정"
echo "  • Cloud Resource Manager API 사용 설정"

echo ""
echo "3️⃣ Firebase Console에서 확인할 사항:"
echo "  • https://console.firebase.google.com/project/hansl-attendance/settings/serviceaccounts/adminsdk"
echo "  • 서비스 계정이 활성화되어 있는지 확인"
echo "  • 마지막으로 키를 생성한 날짜 확인"

echo ""
echo "4️⃣ Google Cloud Console에서 확인:"
echo "  • https://console.cloud.google.com/iam-admin/serviceaccounts?project=hansl-attendance"
echo "  • 서비스 계정 상태 확인"
echo "  • 키 관리 탭에서 현재 키 ID 확인: f2383423feb55098cecd0ea7eb5c4583c2eff970"

echo ""
echo "5️⃣ API 활성화 상태 확인:"
echo "  • https://console.cloud.google.com/apis/library?project=hansl-attendance"
echo "  • Firebase Cloud Messaging API"
echo "  • Identity and Access Management (IAM) API"
echo "  • Cloud Resource Manager API"