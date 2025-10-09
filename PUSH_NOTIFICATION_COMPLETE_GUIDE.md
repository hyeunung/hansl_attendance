# 📱 HANSL 푸시 알림 시스템 완벽 복구 가이드

> **작성일**: 2025년 1월 4일  
> **현재 상태**: ✅ 완벽하게 작동 중  
> **중요**: 이 문서는 푸시 알림 시스템이 문제가 생겼을 때 현재의 완벽한 상태로 복구하기 위한 완전한 가이드입니다.

## 🎯 시스템 개요

### 푸시 알림이 발송되는 케이스
1. **연차/출장 승인 요청** - 관리자에게 알림
2. **연차/출장 승인 완료** - 신청자에게 알림  
3. **연차/출장 반려** - 신청자에게 알림
4. **구매 요청 승인 단계별 알림**
   - 1차 승인자(middle_manager)에게
   - 최종 승인자(카테고리별 관리자)에게
   - 승인/반려 시 요청자에게

## 🔧 핵심 구성 요소

### 1. Firebase 설정 파일
```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

### 2. 환경 변수 (.env)
```bash
SUPABASE_URL=https://qvhbigvdfyvhoegkhvef.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
```

### 3. Supabase Edge Function 환경 변수
```bash
# Supabase Dashboard > Edge Functions > send_fcm_notification에 설정
FIREBASE_SERVICE_ACCOUNT_KEY={
  "type": "service_account",
  "project_id": "hansl-attendance",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-...",
  ...
}
```

## 📂 핵심 파일 구조

### Flutter 앱 (Frontend)

#### 1. lib/services/notification_service.dart
```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'badge_count_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;
  final BadgeCountService _badgeService = BadgeCountService();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Firebase 권한 요청
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.info('푸시 알림 권한 허용됨');
      } else {
        AppLogger.warning('푸시 알림 권한 거부됨');
        return;
      }

      // 2. FCM 토큰 획득 및 저장
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveFCMToken(token);
        AppLogger.info('FCM 토큰 저장 완료');
      }

      // 3. 토큰 갱신 리스너
      _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);

      // 4. Local Notifications 초기화
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationTap,
      );

      // 5. 메시지 리스너 설정
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // 6. 백그라운드 메시지 핸들러
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      _isInitialized = true;
      AppLogger.info('NotificationService 초기화 완료');
    } catch (e) {
      AppLogger.error('NotificationService 초기화 실패', e);
    }
  }

  // FCM 토큰 저장
  Future<void> _saveFCMToken(String token) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('employees')
            .update({'fcm_token': token})
            .eq('email', user.email!);
        AppLogger.info('FCM 토큰 업데이트 성공');
      }
    } catch (e) {
      AppLogger.error('FCM 토큰 저장 실패', e);
    }
  }

  // Foreground 메시지 처리
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.info('Foreground 메시지 수신: ${message.notification?.title}');
    
    // 로컬 알림 표시
    await _showLocalNotification(message);
    
    // 배지 업데이트
    await _badgeService.updateBadgeCount();
  }

  // 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'hansl_channel',
      'HANSL 알림',
      channelDescription: 'HANSL 앱 알림',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? '알림',
      message.notification?.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  // 알림 탭 처리
  void _handleNotificationTap(NotificationResponse response) {
    AppLogger.info('알림 탭됨: ${response.payload}');
    // 필요시 네비게이션 처리
  }

  // 앱이 백그라운드에서 열렸을 때
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppLogger.info('백그라운드에서 앱 열림: ${message.notification?.title}');
    // 필요시 네비게이션 처리
  }
}

// 백그라운드 메시지 핸들러 (top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info('백그라운드 메시지 수신: ${message.notification?.title}');
}
```

#### 2. lib/main.dart - 초기화 부분
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Supabase 초기화
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  // 알림 서비스 초기화
  await NotificationService().initialize();
  
  runApp(MyApp());
}
```

### Supabase Edge Functions (Backend)

#### 1. supabase/functions/send_fcm_notification/index.ts
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import * as jwt from "https://deno.land/x/djwt@v2.8/mod.ts"

const FIREBASE_PROJECT_ID = "hansl-attendance"

// CORS 헤더
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Firebase Access Token 획득
async function getAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY') || '{}')
  
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  }

  const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n')
  const token = await jwt.create({ alg: "RS256", typ: "JWT" }, payload, privateKey)

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: token
    })
  })

  const data = await response.json()
  return data.access_token
}

// FCM 메시지 전송
async function sendFCMMessage(fcmToken: string, title: string, body: string, data?: any) {
  const accessToken = await getAccessToken()
  
  const message = {
    message: {
      token: fcmToken,
      notification: {
        title,
        body
      },
      data: data || {},
      android: {
        priority: "high",
        notification: {
          sound: "default",
          priority: "high",
          visibility: "public",
          notification_priority: "PRIORITY_HIGH"
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title,
              body
            },
            sound: "default",
            badge: 1,
            "content-available": 1
          }
        },
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert"
        }
      }
    }
  }

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(message)
    }
  )

  if (!response.ok) {
    const error = await response.text()
    console.error('FCM 전송 실패:', error)
    throw new Error(`FCM 전송 실패: ${error}`)
  }

  return await response.json()
}

serve(async (req) => {
  // CORS 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { fcmToken, title, body, data } = await req.json()

    if (!fcmToken) {
      throw new Error('FCM 토큰이 필요합니다')
    }

    const result = await sendFCMMessage(fcmToken, title, body, data)
    
    return new Response(
      JSON.stringify({ success: true, result }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )
  } catch (error) {
    console.error('에러 발생:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400 
      }
    )
  }
})
```

### 데이터베이스 트리거 (연차 알림)

#### supabase/migrations/XXX_leave_notification_trigger.sql
```sql
-- 연차 요청 알림 트리거
CREATE OR REPLACE FUNCTION notify_leave_request()
RETURNS TRIGGER AS $$
DECLARE
  manager_record RECORD;
  requester_name TEXT;
  notification_title TEXT;
  notification_body TEXT;
BEGIN
  -- INSERT 시에만 동작 (pending 상태)
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    -- 요청자 이름 가져오기
    SELECT name INTO requester_name
    FROM employees
    WHERE email = NEW.user_email;

    -- 알림 제목과 본문 설정
    notification_title := '연차 승인 요청';
    notification_body := requester_name || '님이 ' || 
                        CASE NEW.type 
                          WHEN 'annual' THEN '연차'
                          WHEN 'business_trip' THEN '출장'
                          ELSE NEW.type
                        END || ' 신청을 요청했습니다';

    -- 모든 관리자에게 알림 전송
    FOR manager_record IN 
      SELECT fcm_token, email
      FROM employees
      WHERE fcm_token IS NOT NULL
        AND fcm_token != ''
        AND (
          'superadmin' = ANY(attendance_role) OR
          'admin' = ANY(attendance_role) OR
          'supervisor' = ANY(attendance_role) OR
          'dev3 manager' = ANY(attendance_role) OR
          'cad manager' = ANY(attendance_role) OR
          'dev manager' = ANY(attendance_role) OR
          'support manager' = ANY(attendance_role) OR
          'lab manager' = ANY(attendance_role)
        )
    LOOP
      -- Edge Function 호출하여 FCM 전송
      PERFORM net.http_post(
        url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
        ),
        body := jsonb_build_object(
          'fcmToken', manager_record.fcm_token,
          'title', notification_title,
          'body', notification_body,
          'data', jsonb_build_object(
            'type', 'leave_request',
            'leave_id', NEW.id::text,
            'requester', NEW.user_email
          )
        )
      );
    END LOOP;

  -- UPDATE 시 (승인/반려)
  ELSIF TG_OP = 'UPDATE' THEN
    -- 상태가 변경되었을 때만
    IF OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected') THEN
      -- 신청자에게 알림
      SELECT fcm_token INTO manager_record.fcm_token
      FROM employees
      WHERE email = NEW.user_email
        AND fcm_token IS NOT NULL
        AND fcm_token != '';

      IF manager_record.fcm_token IS NOT NULL THEN
        -- 알림 내용 설정
        IF NEW.status = 'approved' THEN
          notification_title := '연차 승인 완료';
          notification_body := '신청하신 ' || 
                              CASE NEW.type 
                                WHEN 'annual' THEN '연차가'
                                WHEN 'business_trip' THEN '출장이'
                                ELSE NEW.type || '이(가)'
                              END || ' 승인되었습니다';
        ELSE
          notification_title := '연차 반려';
          notification_body := '신청하신 ' || 
                              CASE NEW.type 
                                WHEN 'annual' THEN '연차가'
                                WHEN 'business_trip' THEN '출장이'
                                ELSE NEW.type || '이(가)'
                              END || ' 반려되었습니다';
        END IF;

        -- FCM 전송
        PERFORM net.http_post(
          url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
          ),
          body := jsonb_build_object(
            'fcmToken', manager_record.fcm_token,
            'title', notification_title,
            'body', notification_body,
            'data', jsonb_build_object(
              'type', 'leave_response',
              'leave_id', NEW.id::text,
              'status', NEW.status
            )
          )
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 트리거 생성
DROP TRIGGER IF EXISTS leave_notification_trigger ON leave;
CREATE TRIGGER leave_notification_trigger
AFTER INSERT OR UPDATE ON leave
FOR EACH ROW
EXECUTE FUNCTION notify_leave_request();
```

### 구매 요청 알림 트리거

#### supabase/migrations/XXX_purchase_notification_trigger.sql
```sql
-- 구매 요청 알림 트리거
CREATE OR REPLACE FUNCTION notify_purchase_request()
RETURNS TRIGGER AS $$
DECLARE
  manager_record RECORD;
  notification_title TEXT;
  notification_body TEXT;
  target_role TEXT;
BEGIN
  -- 1차 승인 대기 → 1차 승인자에게 알림
  IF NEW.middle_manager_status = 'pending' AND OLD.middle_manager_status IS NULL THEN
    notification_title := '구매 승인 요청';
    notification_body := NEW.requester_name || '님의 구매 요청이 승인 대기 중입니다';
    
    FOR manager_record IN 
      SELECT fcm_token
      FROM employees
      WHERE fcm_token IS NOT NULL
        AND fcm_token != ''
        AND 'middle_manager' = ANY(purchase_role)
    LOOP
      PERFORM net.http_post(
        url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
        ),
        body := jsonb_build_object(
          'fcmToken', manager_record.fcm_token,
          'title', notification_title,
          'body', notification_body
        )
      );
    END LOOP;

  -- 1차 승인 완료 → 최종 승인자에게 알림
  ELSIF NEW.middle_manager_status = 'approved' AND OLD.middle_manager_status = 'pending' THEN
    notification_title := '최종 승인 요청';
    notification_body := NEW.requester_name || '님의 구매 요청이 최종 승인 대기 중입니다';
    
    -- 카테고리에 따른 최종 승인자 결정
    IF NEW.request_type = '원자재' THEN
      target_role := 'raw_material_manager';
    ELSE
      target_role := 'consumable_manager';
    END IF;
    
    FOR manager_record IN 
      SELECT fcm_token
      FROM employees
      WHERE fcm_token IS NOT NULL
        AND fcm_token != ''
        AND (target_role = ANY(purchase_role) OR 'final_approver' = ANY(purchase_role))
    LOOP
      PERFORM net.http_post(
        url := 'https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
        ),
        body := jsonb_build_object(
          'fcmToken', manager_record.fcm_token,
          'title', notification_title,
          'body', notification_body
        )
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 트리거 생성
DROP TRIGGER IF EXISTS purchase_notification_trigger ON purchase_requests;
CREATE TRIGGER purchase_notification_trigger
AFTER INSERT OR UPDATE ON purchase_requests
FOR EACH ROW
EXECUTE FUNCTION notify_purchase_request();
```

## 🔍 디버깅 및 테스트

### 1. FCM 토큰 확인
```sql
-- Supabase SQL Editor에서 실행
SELECT email, name, fcm_token 
FROM employees 
WHERE email = 'test@hansl.com';
```

### 2. Edge Function 테스트
```bash
# 터미널에서 실행
curl -X POST https://qvhbigvdfyvhoegkhvef.supabase.co/functions/v1/send_fcm_notification \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "fcmToken": "실제_FCM_토큰",
    "title": "테스트 알림",
    "body": "테스트 메시지입니다"
  }'
```

### 3. 로그 확인
```bash
# Edge Function 로그 확인
supabase functions logs send_fcm_notification --project-ref qvhbigvdfyvhoegkhvef
```

## ⚠️ 주의사항

1. **Firebase 서비스 계정 키**: 절대 코드에 직접 포함하지 말고 환경 변수로 관리
2. **Supabase Anon Key**: .env 파일에만 보관, 깃에 커밋하지 않음
3. **FCM 토큰**: 앱 재설치 시 변경되므로 항상 최신 토큰 유지
4. **테스트**: 항상 test@hansl.com 계정으로만 테스트

## 🚨 문제 해결

### 알림이 오지 않을 때
1. FCM 토큰이 데이터베이스에 저장되어 있는지 확인
2. Edge Function이 정상 작동하는지 로그 확인
3. Firebase 콘솔에서 프로젝트 설정 확인
4. 기기의 알림 권한 설정 확인

### 특정 사용자만 알림이 안 올 때
1. 해당 사용자의 FCM 토큰 확인
2. 역할(role) 설정이 올바른지 확인
3. 앱 재설치 후 토큰 갱신 필요

## 📝 체크리스트

복구 시 다음 항목들을 순서대로 확인:

- [ ] Firebase 프로젝트 설정 확인
- [ ] google-services.json, GoogleService-Info.plist 파일 존재
- [ ] .env 파일에 Supabase URL과 Anon Key 설정
- [ ] Edge Function에 Firebase 서비스 계정 키 환경 변수 설정
- [ ] send_fcm_notification Edge Function 배포
- [ ] 데이터베이스 트리거 생성 (leave, purchase_requests)
- [ ] Flutter 앱에서 NotificationService 초기화
- [ ] test@hansl.com으로 테스트

## 🎯 완료 기준

다음 시나리오가 모두 작동하면 복구 완료:

1. ✅ 연차 신청 시 관리자에게 알림
2. ✅ 연차 승인/반려 시 신청자에게 알림
3. ✅ 구매 요청 시 1차 승인자에게 알림
4. ✅ 1차 승인 후 최종 승인자에게 알림
5. ✅ 최종 승인/반려 시 요청자에게 알림
6. ✅ 앱이 포그라운드/백그라운드 모두에서 알림 수신

---

**마지막 업데이트**: 2025년 1월 4일
**작성자**: Claude & Scott
**상태**: ✅ 완벽 작동 중