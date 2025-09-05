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
import '../screens/main_tab.dart';

// 백그라운드 메시지 핸들러 (글로벌 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();

    final title = message.notification?.title ?? '새 알림';
    final body = message.notification?.body ?? '';
    final type = message.data['type'] ?? 'unknown';

    if (kDebugMode) {
      if (kDebugMode) print('📨 백그라운드 메시지 수신:');
      if (kDebugMode) print('   메시지 ID: ${message.messageId}');
      if (kDebugMode) print('   제목: $title');
      if (kDebugMode) print('   내용: $body');
      if (kDebugMode) print('   타입: $type');
      if (kDebugMode) print('   데이터: ${message.data}');
      if (kDebugMode) print('   수신 시간: ${DateTime.now().toIso8601String()}');
    }

    // TODO: 백그라운드에서 필요한 추가 처리 (예: 로컬 DB 업데이트)
  } catch (e) {
    if (kDebugMode) {
      if (kDebugMode) print('❌ 백그라운드 메시지 처리 실패: $e');
    }
  }
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static String? _fcmToken;

  /// 글로벌 네비게이터 키 (외부에서 접근 가능)
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 중복 알림 방지를 위한 최근 전송 기록 (메모리에서만 관리)
  static final Map<String, DateTime> _recentNotifications = <String, DateTime>{};

  // 중복 알림 방지 시간 (초)
  static const int _duplicatePreventionSeconds = 30;

  /// Firebase 알림 서비스 초기화
  static Future<void> initialize() async {
    try {
      // 백그라운드 메시지 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
        if (kDebugMode) print('🔔 Firebase 알림 서비스 초기화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ Firebase 알림 서비스 초기화 실패: $e');
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
        if (kDebugMode) print('✅ 알림 권한 허용됨');
      }
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      if (kDebugMode) {
        if (kDebugMode) print('⚠️ 임시 알림 권한 허용됨');
      }
    } else {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 알림 권한 거부됨');
      }
    }
  }

  /// FCM 토큰 가져오기 및 저장
  static Future<void> _getFCMToken() async {
    try {
      // iOS에서 APNS 토큰 처리 (필수)
      if (Platform.isIOS) {
        if (kDebugMode) {
          if (kDebugMode) print('📱 iOS 플랫폼 감지 - APNS 토큰 확인...');
        }

        try {
          // APNS 토큰 요청 (더 긴 타임아웃)
          String? apnsToken = await _messaging.getAPNSToken().timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );

          if (apnsToken != null) {
            if (kDebugMode) {
              if (kDebugMode) print('✅ APNS 토큰 설정됨: ${apnsToken.substring(0, 20)}...');
              if (kDebugMode) print('✅ iOS 푸시 알림 사용 가능');
            }
          } else {
            if (kDebugMode) {
              if (kDebugMode) print('⚠️ APNS 토큰 없음');
              if (kDebugMode) print('📱 실제 iPhone에서 테스트하거나 알림 권한을 확인하세요');
              if (kDebugMode) print('📱 시뮬레이터에서는 푸시 알림을 받을 수 없습니다');
            }

            // 실제 기기에서 추가 시도
            if (!kIsWeb) {
              if (kDebugMode) {
                if (kDebugMode) print('🔄 APNS 토큰 추가 시도...');
              }
              await Future.delayed(const Duration(seconds: 2));
              apnsToken = await _messaging.getAPNSToken();

              if (apnsToken != null) {
                if (kDebugMode) {
                  if (kDebugMode) print('✅ APNS 토큰 지연 생성됨: ${apnsToken.substring(0, 20)}...');
                }
              }
            }
          }
        } catch (apnsError) {
          if (kDebugMode) {
            if (kDebugMode) print('❌ APNS 토큰 오류: $apnsError');
            if (kDebugMode) print('📱 iOS 푸시 알림이 작동하지 않을 수 있습니다');
          }
        }
      }

      // FCM 토큰 가져오기 (APNS 토큰 없이도 시도)
      try {
        _fcmToken = await _messaging.getToken();

        if (_fcmToken != null) {
          if (kDebugMode) {
            if (kDebugMode) print('🔑 FCM 토큰 성공: $_fcmToken');
          }

          // SharedPreferences에 토큰 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', _fcmToken!);

          // 서버에 토큰 전송 (Supabase에 저장)
          await _sendTokenToServer(_fcmToken!);
        } else {
          if (kDebugMode) {
            if (kDebugMode) print('❌ FCM 토큰이 null - 재시도');
          }
          await _retryGetToken();
        }
      } catch (fcmError) {
        if (kDebugMode) {
          if (kDebugMode) print('❌ FCM 토큰 오류: $fcmError - 재시도');
        }
        await _retryGetToken();
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 토큰 가져오기 전체 실패: $e');
      }
      await _retryGetToken();
    }
  }

  /// FCM 토큰 가져오기 재시도
  static Future<void> _retryGetToken() async {
    if (kDebugMode) {
      if (kDebugMode) print('🔄 FCM 토큰 재시도 시작...');
    }

    try {
      // 3초 대기 후 재시도
      await Future.delayed(const Duration(seconds: 3));

      _fcmToken = await _messaging.getToken();

      if (_fcmToken != null) {
        if (kDebugMode) {
          if (kDebugMode) print('✅ FCM 토큰 재시도 성공: $_fcmToken');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        await _sendTokenToServer(_fcmToken!);
      } else {
        if (kDebugMode) {
          if (kDebugMode) print('❌ FCM 토큰 재시도도 null - 토큰 갱신 대기');
        }
        // onTokenRefresh 리스너는 이미 _setupMessageListeners에서 설정됨
      }
    } catch (retryError) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ FCM 토큰 재시도 실패: $retryError');
        if (kDebugMode) print('📝 토큰은 나중에 onTokenRefresh에서 처리됩니다.');
      }
    }
  }

  /// 로컬 알림 초기화
  static Future<void> _initializeLocalNotifications() async {
    // Android 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // iOS 10 이상에서는 UNUserNotificationCenter 사용
    );

    // 플랫폼 별 설정
    final settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    // 초기화
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 알림 탭 핸들링
        if (kDebugMode) {
          if (kDebugMode) print('🔔 로컬 알림 탭: ${response.payload}');
        }
        _handleLocalNotificationTap(response.payload);
      },
    );

    if (kDebugMode) {
      if (kDebugMode) print('✅ 로컬 알림 초기화 완료');
    }
  }

  /// 포그라운드 알림 설정
  static Future<void> _configureForegroundNotification() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// 메시지 리스너 설정
  static void _setupMessageListeners() {
    // 포그라운드에서 메시지 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        if (kDebugMode) print('📱 포그라운드 메시지 수신: ${message.notification?.title}');
      }
      _showLocalNotification(message);
    });

    // 앱이 백그라운드에서 열릴 때 (알림 탭)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        if (kDebugMode) print('🔔 알림 탭으로 앱 열림: ${message.notification?.title}');
      }
      _handleNotificationTap(message);
    });

    // 토큰 갱신 리스너
    _messaging.onTokenRefresh.listen((String token) {
      if (kDebugMode) {
        if (kDebugMode) print('🔄 FCM 토큰 갱신: $token');
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
      final title = message.notification?.title ?? '새 알림';
      final body = message.notification?.body ?? '';
      final type = message.data['type'] ?? 'unknown';

      if (kDebugMode) {
        if (kDebugMode) print('📢 포그라운드 알림 표시:');
        if (kDebugMode) print('   제목: $title');
        if (kDebugMode) print('   내용: $body');
        if (kDebugMode) print('   타입: $type');
        if (kDebugMode) print('   데이터: ${message.data}');
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
      );

      // 플랫폼 별 설정 통합
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      // 알림 ID 생성 (중복 방지)
      final notificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

      // 로컬 알림 표시
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: jsonEncode(message.data),
      );

      if (kDebugMode) {
        if (kDebugMode) print('✅ 포그라운드 알림 표시 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 로컬 알림 표시 실패: $e');
      }
    }
  }

  /// 로컬 알림 탭 핸들링
  static void _handleLocalNotificationTap(String? payload) {
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (kDebugMode) {
        if (kDebugMode) print('👆 로컬 알림 탭 처리: $data');
      }

      // RemoteMessage와 비슷한 형식으로 변환
      final message = RemoteMessage(data: data);
      _handleNotificationTap(message);
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 로컬 알림 payload 파싱 실패: $e');
      }
    }
  }

  /// 알림 탭 처리
  static void _handleNotificationTap(RemoteMessage message) async {
    if (kDebugMode) {
      if (kDebugMode) print('👆 알림 탭 처리: ${message.data}');
    }

    try {
      // 알림 타입에 따라 적절한 화면으로 이동
      String? type = message.data['type'];
      String? requesterEmail = message.data['requester_email'];
      String? requesterName = message.data['requester_name'];

      final context = navigatorKey.currentContext;
      if (context == null) {
        if (kDebugMode) {
          if (kDebugMode) print('❌ NavigatorKey context가 null입니다.');
        }
        return;
      }

      switch (type) {
        case 'leave_request':
        case 'business_trip':
          // 연차/출장 신청 알림 - 관리자는 승인 탭으로 바로 이동
          if (kDebugMode) {
            if (kDebugMode) print('📅 ${type == 'business_trip' ? '출장' : '연차'} 신청 알림');
            if (kDebugMode) print('   신청자: $requesterName ($requesterEmail)');
          }

          // 현재 사용자의 권한 확인을 위해 Supabase에서 직접 조회
          try {
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
              final response = await Supabase.instance.client
                  .from('employees')
                  .select('attendance_role')
                  .eq('email', user.email!)
                  .single();

              final List<dynamic> attendanceRoles =
                  (response['attendance_role'] as List<dynamic>?) ?? [];

              // 승인 권한이 있는 역할 확인
              final approvalRoles = [
                'admin',
                'superadmin',
                '개발3팀_manager',
                'CAD_manager',
                '개발팀_manager',
                '경영지원팀_manager',
                '연구소_manager',
              ];

              final hasApprovalRole = attendanceRoles.any((role) => approvalRoles.contains(role));

              if (hasApprovalRole) {
                // 관리자는 승인 탭(index 2)으로 바로 이동
                if (kDebugMode) {
                  if (kDebugMode) print('✅ 관리자 권한 확인 - 승인 탭으로 이동');
                }
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MainTab(initialIndex: 2), // 승인 탭
                  ),
                  (route) => false,
                );
              } else {
                // 일반 사용자는 홈 탭으로 이동
                if (kDebugMode) {
                  if (kDebugMode) print('📱 일반 사용자 - 홈 화면으로 이동');
                }
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MainTab(initialIndex: 0), // 홈 탭
                  ),
                  (route) => false,
                );
              }
            }
          } catch (e) {
            // 오류 시 기본 홈 화면으로
            if (kDebugMode) {
              if (kDebugMode) print('⚠️ 권한 확인 실패, 홈으로 이동: $e');
            }
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const MainTab(initialIndex: 0), // 홈 탭
              ),
              (route) => false,
            );
          }
          break;

        case 'leave_result':
          // 승인/반려 결과 알림 - 연차 현황 화면으로 이동
          if (kDebugMode) {
            if (kDebugMode) print('📋 승인/반려 결과 알림 - 연차 현황 화면으로 이동');
          }

          // MainTab으로 이동하고 연차 탭(index 1) 선택
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MainTab(initialIndex: 1), // 연차 탭
            ),
            (route) => false,
          );
          break;

        default:
          // 기본 홈 화면으로 이동
          if (kDebugMode) {
            if (kDebugMode) print('🏠 기본 홈 화면으로 이동 (알림 타입: $type)');
          }

          // MainTab으로 이동하고 홈 탭(index 0) 선택
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MainTab(initialIndex: 0), // 홈 탭
            ),
            (route) => false,
          );
      }

      // 알림 탭 이벤트 로깅
      _logNotificationEvent('tap', message);
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 알림 탭 처리 중 오류: $e');
      }
    }
  }

  /// 알림 이벤트 로깅 (분석용)
  static void _logNotificationEvent(String eventType, RemoteMessage message) {
    try {
      final eventData = {
        'event_type': eventType,
        'notification_type': message.data['type'],
        'timestamp': DateTime.now().toIso8601String(),
        'message_id': message.messageId,
        'title': message.notification?.title,
      };
      if (kDebugMode) {
        if (kDebugMode) print('📊 알림 이벤트 로그: $eventData');
      }
      // TODO: 실제 분석 서버로 로그 전송 구현
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 알림 이벤트 로깅 실패: $e');
      }
    }
  }

  /// 서버에 FCM 토큰 전송 (Supabase)
  static Future<void> _sendTokenToServer(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          if (kDebugMode) print('❌ 로그인된 사용자가 없어서 토큰 저장 불가');
        }
        return;
      }

      if (kDebugMode) {
        if (kDebugMode) print('📤 서버에 토큰 전송: $token');
      }

      // Supabase에 FCM 토큰 저장
      await Supabase.instance.client
          .from('employees')
          .update({'fcm_token': token})
          .eq('email', user.email!);

      if (kDebugMode) {
        if (kDebugMode) print('✅ FCM 토큰 저장 완료: ${user.email}');
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 서버에 토큰 전송 실패: $e');
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
      final projectId = 'qvhbigvdfyvhoegkhvef'; // 원래 프로젝트 ID로 복원
      final functionUrl = 'https://$projectId.supabase.co/functions/v1/send_fcm_notification';

      final requestData = {
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        if (requesterDepartment != null) 'requester_department': requesterDepartment,
        if (userEmail != null) 'user_email': userEmail,
        if (requesterEmail != null) 'requester_email': requesterEmail,
        'is_manager_request': isManagerRequest,
      };

      if (kDebugMode) {
        if (kDebugMode) print('📮 Edge Function 호출: $type - $title');
      }

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          if (kDebugMode) {
            if (kDebugMode) print('✅ Edge Function 알림 전송 성공: ${responseData['message']}');
          }
          return true;
        } else {
          if (kDebugMode) {
            if (kDebugMode) print('❌ Edge Function 알림 전송 실패: ${responseData['message']}');
          }
          return false;
        }
      } else {
        if (kDebugMode) {
          if (kDebugMode) print('❌ Edge Function 호출 실패: ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ Edge Function 호출 중 오류: $e');
      }
      return false;
    }
  }

  /// 중복 알림 방지 체크
  static bool _isDuplicateNotification(String userEmail, String title, String type) {
    final key = '${userEmail}_${title}_$type';
    final now = DateTime.now();

    if (_recentNotifications.containsKey(key)) {
      final lastSent = _recentNotifications[key]!;
      final secondsElapsed = now.difference(lastSent).inSeconds;

      if (secondsElapsed < _duplicatePreventionSeconds) {
        if (kDebugMode) {
          if (kDebugMode) print('🚫 중복 알림 차단: $title (${secondsElapsed}초 전에 전송됨)');
        }
        return true;
      }
    }

    // 기록 저장 및 5분 이상 된 기록 정리
    _recentNotifications[key] = now;
    _recentNotifications.removeWhere((key, timestamp) => now.difference(timestamp).inMinutes > 5);

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
      // 중복 알림 방지 체크
      final notificationType = data['type'] ?? 'admin';
      if (_isDuplicateNotification(requesterEmail ?? 'admin', title, notificationType)) {
        if (kDebugMode) {
          if (kDebugMode) print('⏩ 중복 알림으로 전송 건너뜀: $title');
        }
        return;
      }

      if (kDebugMode) {
        if (kDebugMode) print('📮 ${isManagerRequest ? 'Admin' : '부서 관리자'}에게 알림 전송 시작: $title');
      }

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
          print('⚠️ FCM 전송 실패 (계속 진행): $error');
        }
        // FCM 실패해도 프로세스는 계속 진행
        return false;
      });
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 알림 전송 실패: $e');
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
          if (kDebugMode) print('⏩ 중복 알림으로 전송 건너뜀: $title');
        }
        return;
      }

      if (kDebugMode) {
        if (kDebugMode) print('📮 $userEmail 사용자에게 알림 전송 시작: $title');
      }

      await _callFCMEdgeFunction(
        type: 'user',
        title: title,
        body: body,
        data: data,
        userEmail: userEmail,
      ).catchError((error) {
        if (kDebugMode) {
          print('⚠️ FCM 전송 실패 (계속 진행): $error');
        }
        // FCM 실패해도 프로세스는 계속 진행
        return false;
      });
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 사용자 알림 전송 실패: $e');
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
          if (kDebugMode) print('🔄 로그인 후 FCM 토큰 재저장 시작');
        }
        await _sendTokenToServer(_fcmToken!);
      } else {
        if (kDebugMode) {
          if (kDebugMode) print('⚠️ FCM 토큰이 없어서 재저장 불가');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 로그인 후 FCM 토큰 재저장 실패: $e');
      }
    }
  }
}
