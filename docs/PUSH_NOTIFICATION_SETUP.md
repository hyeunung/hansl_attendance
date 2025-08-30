# 📱 HANSL 앱 푸시 알림 설정 가이드

## 🚨 현재 문제 진단

### 알림이 안 오는 이유 체크리스트

#### iOS
- [ ] **실제 기기**에서 테스트 중인가? (시뮬레이터는 푸시 알림 불가)
- [ ] **APNs 인증서/P8 키**를 Firebase에 업로드했는가?
- [ ] Xcode에서 **Push Notifications Capability**를 추가했는가?
- [ ] **Background Modes > Remote notifications**를 체크했는가?
- [ ] Info.plist에 `FirebaseAppDelegateProxyEnabled = YES` 설정이 있는가?

#### Android
- [ ] `android/app/google-services.json` 파일이 있는가?
- [ ] Firebase Console에 **SHA-1/SHA-256 지문**을 등록했는가?
- [ ] Android 13+ 기기에서 **알림 권한**을 허용했는가?
- [ ] AndroidManifest.xml에 **notification channel** 설정이 있는가?

## 🔧 즉시 해결 방법

### 1. iOS 설정 (Xcode)

```bash
# 1. Runner.xcworkspace 열기
cd ios
open Runner.xcworkspace

# 2. Signing & Capabilities 탭에서:
- "+ Capability" 클릭
- "Push Notifications" 추가
- "Background Modes" 추가 → "Remote notifications" 체크

# 3. Info.plist에 추가:
<key>FirebaseAppDelegateProxyEnabled</key>
<true/>
```

### 2. Firebase Console 설정

#### APNs P8 키 생성 및 업로드 (권장)

1. [Apple Developer](https://developer.apple.com) 접속
2. Keys → Create a Key
3. "Apple Push Notifications service (APNs)" 체크
4. Download .p8 파일
5. Firebase Console → Project Settings → Cloud Messaging
6. iOS app configuration → APNs Authentication Key 업로드
7. Key ID와 Team ID 입력

### 3. Android 설정

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application>
    <!-- FCM 기본 채널 설정 -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="high_importance_channel" />
    
    <!-- FCM 기본 아이콘 -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@drawable/ic_notification" />
</application>
```

### 4. Flutter 코드 수정

```dart
// lib/services/notification_service.dart 에 추가

// Android 13+ 권한 요청
static Future<void> requestNotificationPermission() async {
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('✅ 알림 권한 승인됨');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('⚠️ 임시 알림 권한');
  } else {
    print('❌ 알림 권한 거부됨');
  }
}

// 앱 시작 시 호출
static Future<void> initialize() async {
  await requestNotificationPermission();
  // 기존 초기화 코드...
}
```

## 📱 앱 출시 전 필수 체크리스트

### iOS App Store 출시
- [ ] **Production APNs 인증서** Firebase 업로드
- [ ] **aps-environment: production** Entitlements 설정
- [ ] **Privacy Manifest** 파일 추가 (2024년 필수)
- [ ] 실제 기기에서 TestFlight 테스트

### Google Play Store 출시
- [ ] **Production google-services.json** 사용
- [ ] **SHA-1/SHA-256** Production 지문 등록
- [ ] **Android 13+ 권한 처리** 코드 구현
- [ ] **Notification Channel** 생성 코드

## 🔍 디버깅 명령어

```bash
# FCM 토큰 확인 (Flutter 콘솔)
flutter: ✅ FCM Token: [토큰값]

# iOS 푸시 인증서 확인
openssl x509 -in aps_production.cer -inform DER -text -noout

# Android SHA 지문 확인
keytool -list -v -keystore android/app/key.jks

# Firebase 프로젝트 확인
firebase projects:list
```

## ⚠️ 자주 발생하는 문제

### "No FCM tokens found" 오류
- **원인**: 직원들이 앱을 설치하지 않았거나 알림 권한 거부
- **해결**: 
  1. 해당 직원들에게 앱 재설치 요청
  2. 설정 > 알림 > HANSL 앱 > 알림 허용 확인

### iOS 디버그 모드에서만 작동
- **원인**: Development 인증서만 설정됨
- **해결**: Production APNs 인증서도 Firebase에 업로드

### Android 13+에서 알림 안 옴
- **원인**: 런타임 권한 요청 안 함
- **해결**: 앱 첫 실행 시 `requestPermission()` 호출

## 📞 긴급 지원

문제가 지속되면:
1. Firebase Console > Cloud Messaging 탭에서 테스트 메시지 전송
2. Xcode/Android Studio 콘솔 로그 확인
3. `flutter doctor -v` 실행하여 환경 확인

---

작성일: 2024-12-26
버전: 1.0.0