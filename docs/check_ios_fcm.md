# iOS FCM 설정 확인 가이드

## 1. Firebase Console에서 APNs 설정 확인

### 확인 방법:
1. [Firebase Console](https://console.firebase.google.com/project/hansl-attendance/settings/cloudmessaging) 접속
2. **프로젝트 설정** → **클라우드 메시징** 탭
3. **Apple 앱 구성** 섹션 확인

### 필요한 설정 (둘 중 하나):

#### 옵션 A: APNs 인증 키 (권장)
- **Key ID**: 10자리 문자열
- **Team ID**: Apple Developer 팀 ID
- **.p8 파일**: Apple Developer에서 다운로드한 인증 키

#### 옵션 B: APNs 인증서
- **개발용 인증서**: 개발/테스트용
- **프로덕션 인증서**: 배포용

## 2. Xcode 프로젝트 설정 확인

### Runner.xcworkspace 열기:
```bash
cd /Users/scott/workspace/hansl/ios
open Runner.xcworkspace
```

### Signing & Capabilities 확인:
1. **Push Notifications** - 활성화되어 있어야 함
2. **Background Modes** - Remote notifications 체크

## 3. iOS 디바이스에서 권한 확인

### 설정 앱에서:
1. 설정 → 알림 → 한슬
2. 알림 허용 ON
3. 알림 스타일 설정

## 4. 테스트 모드 확인

Xcode로 실행 중이면 **개발 모드**입니다.
- 개발 모드: APNs Sandbox 서버 사용
- 프로덕션 모드: APNs Production 서버 사용

Firebase는 자동으로 올바른 서버를 선택하지만, 
인증서 방식을 사용한다면 개발/프로덕션 인증서가 모두 필요합니다.

