# FCM 알림 시스템 점검 및 해결 방안

## 📊 현재 상태

### 1. FCM 토큰 상태
- **문제**: 31명 중 4명만 FCM 토큰 보유
- **원인**: 대부분의 사용자가 앱에 로그인하지 않았거나 FCM 토큰이 저장되지 않음

### 2. Edge Function 상태
- `send_fcm_notification` 함수가 배포됨 (버전 17)
- 마지막 업데이트: 최근

## 🔧 해결 방안

### 즉시 필요한 조치:

#### 1. **모든 사용자가 앱에 다시 로그인하도록 안내**
```dart
// 앱을 열고 로그인하면 FCM 토큰이 자동으로 등록됩니다
// lib/services/notification_service.dart에서 토큰 등록 확인
```

#### 2. **Firebase 서비스 계정 키 확인**
Supabase Dashboard에서:
1. Settings → Edge Functions
2. Environment Variables 섹션
3. `FIREBASE_SERVICE_ACCOUNT_JSON` 변수 확인

Firebase Console에서 새 키 생성:
1. Firebase Console → 프로젝트 설정 → 서비스 계정
2. "새 비공개 키 생성" 클릭
3. JSON 파일 다운로드
4. Supabase Dashboard에 환경변수로 추가

#### 3. **FCM 토큰 강제 갱신 (선택사항)**
앱에 다음 코드 추가하여 토큰 강제 갱신:
```dart
// 로그인 성공 후 또는 MainTab initState에서
await NotificationService.refreshFCMToken();
```

## 📱 테스트 방법

### 1. FCM 토큰 확인
```sql
-- Supabase SQL Editor에서 실행
SELECT email, name, 
       CASE WHEN fcm_token IS NOT NULL THEN 'O' ELSE 'X' END as has_token
FROM employees
WHERE email = 'your-email@example.com';
```

### 2. Edge Function 테스트
```bash
# 터미널에서 실행
curl -X POST https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "user",
    "title": "테스트 알림",
    "body": "테스트 메시지입니다",
    "user_email": "your-email@example.com"
  }'
```

### 3. Firebase Console에서 직접 테스트
1. Firebase Console → Cloud Messaging
2. "Send your first message" 클릭
3. FCM 토큰으로 테스트 메시지 전송

## 🚨 주의사항

1. **iOS 시뮬레이터**: 푸시 알림 지원 안 함 (실제 기기 필요)
2. **Android 에뮬레이터**: Google Play Services 필요
3. **권한**: 사용자가 알림 권한을 허용해야 함

## 📝 체크리스트

- [ ] 모든 사용자가 앱에 재로그인
- [ ] Firebase 서비스 계정 키 환경변수 설정
- [ ] FCM 토큰 DB 저장 확인
- [ ] Edge Function 로그 모니터링
- [ ] 테스트 알림 전송 성공

## 🔄 자동화 제안

앱 시작시 자동으로 FCM 토큰 갱신:
```dart
// main.dart에 추가
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // 앱 시작시 FCM 토큰 자동 갱신
  if (FirebaseAuth.instance.currentUser != null) {
    await NotificationService.initialize();
    await NotificationService.refreshFCMToken();
  }
  
  runApp(MyApp());
}
```

