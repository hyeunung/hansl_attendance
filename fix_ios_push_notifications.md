# iOS 푸시 알림 문제 해결 가이드

## 🔍 문제 진단 결과

Android는 푸시 알림이 오는데 iOS만 안 오는 상황입니다. 다음 설정을 확인해주세요:

## 1️⃣ Xcode에서 Push Notifications Capability 추가 (가장 중요!)

```bash
# Terminal에서
cd /Users/scott/workspace/hansl/ios
open Runner.xcworkspace
```

Xcode에서:
1. **Runner** 프로젝트 선택
2. **Signing & Capabilities** 탭 클릭
3. **+ Capability** 버튼 클릭
4. **Push Notifications** 검색해서 추가
5. **Background Modes** 도 추가하고 **Remote notifications** 체크

## 2️⃣ Firebase Console에서 APNs 설정 확인

[Firebase Console](https://console.firebase.google.com/project/hansl-attendance/settings/cloudmessaging) 접속 후:

### Apple 앱 구성 섹션에서 확인할 사항:
- **APNs 인증 키**가 업로드되어 있는지
- 또는 **APNs 인증서**가 업로드되어 있는지

### 만약 없다면:

#### 방법 1: APNs 인증 키 (권장)
1. [Apple Developer](https://developer.apple.com/account/resources/authkeys/list) 접속
2. **Keys** → **Create a Key** 클릭
3. Key Name 입력 (예: HANSL Push Key)
4. **Apple Push Notifications service (APNs)** 체크
5. **Continue** → **Register**
6. **.p8 파일 다운로드** (⚠️ 한 번만 다운로드 가능!)
7. **Key ID** 메모

Firebase Console에서:
1. **APNs 인증 키** 섹션에서 **업로드** 클릭
2. 다운로드한 **.p8 파일** 선택
3. **Key ID** 입력 (10자리)
4. **Team ID** 입력 (Apple Developer 우측 상단에서 확인)
5. **업로드** 클릭

## 3️⃣ iOS 기기에서 알림 권한 확인

iPhone 설정:
- 설정 → 알림 → HANSL
- **알림 허용** ON 확인
- 알림 스타일 설정 확인

## 4️⃣ 앱에서 권한 요청 코드 확인

현재 NotificationService에 권한 요청 코드가 있는지 확인 필요

## 5️⃣ 빌드 후 테스트

위 설정 완료 후:
1. Xcode에서 실제 iPhone에 빌드
2. 앱 실행 시 알림 권한 허용
3. 푸시 알림 테스트

## ⚠️ 주의사항

- **시뮬레이터에서는 푸시 알림이 작동하지 않습니다**
- 반드시 **실제 iPhone 기기**에서 테스트해야 합니다
- APNs 설정 후 반영까지 몇 분 걸릴 수 있습니다

## 🔧 디버깅 팁

Xcode Console에서 확인할 로그:
- `FCM Token:` - 토큰이 생성되는지
- `APNS Token:` - APNs 토큰이 생성되는지
- 에러 메시지가 있는지

Firebase Console에서 테스트 메시지 보내기:
1. Firebase Console → Cloud Messaging
2. "새 알림" 클릭
3. 테스트 메시지 작성
4. "테스트 메시지 전송" 클릭
5. FCM 토큰 입력 후 전송
