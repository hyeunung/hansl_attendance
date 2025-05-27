import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/attendance_service.dart';
import '../models/attendance.dart';

enum AttendanceStatus { beforeWork, working, late, offWork }

class AttendanceProvider extends ChangeNotifier {
  final String userId;
  final String userName;
 /* // 회사 위치
  static const double companyLat = 35.844541;  //hansl 위도
  static const double companyLng = 128.506440;  //hansl 경도
  */
    static const double companyLat = 35.804306;  //갈밭로12길 11 위도
  static const double companyLng = 128.529245;  //갈밭로12길 11 경도
  static const double allowedDistance = 100.0; // meters

  AttendanceStatus status = AttendanceStatus.beforeWork;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  bool isLate = false;
  String? errorMessage;
  List<AttendanceRecord> history = [];

  final AttendanceService _attendanceService = AttendanceService();

  bool isLoading = true;

  Color get statusColor {
    switch (status) {
      case AttendanceStatus.working:
        return const Color(0xFF1777CB); // 파랑
      case AttendanceStatus.late:
        return const Color(0xFFE53935); // 빨강
      case AttendanceStatus.offWork:
        return const Color(0xFFFFC107); // 노랑
      default:
        return const Color(0xFFB0B0B0); // 회색
    }
  }

  String get statusText {
    switch (status) {
      case AttendanceStatus.working:
        return '정상 출근';
      case AttendanceStatus.late:
        return '지각';
      case AttendanceStatus.offWork:
        return '퇴근';
      default:
        return '출근 전';
    }
  }

  // 출근 버튼 활성화 조건: 출근 전 & 위치 OK & 00:00~18:00
  bool canClockIn = true;
  // 퇴근 버튼 활성화 조건: 출근 후 & 퇴근 전
  bool get canClockOut => status == AttendanceStatus.working || status == AttendanceStatus.late;

  AttendanceProvider({required this.userId, required this.userName}) {
    _initToday().then((_) => fetchRecentHistory());
    _startMidnightResetTimer();
    _startAutoClockOutTimer();
  }

  Future<void> _initToday() async {
    isLoading = true;
    notifyListeners();
    final now = DateTime.now();
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    // DB에서 오늘 출근 기록 조회
    final record = await Supabase.instance.client
        .from('attendance_records')
        .select()
        .eq('employee_id', userId)
        .eq('date', todayStr)
        .maybeSingle();

    if (record != null && record['clock_in'] != null) {
      // 이미 출근함
      clockInTime = DateTime.parse('${todayStr}T${record['clock_in']}');
      clockOutTime = record['clock_out'] != null ? DateTime.tryParse('${todayStr}T${record['clock_out']}') : null;
      isLate = record['status'] == '지각';
      if (clockInTime != null && clockOutTime == null) {
        status = isLate ? AttendanceStatus.late : AttendanceStatus.working;
      } else if (clockInTime != null && clockOutTime != null) {
        status = AttendanceStatus.offWork;
      } else {
        status = AttendanceStatus.beforeWork;
      }
      canClockIn = false;
    } else {
      status = AttendanceStatus.beforeWork;
      clockInTime = null;
      clockOutTime = null;
      isLate = false;
      canClockIn = true;
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchRecentHistory() async {
    final records = await Supabase.instance.client
        .from('attendance_records')
        .select()
        .eq('employee_id', userId)
        .order('date', ascending: false)
        .limit(5);

    history = records.map<AttendanceRecord>((r) {
      final date = DateTime.parse(r['date']);
      final clockIn = r['clock_in'] != null ? DateTime.parse('${r['date']}T${r['clock_in']}') : null;
      final clockOut = r['clock_out'] != null ? DateTime.parse('${r['date']}T${r['clock_out']}') : null;
      return AttendanceRecord(
        date: date,
        employeeId: userId,
        employeeName: userName,
        status: r['status'],
        clockIn: clockIn,
        clockOut: clockOut,
        isLate: r['status'] == '지각',
      );
    }).toList();
    notifyListeners();
  }

  Future<void> tryClockIn() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    errorMessage = null;
    // 위치 권한 및 거리 체크
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      errorMessage = '위치 서비스를 켜주세요.';
      notifyListeners();
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        errorMessage = '위치 권한이 필요합니다.';
        notifyListeners();
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      errorMessage = '위치 권한이 영구적으로 거부되었습니다.';
      notifyListeners();
      return;
    }
    Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    double distance = Geolocator.distanceBetween(
      pos.latitude, pos.longitude, companyLat, companyLng,
    );
    if (distance > allowedDistance) {
      errorMessage = '근무지가 아닙니다';
      notifyListeners();
      return;
    }
    // 시간 체크
    final now = DateTime.now();
    final lateTime = DateTime(now.year, now.month, now.day, 8, 30);
    isLate = now.isAfter(lateTime);
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    // 오늘 내 row 찾기
    final record = await Supabase.instance.client
        .from('attendance_records')
        .select()
        .eq('employee_id', userId)
        .eq('date', todayStr)
        .maybeSingle();
    if (record != null) {
      await Supabase.instance.client
          .from('attendance_records')
          .update({
            'clock_in': now.toIso8601String().substring(11, 19),
            'status': isLate ? '지각' : '정상 출근',
          })
          .eq('id', record['id']);
    } else {
      errorMessage = '오늘자 출근 row가 없습니다. 관리자에게 문의하세요.';
      isLoading = false;
      notifyListeners();
      return;
    }
    clockInTime = now;
    status = isLate ? AttendanceStatus.late : AttendanceStatus.working;
    canClockIn = false;
    // history 갱신
    final today = DateTime(now.year, now.month, now.day);
    final idx = history.indexWhere((r) => _isSameDay(r.date, today));
    final recordObj = AttendanceRecord(
      date: today,
      employeeId: userId,
      employeeName: userName,
      status: isLate ? '지각' : '정상 출근',
      clockIn: now,
      clockOut: null,
      isLate: isLate,
    );
    if (idx != -1) {
      history[idx] = recordObj;
    } else {
      history.insert(0, recordObj);
      if (history.length > 5) {
        history = history.take(5).toList();
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> tryClockOut() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    if (clockInTime == null) {
      isLoading = false;
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    // 오늘 내 row 찾기
    final record = await Supabase.instance.client
        .from('attendance_records')
        .select()
        .eq('employee_id', userId)
        .eq('date', todayStr)
        .maybeSingle();
    if (record != null) {
      await Supabase.instance.client
          .from('attendance_records')
          .update({
            'clock_out': now.toIso8601String().substring(11, 19),
            'status': '퇴근',
          })
          .eq('id', record['id']);
    } else {
      errorMessage = '오늘자 출근 row가 없습니다. 관리자에게 문의하세요.';
      isLoading = false;
      notifyListeners();
      return;
    }
    clockOutTime = now;
    status = AttendanceStatus.offWork;
    // history 갱신
    final today = DateTime(now.year, now.month, now.day);
    final idx = history.indexWhere((r) => _isSameDay(r.date, today));
    final recordObj = AttendanceRecord(
      date: today,
      employeeId: userId,
      employeeName: userName,
      status: '퇴근',
      clockIn: clockInTime,
      clockOut: now,
      isLate: isLate,
    );
    if (idx != -1) {
      history[idx] = recordObj;
    } else {
      history.insert(0, recordObj);
      if (history.length > 5) {
        history = history.take(5).toList();
      }
    }
    isLoading = false;
    notifyListeners();
  }

  void _startMidnightResetTimer() {
    // 자정에 데이터 초기화
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);
    Timer(duration, () {
      _initToday();
      fetchRecentHistory(); // 자정에 history도 새로고침
      _startMidnightResetTimer();
    });
  }

  void _startAutoClockOutTimer() {
    // 18:00 자동 퇴근 처리
    final now = DateTime.now();
    final todaySix = DateTime(now.year, now.month, now.day, 18, 0);
    Duration duration;
    if (now.isBefore(todaySix)) {
      duration = todaySix.difference(now);
    } else {
      // 이미 18시가 지났으면 내일 18시로 예약
      final tomorrowSix = todaySix.add(const Duration(days: 1));
      duration = tomorrowSix.difference(now);
    }
    Timer(duration, () {
      _autoClockOut();
      _startAutoClockOutTimer();
    });
  }

  void _autoClockOut() {
    if (clockInTime != null && clockOutTime == null) {
      // 퇴근 미처리 시 18:00 자동 퇴근
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final autoOut = DateTime(now.year, now.month, now.day, 18, 0);
      clockOutTime = autoOut;
      status = AttendanceStatus.offWork;
      final idx = history.indexWhere((r) => _isSameDay(r.date, today));
      if (idx != -1) {
        history[idx] = AttendanceRecord(
          date: today,
          employeeId: userId,
          employeeName: userName,
          status: '퇴근',
          clockIn: clockInTime,
          clockOut: autoOut,
          isLate: isLate,
        );
      } else {
        history.insert(0, AttendanceRecord(
          date: today,
          employeeId: userId,
          employeeName: userName,
          status: '퇴근',
          clockIn: clockInTime,
          clockOut: autoOut,
          isLate: isLate,
        ));
      }
      notifyListeners();
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 오늘 근무 시간(문자열)
  String get todayWorkDuration {
    if (clockInTime == null) return '-';
    final end = clockOutTime ?? DateTime.now();
    final diff = end.difference(clockInTime!);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}시간 ${m}분';
  }

  // 출근/퇴근 시간 문자열
  String get clockInStr => clockInTime == null ? '-' : _formatTime(clockInTime!);
  String get clockOutStr => clockOutTime == null ? '-' : _formatTime(clockOutTime!);

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  // 최근 기록(오늘 포함 최대 5개, 최신순)
  List<AttendanceRecord> get recentHistory {
    final today = DateTime.now();
    return history.take(5).toList();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
} 