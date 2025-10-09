// 이 코드를 main.dart의 initState나 적절한 위치에 임시로 추가해서 
// FCM 토큰을 확인하세요

import 'package:firebase_messaging/firebase_messaging.dart';

void checkFCMToken() async {
  // APNs 토큰 확인
  String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  print('🍎 APNs Token: $apnsToken');
  
  // FCM 토큰 확인  
  String? fcmToken = await FirebaseMessaging.instance.getToken();
  print('🔥 FCM Token: $fcmToken');
  
  // 토큰 리프레시 리스너
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print('🔄 New FCM Token: $newToken');
  });
  
  // 알림 권한 상태 확인
  NotificationSettings settings = await FirebaseMessaging.instance.getNotificationSettings();
  print('📱 Notification Permission: ${settings.authorizationStatus}');
}