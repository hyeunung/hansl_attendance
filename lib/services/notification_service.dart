import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 백그라운드 메시지 핸들러 (글로벌 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('백그라운드 메시지 수신: ${message.messageId}');
  print('제목: ${message.notification?.title}');
  print('내용: ${message.notification?.body}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _fcmToken;

  /// Firebase 알림 서비스 초기화
  static Future<void> initialize() async {
    try {
      // Firebase 초기화
      await Firebase.initializeApp();
      
      // 백그라운드 메시지 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // 알림 권한 요청
      await _requestPermission();
      
      // FCM 토큰 가져오기
      await _getFCMToken();
      
      // 포그라운드 알림 설정
      await _configureForegroundNotification();
      
      // 메시지 리스너 설정
      _setupMessageListeners();
      
      print('🔔 Firebase 알림 서비스 초기화 완료');
    } catch (e) {
      print('❌ Firebase 알림 서비스 초기화 실패: $e');
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
      print('✅ 알림 권한 허용됨');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('⚠️ 임시 알림 권한 허용됨');
    } else {
      print('❌ 알림 권한 거부됨');
    }
  }

  /// FCM 토큰 가져오기 및 저장
  static Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        print('🔑 FCM 토큰: $_fcmToken');
        
        // SharedPreferences에 토큰 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        
        // 서버에 토큰 전송 (Supabase에 저장)
        await _sendTokenToServer(_fcmToken!);
      }
    } catch (e) {
      print('❌ FCM 토큰 가져오기 실패: $e');
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
      print('📱 포그라운드 메시지 수신: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 앱이 백그라운드에서 열릴 때 (알림 탭)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 알림 탭으로 앱 열림: ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    // 토큰 갱신 리스너
    _messaging.onTokenRefresh.listen((String token) {
      print('🔄 FCM 토큰 갱신: $token');
      _fcmToken = token;
      _sendTokenToServer(token);
    });
  }

  /// 로컬 알림 표시 (포그라운드용)
  static void _showLocalNotification(RemoteMessage message) {
    // Flutter의 기본 스낵바나 다이얼로그로 표시
    // 실제로는 flutter_local_notifications 플러그인 사용 권장
    print('📢 알림 표시: ${message.notification?.title} - ${message.notification?.body}');
  }

  /// 알림 탭 처리
  static void _handleNotificationTap(RemoteMessage message) {
    print('👆 알림 탭 처리: ${message.data}');
    
    // 알림 타입에 따라 적절한 화면으로 이동
    String? type = message.data['type'];
    switch (type) {
      case 'leave_request':
        // 연차 신청 화면으로 이동
        print('📅 연차 신청 알림 - 승인 화면으로 이동');
        break;
      case 'business_trip':
        // 출장 신청 화면으로 이동
        print('✈️ 출장 신청 알림 - 승인 화면으로 이동');
        break;
      default:
        // 기본 홈 화면으로 이동
        print('🏠 기본 홈 화면으로 이동');
    }
  }

  /// 서버에 FCM 토큰 전송 (Supabase)
  static Future<void> _sendTokenToServer(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('❌ 로그인된 사용자가 없어서 토큰 저장 불가');
        return;
      }

      print('📤 서버에 토큰 전송: $token');
      
      // Supabase에 FCM 토큰 저장
      await Supabase.instance.client
          .from('employees')
          .update({'fcm_token': token})
          .eq('email', user.email!);
      
      print('✅ FCM 토큰 저장 완료: ${user.email}');
      
    } catch (e) {
      print('❌ 서버에 토큰 전송 실패: $e');
    }
  }

  /// 부서별 관리자 매핑
  static String _getManagerByDepartment(String department) {
    switch (department) {
      case '개발1팀':
      case '개발2팀':
        return '개발팀_manager';  // 통합
      case '개발3팀':
        return '개발3팀_manager';
      case '연구소':
        return '연구소_manager';
      case '경영지원팀':
        return '경영지원팀_manager';
      case 'CAD':
        return 'CAD_manager';
      default:
        return '';
    }
  }

  /// 실제 FCM 푸시 알림 전송
  static Future<bool> _sendActualPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // TODO: Firebase Console에서 가져온 Server Key로 교체 필요
      const String serverKey = 'YOUR_FIREBASE_SERVER_KEY_HERE';  // AAAA로 시작하는 키
      
      if (serverKey == 'YOUR_FIREBASE_SERVER_KEY_HERE') {
        print('⚠️ Firebase Server Key가 설정되지 않았습니다. Firebase Console에서 Server Key를 가져와서 설정해주세요.');
        return false;
      }
      
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Authorization': 'key=$serverKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': fcmToken,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'data': data,
          'priority': 'high',
        }),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == 1) {
          print('✅ FCM 알림 전송 성공: $title');
          return true;
        } else {
          print('❌ FCM 알림 전송 실패: ${responseData['results']}');
          return false;
        }
      } else {
        print('❌ FCM API 호출 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ FCM 알림 전송 중 오류: $e');
      return false;
    }
  }

  /// Admin + 부서별 관리자에게 이중 알림 전송
  static Future<void> sendNotificationToAdmins({
    required String title,
    required String body,
    required Map<String, String> data,
    String? requesterDepartment,
  }) async {
    try {
      print('📮 관리자들에게 알림 전송 시작: $title');
      
      // 1. 모든 admin 조회 (attendance_role에 'admin' 포함)
      final adminResponse = await Supabase.instance.client
          .from('employees')
          .select('email, name, fcm_token, attendance_role')
          .not('fcm_token', 'is', null);
      
      final allEmployees = (adminResponse as List).cast<Map<String, dynamic>>();
      
      // Admin 필터링 (attendance_role 배열에 'admin' 포함된 사용자)
      final adminList = allEmployees.where((emp) {
        final attendanceRole = emp['attendance_role'];
        if (attendanceRole == null) return false;
        if (attendanceRole is List) {
          return attendanceRole.contains('admin');
        }
        return false;
      }).toList();
      
      print('📊 Admin 대상자: ${adminList.length}명');
      
      // 2. 해당 부서 관리자 조회 (requesterDepartment가 있는 경우)
      List<Map<String, dynamic>> departmentManagerList = [];
      if (requesterDepartment != null && requesterDepartment.isNotEmpty) {
        final managerRole = _getManagerByDepartment(requesterDepartment);
        if (managerRole.isNotEmpty) {
          // attendance_role 배열에 해당 관리자 역할이 포함된 사용자 조회
          final departmentManagers = allEmployees.where((emp) {
            final attendanceRole = emp['attendance_role'];
            if (attendanceRole == null) return false;
            if (attendanceRole is List) {
              return attendanceRole.contains(managerRole);
            }
            return false;
          }).toList();
          
          departmentManagerList = departmentManagers;
          print('📊 $requesterDepartment 관리자 ($managerRole) 대상자: ${departmentManagerList.length}명');
        }
      }
      
      // 3. 중복 제거 (admin이면서 해당 부서 관리자인 경우)
      final allTargets = <String, Map<String, dynamic>>{};
      
      // Admin들 추가
      for (final admin in adminList) {
        if (admin['fcm_token'] != null && admin['fcm_token'].toString().isNotEmpty) {
          allTargets[admin['email']] = admin;
        }
      }
      
      // 부서 관리자들 추가 (중복 방지)
      for (final manager in departmentManagerList) {
        if (manager['fcm_token'] != null && manager['fcm_token'].toString().isNotEmpty) {
          allTargets[manager['email']] = manager;
        }
      }
      
      print('📊 최종 알림 대상자: ${allTargets.length}명');
      
      // 4. 각 대상자에게 실제 푸시 알림 전송
      int successCount = 0;
      int failureCount = 0;
      
      for (final target in allTargets.values) {
        try {
          print('📲 ${target['name']} (${target['email']})에게 알림 전송 중...');
          
          // 실제 FCM 푸시 알림 전송
          final success = await _sendActualPushNotification(
            fcmToken: target['fcm_token'],
            title: title,
            body: body,
            data: data,
          );
          
          if (success) {
            successCount++;
            print('   ✅ 성공');
          } else {
            failureCount++;
            print('   ❌ 실패');
          }
        } catch (e) {
          failureCount++;
          print('❌ ${target['email']} 알림 전송 실패: $e');
        }
      }
      
      print('✅ 알림 전송 완료: $successCount성공 / $failureCount실패 / ${allTargets.length}총');
      
      // 5. 알림 대상자 요약
      if (allTargets.isNotEmpty) {
        print('📋 알림 받은 사용자 목록:');
        for (final target in allTargets.values) {
          final roles = target['attendance_role'] as List?;
          print('   - ${target['name']} (${target['email']}) - 역할: ${roles?.join(", ") ?? "없음"}');
        }
      } else {
        print('⚠️ 알림을 받을 대상자가 없습니다. FCM 토큰이 등록된 admin 또는 관리자를 확인해주세요.');
      }
      
    } catch (e) {
      print('❌ 관리자 알림 전송 실패: $e');
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
} 