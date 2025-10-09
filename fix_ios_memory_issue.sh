#!/bin/bash

echo "🔧 iOS 메모리 보호 충돌 문제 해결 중..."

# 1. Flutter 클린
echo "1️⃣ Flutter 클린..."
cd /Users/scott/workspace/hansl
flutter clean

# 2. iOS 빌드 캐시 클리어
echo "2️⃣ iOS 빌드 캐시 삭제..."
cd ios
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf Pods
rm -rf .symlinks
rm -rf Podfile.lock
rm -rf ~/Library/Caches/CocoaPods

# 3. Pod 재설치
echo "3️⃣ CocoaPods 재설치..."
pod deintegrate
pod cache clean --all
pod install --repo-update

# 4. Flutter pub get
echo "4️⃣ Flutter 의존성 재설치..."
cd ..
flutter pub get

echo "✅ 완료! 이제 Xcode에서 다음을 수행하세요:"
echo ""
echo "📱 Xcode에서:"
echo "1. Product > Clean Build Folder (Shift+Cmd+K)"
echo "2. Runner target 선택"
echo "3. Build Settings 탭"
echo "4. 'Other Linker Flags' 검색"
echo "5. Debug 구성에 추가: -ld_classic"
echo ""
echo "또는 다시 실행해보세요:"
echo "flutter run --release"