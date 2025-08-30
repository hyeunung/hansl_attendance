# APNs 설정 확인 가이드

## 🔍 Firebase Console 확인 방법

### 1. 접속 링크
https://console.firebase.google.com/project/hansl-attendance/settings/cloudmessaging

### 2. 확인 위치
페이지 하단의 **"Apple 앱 구성"** 섹션

### 3. 설정 상태 판별

#### ✅ APNs 설정이 되어 있는 경우:
```
Apple 앱 구성
├── APNs 인증 키
│   ├── Key ID: XXXXXXXXXX
│   ├── Team ID: XXXXXXXXXX
│   └── 업로드됨: 2024-XX-XX
└── 또는 APNs 인증서가 표시됨
```

#### ❌ APNs 설정이 안 되어 있는 경우:
```
Apple 앱 구성
├── APNs 인증 키 업로드 [버튼]
└── APNs 인증서 업로드 [버튼]
```

### 4. 앱 등록 확인
- iOS 앱이 Firebase 프로젝트에 등록되어 있는지 확인
- 번들 ID: `com.hansl.hansla` (추정)

## 📱 iOS 앱에서 확인 방법

### Xcode에서 현재 번들 ID 확인:
1. Xcode에서 Runner.xcworkspace 열기
2. Runner 프로젝트 선택
3. General 탭 → Bundle Identifier 확인

### Firebase Console에서 iOS 앱 확인:
1. 프로젝트 설정 → 일반 탭
2. "내 앱" 섹션에서 iOS 앱 확인
3. 번들 ID가 일치하는지 확인

## 🔧 문제 해결

### APNs 설정이 없는 경우:
1. Apple Developer 계정 필요
2. APNs 인증 키 생성 및 다운로드
3. Firebase Console에 업로드

### iOS 앱이 등록되지 않은 경우:
1. Firebase Console에서 iOS 앱 추가
2. 번들 ID 일치 확인
3. GoogleService-Info.plist 다운로드 및 교체

