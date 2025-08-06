#!/bin/bash

# 한슬 APK 자동 빌드 및 Google Drive 업로드 스크립트
# 사용법: ./upload_apk_to_drive.sh

set -e  # 에러 발생 시 스크립트 중단

echo "🚀 한슬 APK 빌드 및 업로드 시작..."

# 1. APK 빌드
echo "📦 APK 빌드 중..."
flutter build apk --release

if [ $? -eq 0 ]; then
    echo "✅ APK 빌드 완료!"
else
    echo "❌ APK 빌드 실패!"
    exit 1
fi

# 2. 버전 정보 가져오기
VERSION=$(grep "version:" pubspec.yaml | head -n1 | awk '{print $2}' | cut -d'+' -f1)
TIMESTAMP=$(date +%Y%m%d_%H%M)
APK_NAME="hansl_v${VERSION}_${TIMESTAMP}.apk"

# 3. Google Drive 경로 설정
GOOGLE_DRIVE_PATH="/Users/scott/Library/CloudStorage/GoogleDrive-hyeunung@gmail.com/내 드라이브/한슬_adroid_app"

# 4. APK 파일을 Google Drive에 복사
echo "☁️  Google Drive에 업로드 중..."
cp "build/app/outputs/flutter-apk/app-release.apk" "${GOOGLE_DRIVE_PATH}/${APK_NAME}"

if [ $? -eq 0 ]; then
    echo "✅ Google Drive 업로드 완료!"
    echo "📂 파일 위치: 한슬_adroid_app/${APK_NAME}"
    echo "📊 파일 크기: $(ls -lh "${GOOGLE_DRIVE_PATH}/${APK_NAME}" | awk '{print $5}')"
else
    echo "❌ Google Drive 업로드 실패!"
    exit 1
fi

# 5. 바탕화면에도 복사 (선택사항)
echo "🖥️  바탕화면에도 복사 중..."
cp "build/app/outputs/flutter-apk/app-release.apk" "$HOME/Desktop/${APK_NAME}"

echo ""
echo "🎉 모든 작업 완료!"
echo "📱 APK 파일: ${APK_NAME}"
echo "☁️  Google Drive: hyeunung@gmail.com > 한슬_adroid_app"
echo "🖥️  바탕화면: ~/Desktop/${APK_NAME}"
echo ""
echo "🔗 Google Drive에서 확인: https://drive.google.com" 