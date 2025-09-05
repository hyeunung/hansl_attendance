import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../main.dart';
import 'package:flutter/foundation.dart';

class AttendanceNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 회사 위치 (백엔드와 동일한 좌표)
  static const double _companyLatitude = 35.844541; // HANSL 본사
  static const double _companyLongitude = 128.506439;
  static const double _checkInRadius = 100.0; // 100미터 반경

  // 알림 채널 ID
  static const String _channelId = 'attendance_notifications';
  static const String _channelName = '출퇴근 알림';
  static const String _channelDescription = '출근 및 퇴근 시간을 알려드립니다';

  // 알림 ID
  static const int _checkInNotificationId = 1;
  static const int _checkOutNotificationId = 2;

  // Payload 타입
  static const String _checkInPayload = 'navigate_check_in';
  static const String _checkOutPayload = 'navigate_check_out';

  /// 알림 서비스 초기화
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // Android 초기화 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 초기화
    await _notifications.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _handleNotificationClick,
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationHandler,
    );

    // Android 알림 채널 생성
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    // 권한 요청
    await _requestPermissions();

    if (kDebugMode) print('✅ 출퇴근 알림 서비스 초기화 완료');
  }

  /// 알림 채널 생성 (Android)
  static Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 권한 요청
  static Future<void> _requestPermissions() async {
    // iOS 권한
    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Android 13+ 권한
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// 알림 클릭 핸들러
  static void _handleNotificationClick(NotificationResponse response) {
    final payload = response.payload;

    if (payload == null) return;

    // 메인 네비게이터를 통해 화면 이동
    if (navigatorKey.currentState != null) {
      if (payload == _checkInPayload) {
        // 출근 화면으로 이동 + 자동 다이얼로그
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/attendance',
          (route) => false,
          arguments: {'autoShowCheckIn': true},
        );
      } else if (payload == _checkOutPayload) {
        // 퇴근 화면으로 이동 + 자동 다이얼로그
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/attendance',
          (route) => false,
          arguments: {'autoShowCheckOut': true},
        );
      }
    }
  }

  /// 백그라운드 알림 핸들러
  @pragma('vm:entry-point')
  static void _backgroundNotificationHandler(NotificationResponse response) {
    // 백그라운드에서도 동일하게 처리
    _handleNotificationClick(response);
  }

  /// 위치 기반 출근 알림 시작
  static Future<void> startLocationBasedCheckInReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('location_check_in_reminder') ?? true;

    if (!isEnabled) return;

    // 위치 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) print('❌ 위치 권한이 거부되었습니다');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) print('❌ 위치 권한이 영구적으로 거부되었습니다');
      return;
    }

    // 백그라운드 위치 스트림 시작
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // 50미터 이동시마다 체크
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        final now = DateTime.now();

        // 주말 체크
        if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
          return;
        }

        // 공휴일 체크
        if (await _isHoliday(now)) {
          return;
        }

        // 출근 시간대 체크 (오전 7시 ~ 10시)
        if (now.hour < 7 || now.hour >= 10) return;

        // 이미 출근했는지 체크
        final hasCheckedIn = await _hasCheckedInToday();
        if (hasCheckedIn) return;

        // 회사 근처인지 체크
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          _companyLatitude,
          _companyLongitude,
        );

        if (distance <= _checkInRadius) {
          // 오늘 이미 알림을 보냈는지 체크
          final hasShownToday = await _hasShownCheckInNotificationToday();
          if (!hasShownToday) {
            await _showCheckInNotification();
            await _markCheckInNotificationShown();
          }
        }
      },
      onError: (error) {
        if (kDebugMode) print('❌ 위치 스트림 에러: $error');
      },
    );

    if (kDebugMode) print('✅ 위치 기반 출근 알림 시작');
  }

  /// 시간 기반 퇴근 알림 설정
  static Future<void> scheduleCheckOutReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('check_out_reminder') ?? true;

    if (!isEnabled) return;

    // 퇴근 시간 가져오기 (기본값: 오후 6시)
    final checkOutHour = prefs.getInt('check_out_hour') ?? 18;
    final checkOutMinute = prefs.getInt('check_out_minute') ?? 0;

    // 다음 퇴근 시간 계산
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, checkOutHour, checkOutMinute);

    // 이미 시간이 지났으면 다음날로 설정
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 주말 및 공휴일 제외
    while (scheduledDate.weekday == DateTime.saturday ||
        scheduledDate.weekday == DateTime.sunday ||
        await _isHoliday(scheduledDate)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 알림 예약
    await _notifications.zonedSchedule(
      _checkOutNotificationId,
      '퇴근 시간입니다 🏠',
      '오늘도 수고하셨어요! 탭하여 퇴근 체크하기',
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          ticker: '퇴근 시간',
          icon: '@mipmap/ic_launcher',
          color: Colors.blue,
          actions: [
            const AndroidNotificationAction('check_out_action', '퇴근하기', showsUserInterface: true),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          categoryIdentifier: 'CHECK_OUT_CATEGORY',
        ),
      ),
      payload: _checkOutPayload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
    );

    if (kDebugMode) print('✅ 퇴근 알림 예약 완료: ${scheduledDate.toString()}');
  }

  /// 출근 알림 표시
  static Future<void> _showCheckInNotification() async {
    await _notifications.show(
      _checkInNotificationId,
      '출근 시간입니다 🏢',
      '회사 근처에 도착하셨네요! 탭하여 출근 체크하기',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          ticker: '출근 알림',
          icon: '@mipmap/ic_launcher',
          color: Colors.green,
          actions: [
            const AndroidNotificationAction('check_in_action', '출근하기', showsUserInterface: true),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          categoryIdentifier: 'CHECK_IN_CATEGORY',
        ),
      ),
      payload: _checkInPayload,
    );
  }

  /// 출근 완료 알림
  static Future<void> showCheckInSuccessNotification() async {
    await _notifications.show(
      999, // 다른 ID 사용
      '출근이 완료되었습니다 ✅',
      '좋은 하루 되세요!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
          color: Colors.green,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: false),
      ),
    );
  }

  /// 퇴근 완료 알림
  static Future<void> showCheckOutSuccessNotification() async {
    await _notifications.show(
      998, // 다른 ID 사용
      '퇴근이 완료되었습니다 ✅',
      '오늘도 수고하셨습니다!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
          color: Colors.blue,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: false),
      ),
    );
  }

  /// 오늘 출근했는지 확인
  static Future<bool> _hasCheckedInToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckIn = prefs.getString('last_check_in_date');

    if (lastCheckIn == null) return false;

    final lastDate = DateTime.parse(lastCheckIn);
    final today = DateTime.now();

    return lastDate.year == today.year &&
        lastDate.month == today.month &&
        lastDate.day == today.day;
  }

  /// 오늘 출근 알림을 보냈는지 확인
  static Future<bool> _hasShownCheckInNotificationToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString('last_check_in_notification');

    if (lastShown == null) return false;

    final lastDate = DateTime.parse(lastShown);
    final today = DateTime.now();

    return lastDate.year == today.year &&
        lastDate.month == today.month &&
        lastDate.day == today.day;
  }

  /// 출근 알림 표시 기록
  static Future<void> _markCheckInNotificationShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_check_in_notification', DateTime.now().toIso8601String());
  }

  /// 알림 권한 상태 확인
  static Future<bool> hasNotificationPermission() async {
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final settings = await ios?.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return false;
  }

  /// 모든 알림 취소
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 특정 알림 취소
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// 공휴일 체크
  static Future<bool> _isHoliday(DateTime date) async {
    try {
      // Supabase에서 공휴일 정보 조회
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final response = await Supabase.instance.client
          .from('holidays')
          .select('id')
          .eq('date', dateStr)
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) print('공휴일 체크 실패: $e');
      // 에러 발생시 공휴일이 아닌 것으로 처리
      return false;
    }
  }
}
