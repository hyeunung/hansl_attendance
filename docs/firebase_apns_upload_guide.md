# Firebase APNs 업로드 가이드

## 🔗 Firebase Console 링크
https://console.firebase.google.com/project/hansl-attendance/settings/cloudmessaging

## 📝 업로드 단계

### 1. Apple 앱 구성 섹션으로 이동
- 페이지 하단 "Apple 앱 구성" 찾기

### 2. APN 인증 키 업로드
1. **"APN 인증 키"** 섹션에서 **"업로드"** 버튼 클릭
2. **파일 선택**: 다운로드한 `.p8` 파일 선택
3. **Key ID 입력**: Apple Developer에서 생성한 10자리 Key ID
4. **Team ID 입력**: Apple Developer 팀 ID
5. **"업로드"** 클릭

### 3. 설정 확인
업로드 성공 시 다음과 같이 표시됩니다:
```
APN 인증 키
├── Key ID: XXXXXXXXXX
├── Team ID: XXXXXXXXXX
└── 파일명: AuthKey_XXXXXXXXXX.p8
```

## 📋 필요한 정보

### Apple Developer에서 확인할 정보:
- **Key ID**: 10자리 문자열 (예: ABC1234567)
- **Team ID**: Apple Developer 계정 팀 ID
- **.p8 파일**: 다운로드한 인증 키 파일

### 확인 방법:
1. [Apple Developer - Keys](https://developer.apple.com/account/resources/authkeys/list)
2. 생성한 키 클릭하여 상세 정보 확인
3. Team ID는 우측 상단 계정 정보에서 확인

## ⚠️ 주의사항

1. **.p8 파일은 한 번만 다운로드 가능**
   - 분실 시 새로 생성해야 함

2. **Key ID와 Team ID 정확히 입력**
   - 틀리면 푸시 알림 작동하지 않음

3. **Environment 설정**
   - Sandbox: 개발/테스트용 (Xcode 실행)
   - Production: 배포용 (App Store)

