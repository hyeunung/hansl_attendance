import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'notification_navigator.dart';
import '../screens/notification/notification_center_screen.dart';

// 백그라운드 메시지 핸들러 (글로벌 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();

    if (kDebugMode) {
      // Debug code removed
    }

    // TODO: 백그라운드에서 필요한 추가 처리 (예: 로컬 DB 업데이트)
  } catch (e) {
    if (kDebugMode) {
      // Debug code removed
    }
  }
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static String? _fcmToken;

  /// 글로벌 네비게이터 키 (외부에서 접근 가능)
  /// MaterialApp.navigatorKey로 연결됨 (main.dart)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // 중복 알림 방지를 위한 최근 전송 기록 (메모리에서만 관리)
  static final Map<String, DateTime> _recentNotifications =
      <String, DateTime>{};

  // 중복 알림 방지 시간 (초)
  static const int _duplicatePreventionSeconds = 30;

  /// Firebase 알림 서비스 초기화
  static Future<void> initialize() async {
    try {
      // 백그라운드 메시지 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // 로컬 알림 초기화
      await _initializeLocalNotifications();

      // 알림 권한 요청
      await _requestPermission();

      // FCM 토큰 가져오기
      await _getFCMToken();

      // 포그라운드 알림 설정
      await _configureForegroundNotification();

      // 메시지 리스너 설정
      _setupMessageListeners();

      if (kDebugMode) {
        // Debug code removed
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
    }
  }

  /// 알림 권한 요청
  static Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        // Debug code removed
      }
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      if (kDebugMode) {
        // Debug code removed
      }
    } else {
      if (kDebugMode) {
        // Debug code removed
      }
    }
  }

  /// FCM 토큰 가져오기 및 저장
  static Future<void> _getFCMToken() async {
    try {
      // iOS에서 APNS 토큰 처리 (필수)
      if (Platform.isIOS) {
        if (kDebugMode) {
        // Debug code removed
        }

        try {
          // APNS 토큰 요청 (더 긴 타임아웃)
          String? apnsToken = await _messaging.getAPNSToken().timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );

          if (apnsToken != null) {
            if (kDebugMode) {
              if (kDebugMode) {
                // Debug code removed
              }
        // Debug code removed
            }
          } else {
            if (kDebugMode) {
        // Debug code removed
        // Debug code removed
        // Debug code removed
            }

            // 실제 기기에서 추가 시도
            if (!kIsWeb) {
              if (kDebugMode) {
        // Debug code removed
              }
              await Future.delayed(const Duration(seconds: 2));
              apnsToken = await _messaging.getAPNSToken();

              if (apnsToken != null) {
                if (kDebugMode) {
                  if (kDebugMode) {
                    // Debug code removed
                  }
                }
              }
            }
          }
        } catch (apnsError) {
          if (kDebugMode) {
        // Debug code removed
        // Debug code removed
          }
        }
      }

      // FCM 토큰 가져오기 (APNS 토큰 없이도 시도)
      try {
        _fcmToken = await _messaging.getToken();

        if (_fcmToken != null) {
          if (kDebugMode) {
        // Debug code removed
          }

          // SharedPreferences에 토큰 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', _fcmToken!);

          // 서버에 토큰 전송 (Supabase에 저장)
          await _sendTokenToServer(_fcmToken!);
        } else {
          if (kDebugMode) {
        // Debug code removed
          }
          await _retryGetToken();
        }
      } catch (fcmError) {
        if (kDebugMode) {
        // Debug code removed
        }
        await _retryGetToken();
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
      await _retryGetToken();
    }
  }

  /// FCM 토큰 가져오기 재시도
  static Future<void> _retryGetToken() async {
    if (kDebugMode) {
        // Debug code removed
    }

    try {
      // 3초 대기 후 재시도
      await Future.delayed(const Duration(seconds: 3));

      _fcmToken = await _messaging.getToken();

      if (_fcmToken != null) {
        if (kDebugMode) {
        // Debug code removed
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        await _sendTokenToServer(_fcmToken!);
      } else {
        if (kDebugMode) {
        // Debug code removed
        }
        // onTokenRefresh 리스너는 이미 _setupMessageListeners에서 설정됨
      }
    } catch (retryError) {
      if (kDebugMode) {
        // Debug code removed
        // Debug code removed
      }
    }
  }

  /// 로컬 알림 초기화
  static Future<void> _initializeLocalNotifications() async {
    // Android 설정
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // iOS 10 이상에서는 UNUserNotificationCenter 사용
    );

    // 플랫폼 별 설정
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 초기화
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 알림 탭 핸들링
        if (kDebugMode) {
        // Debug code removed
        }
        _handleLocalNotificationTap(response.payload);
      },
    );

    if (kDebugMode) {
        // Debug code removed
    }
  }

  /// 포그라운드 알림 설정
  static Future<void> _configureForegroundNotification() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,  // FCM 자동 알림 비활성화 (로컬 알림으로 처리)
      badge: true,
      sound: false,  // 소리도 로컬 알림에서 처리
    );
  }

  /// 메시지 리스너 설정
  static void _setupMessageListeners() {
    // 포그라운드에서 메시지 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        if (kDebugMode) {
          // Debug code removed
        }
      }
      _showLocalNotification(message);
    });

    // 앱이 백그라운드에서 열릴 때 (알림 탭)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // 앱이 종료된 상태에서 알림 탭으로 실행된 경우 - MainTab 준비 후 처리
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _pendingInitialMessage = message;
    });

    // 토큰 갱신 리스너
    _messaging.onTokenRefresh.listen((String token) {
      if (kDebugMode) {
        // Debug code removed
      }
      _fcmToken = token;

      // SharedPreferences에 새로운 토큰 저장
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('fcm_token', token);
      });

      _sendTokenToServer(token);
    });
  }

  /// 로컬 알림 표시 (포그라운드용)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      if (kDebugMode) {
        // Debug code removed
        // Debug code removed
        // Debug code removed
        // Debug code removed
        // Debug code removed
      }

      // 알림 수신 이벤트 로깅
      _logNotificationEvent('received_foreground', message);

      // Android 알림 채널 설정
      const androidDetails = AndroidNotificationDetails(
        'hansl_channel', // 채널 ID
        '한슬 알림', // 채널 이름
        channelDescription: '한슬 어플리케이션 알림',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      // iOS 알림 설정
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: null, // null로 설정하면 시스템이 자동으로 관리
      );

      // 플랫폼 별 설정 통합
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 알림 ID 생성 (중복 방지)
      final notificationId =
          message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';

      // 로컬 알림 표시
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: jsonEncode(message.data),
      );

      if (kDebugMode) {
        // Debug code removed
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
    }
  }

  /// 로컬 알림 탭 핸들링
  static void _handleLocalNotificationTap(String? payload) {
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (kDebugMode) {
        // Debug code removed
      }

      // RemoteMessage와 비슷한 형식으로 변환
      final message = RemoteMessage(data: data);
      _handleNotificationTap(message);
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
    }
  }

  /// 앱 실행을 유발한 알림 (MainTab 초기화 후 처리)
  static RemoteMessage? _pendingInitialMessage;

  /// 앱 실행 알림이 있으면 해당 화면으로 이동 (MainTab 초기화 완료 후 호출)
  static void handlePendingInitialMessage() {
    final message = _pendingInitialMessage;
    if (message == null) return;
    _pendingInitialMessage = null;
    _handleNotificationTap(message);
  }

  /// 알림 탭 처리 - 알림 종류(data.type)에 맞는 화면으로 이동
  static void _handleNotificationTap(RemoteMessage message) async {
    try {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      final type = (message.data['type'] as String?) ?? '';
      final moved = await NotificationNavigator.open(
        navigator,
        type,
        data: message.data,
        body: message.notification?.body,
      );
      if (!moved) {
        // 앱 내 대상 화면이 없는 알림(제작현황 등)은 알림 센터로 이동
        navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
        );
      }

      _logNotificationEvent('tap', message);
    } catch (e) {
      // 이동 실패 시 현재 화면 유지
    }
  }

  /// 알림 이벤트 로깅 (분석용)
  static void _logNotificationEvent(String eventType, RemoteMessage message) {
    try {
      // TODO: 실제 분석 서버로 로그 전송 구현
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
    }
  }

  /// 서버에 FCM 토큰 전송 (Supabase)
  static Future<void> _sendTokenToServer(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
        // Debug code removed
        }
        return;
      }

      if (kDebugMode) {
        // Debug code removed
      }

      // Supabase에 FCM 토큰 저장
      await Supabase.instance.client
          .from('employees')
          .update({'fcm_token': token})
          .eq('email', user.email!);

      if (kDebugMode) {
        // Debug code removed
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
    }
  }

  /// Edge Function을 통한 FCM 알림 전송
  static Future<bool> _callFCMEdgeFunction({
    required String type,
    required String title,
    required String body,
    required Map<String, String> data,
    String? requesterDepartment,
    String? userEmail,
    String? requesterEmail,
    bool isManagerRequest = false,
  }) async {
    try {
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      
      final projectId = 'qvhbigvdfyvhoegkhvef'; // 원래 프로젝트 ID로 복원
      final functionUrl =
          'https://$projectId.supabase.co/functions/v1/send_fcm_notification';

      final requestData = {
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        if (requesterDepartment != null)
          'requester_department': requesterDepartment,
        if (userEmail != null) 'user_email': userEmail,
        if (requesterEmail != null) 'requester_email': requesterEmail,
        'is_manager_request': isManagerRequest,
      };

      // Debug code removed
      // Debug code removed

      // Debug code removed
      
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
        },
        body: jsonEncode(requestData),
      );

      // Debug code removed
      // Debug code removed
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
      // Debug code removed
          return true;
        } else {
      // Debug code removed
          return false;
        }
      } else {
      // Debug code removed
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
      return false;
    }
  }

  /// 중복 알림 방지 체크
  static bool _isDuplicateNotification(
    String userEmail,
    String title,
    String type,
  ) {
    final key = '${userEmail}_${title}_$type';
    final now = DateTime.now();

      // Debug code removed
      // Debug code removed
    
    if (_recentNotifications.containsKey(key)) {
      final lastSent = _recentNotifications[key]!;
      final secondsElapsed = now.difference(lastSent).inSeconds;

      // Debug code removed
      // Debug code removed
      
      if (secondsElapsed < _duplicatePreventionSeconds) {
      // Debug code removed
        if (kDebugMode) {
          // Debug code removed
        }
        return true;
      }
    }

    // 기록 저장 및 5분 이상 된 기록 정리
      // Debug code removed
    _recentNotifications[key] = now;
    _recentNotifications.removeWhere(
      (key, timestamp) => now.difference(timestamp).inMinutes > 5,
    );

      // Debug code removed
    return false;
  }

  /// Admin + 부서별 관리자에게 알림 전송 (새로운 방식)
  static Future<void> sendNotificationToAdmins({
    required String title,
    required String body,
    required Map<String, String> data,
    String? requesterDepartment,
    String? requesterEmail,
    bool isManagerRequest = false,
  }) async {
    try {
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      // Debug code removed
      
      // 중복 알림 방지 체크
      final notificationType = data['type'] ?? 'admin';
      if (_isDuplicateNotification(
        requesterEmail ?? 'admin',
        title,
        notificationType,
      )) {
      // Debug code removed
        return;
      }

      // Debug code removed

      await _callFCMEdgeFunction(
        type: 'admin',
        title: title,
        body: body,
        data: data,
        requesterDepartment: requesterDepartment,
        requesterEmail: requesterEmail,
        isManagerRequest: isManagerRequest,
      ).catchError((error) {
        if (kDebugMode) {
          // Debug code removed
        }
        // FCM 실패해도 프로세스는 계속 진행
        return false;
      });
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
      rethrow;
    }
  }

  /// 특정 사용자에게 푸시 알림 전송 (새로운 방식)
  static Future<void> sendNotificationToUser({
    required String userEmail,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // 중복 알림 방지 체크
      final notificationType = data['type'] ?? 'user';
      if (_isDuplicateNotification(userEmail, title, notificationType)) {
        if (kDebugMode) {
        // Debug code removed
        }
        return;
      }

      if (kDebugMode) {
        // Debug code removed
      }

      await _callFCMEdgeFunction(
        type: 'user',
        title: title,
        body: body,
        data: data,
        userEmail: userEmail,
      ).catchError((error) {
        if (kDebugMode) {
          // Debug code removed
        }
        // FCM 실패해도 프로세스는 계속 진행
        return false;
      });
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
      rethrow;
    }
  }

  /// 현재 FCM 토큰 반환
  static String? get fcmToken => _fcmToken;

  /// 저장된 FCM 토큰 로드
  static Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  /// 로그인 후 FCM 토큰 재저장 (로그인 후 호출)
  static Future<void> refreshTokenAfterLogin() async {
    try {
      if (_fcmToken != null) {
        if (kDebugMode) {
        // Debug code removed
        }
        await _sendTokenToServer(_fcmToken!);
      } else {
        if (kDebugMode) {
        // Debug code removed
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug code removed
      }
    }
  }
}
