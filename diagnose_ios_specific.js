#!/usr/bin/env node

console.log('🔍 iOS 전용 푸시 알림 문제 진단');
console.log('============================');
console.log('📅 진단 시간:', new Date().toLocaleString('ko-KR'));
console.log('');

console.log('✅ 확인된 정상 사항:');
console.log('- 안드로이드 푸시 알림: 정상 작동');
console.log('- Firebase 서비스 계정: 정상');
console.log('- Supabase Edge Function: 정상');
console.log('- APNs 인증서: 1년 미만 (만료 아님)');
console.log('');

console.log('🚨 iOS 전용 문제 가능한 원인들:');
console.log('');

console.log('1️⃣ 🔄 iOS 18.x 업데이트 영향 (가장 가능성 높음)');
console.log('   - iOS 18.0+ APNs 보안 정책 변경');
console.log('   - 기존 FCM SDK와 호환성 문제');
console.log('   - 해결: Firebase SDK 업데이트 필요');
console.log('   - 확인: pubspec.yaml의 firebase_messaging 버전');
console.log('   - 현재: firebase_messaging: 15.1.3');
console.log('');

console.log('2️⃣ 🔐 APNs 환경 설정 불일치');
console.log('   - Development vs Production 환경 혼재');
console.log('   - Firebase Console APNs 설정과 앱 빌드 환경 불일치');
console.log('   - 해결: Firebase APNs 환경을 Production으로 통일');
console.log('');

console.log('3️⃣ 📱 iOS 디바이스 설정 변경');
console.log('   - iOS 설정 → 알림에서 HANSL 앱 알림 비활성화');
console.log('   - 집중 모드/방해금지 모드 활성화');
console.log('   - 배터리 절약 모드로 인한 백그라운드 제한');
console.log('   - 해결: iOS 설정에서 알림 권한 재확인');
console.log('');

console.log('4️⃣ 🏗️ 앱 빌드 프로비저닝 문제');
console.log('   - Xcode 프로비저닝 프로파일 변경');
console.log('   - Development vs Distribution 프로파일 혼재');
console.log('   - 해결: ios/Runner.xcodeproj 설정 재확인');
console.log('');

console.log('5️⃣ 📦 Flutter/Firebase SDK 버전 충돌');
console.log('   - Flutter 3.24.x와 Firebase SDK 호환성');
console.log('   - firebase_core와 firebase_messaging 버전 불일치');
console.log('   - 해결: flutter pub upgrade 또는 버전 다운그레이드');
console.log('');

console.log('🎯 즉시 확인할 사항:');
console.log('');

console.log('A. iOS 디바이스 알림 설정');
console.log('   설정 → 알림 → HANSL → 알림 허용 ON 확인');
console.log('   집중 모드/방해금지 모드 OFF 확인');
console.log('');

console.log('B. Firebase Console APNs 환경');
console.log('   👉 https://console.firebase.google.com/project/hansl-attendance/settings/cloudmessaging');
console.log('   APNs 인증서가 Production 환경으로 설정되어 있는지 확인');
console.log('');

console.log('C. Firebase SDK 버전');
console.log('   현재: firebase_messaging: 15.1.3');
console.log('   최신: firebase_messaging: ^15.1.3 (2024년 최신)');
console.log('   iOS 18 호환 여부 확인');
console.log('');

console.log('🚀 해결 시도 순서:');
console.log('');

console.log('1. 디바이스 알림 설정 재확인');
console.log('2. Firebase APNs 환경 Production 설정');
console.log('3. 앱 완전 삭제 → 재설치 → 알림 권한 재허용');
console.log('4. Firebase SDK 최신 버전으로 업데이트');
console.log('5. iOS 빌드 환경 재설정 (Xcode Clean Build)');
console.log('');

console.log('⚡ 빠른 테스트 방법:');
console.log('- Firebase Console에서 직접 FCM 토큰으로 테스트 메시지 전송');
console.log('- 다른 iOS 디바이스에서 동일한 계정으로 테스트');
console.log('- Development 빌드와 Production 빌드 각각 테스트');
console.log('');

console.log('💡 iOS 18 관련 참고사항:');
console.log('- iOS 18.0+ 에서 APNs 보안 정책 강화');
console.log('- 일부 Firebase SDK 버전에서 호환성 문제 보고됨');
console.log('- Firebase Console APNs 설정을 Production으로 명시적 설정 필요');