import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/attendance_service.dart';
import '../models/attendance.dart';

enum AttendanceStatus { beforeWork, working, late, offWork }

class AttendanceProvider extends ChangeNotifier {
  final String userId;
  final String userName;
  
  // 회사 위치 정보 (임시: 클라이언트 사이드 검증)
  static const double _companyLat = 35.844541;  // hansl 위도
  static const double _companyLng = 128.506440;  // hansl 경도
  static const double _allowedDistance = 100.0;  // meters

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

  // 두 지점 간의 거리 계산 (하버사인 공식)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 지구의 반지름 (미터)
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // 클라이언트 사이드 위치 검증
  bool _validateLocation(double latitude, double longitude) {
    final distance = _calculateDistance(latitude, longitude, _companyLat, _companyLng);
    return distance <= _allowedDistance;
  }

  // 클라이언트 사이드 시간 검증
  bool _validateWorkTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    
    // 00:00 ~ 18:00 사이에만 출근 가능
    if (hour >= 0 && hour < 18) {
      return true;
    } else if (hour == 18 && minute == 0) {
      return true;
    }
    return false;
  }

  // 지각 여부 판정 (09:00 기준)
  bool _isLateClockIn() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    
    // 09:00 이후면 지각
    return hour > 9 || (hour == 9 && minute > 0);
  }

  Future<void> tryClockIn() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    errorMessage = null;
    
    // 위치 권한 체크
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      errorMessage = '위치 서비스를 켜주세요.';
      isLoading = false;
      notifyListeners();
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        errorMessage = '위치 권한이 필요합니다.';
        isLoading = false;
        notifyListeners();
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      errorMessage = '위치 권한이 영구적으로 거부되었습니다.';
      isLoading = false;
      notifyListeners();
      return;
    }
    
    // GPS 위치 획득
    Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    // 클라이언트 사이드 위치 검증 (임시)
    if (!_validateLocation(pos.latitude, pos.longitude)) {
      final distance = _calculateDistance(pos.latitude, pos.longitude, _companyLat, _companyLng);
      errorMessage = '회사에서 ${distance.round()}m 떨어져 있습니다. 허용 범위: ${_allowedDistance.round()}m';
      isLoading = false;
      notifyListeners();
      return;
    }
    
    // 클라이언트 사이드 시간 검증 (임시)
    if (!_validateWorkTime()) {
      errorMessage = '출근 가능한 시간이 아닙니다. (00:00 ~ 18:00)';
      isLoading = false;
      notifyListeners();
      return;
    }
    
    // 지각 여부 판정
    var now = DateTime.now();
    isLate = _isLateClockIn();
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    try {
      
      // 오늘 내 row 찾기
      final record = await Supabase.instance.client
          .from('attendance_records')
          .select()
          .eq('employee_id', userId)
          .eq('date', todayStr)
          .maybeSingle();
      
      if (record != null) {
        // 기존 레코드가 있으면 UPDATE
        final updateResult = await Supabase.instance.client
            .from('attendance_records')
            .update({
              'clock_in': now.toIso8601String().substring(11, 19),
              'status': isLate ? '지각' : '정상 출근',
            })
            .eq('id', record['id']);
      } else {
        // 기존 레코드가 없으면 INSERT (새로 생성)
        final insertResult = await Supabase.instance.client
            .from('attendance_records')
            .insert({
              'date': todayStr,
              'employee_id': userId,
              'employee_name': userName,
              'clock_in': now.toIso8601String().substring(11, 19),
              'status': isLate ? '지각' : '정상 출근',
              'created_at': now.toIso8601String(),
            });
      }
    } catch (e) {
      errorMessage = '출근 등록 중 오류가 발생했습니다. 다시 시도해주세요.';
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
    
    // 퇴근 시간 확인 (임시: 클라이언트 사이드)
    var now = DateTime.now();
    
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    try {
      
      // 오늘 내 row 찾기
      final record = await Supabase.instance.client
          .from('attendance_records')
          .select()
          .eq('employee_id', userId)
          .eq('date', todayStr)
          .maybeSingle();
      
      if (record != null) {
        // 기존 레코드가 있으면 UPDATE
        final updateResult = await Supabase.instance.client
            .from('attendance_records')
            .update({
              'clock_out': now.toIso8601String().substring(11, 19),
              'status': '퇴근',
            })
            .eq('id', record['id']);
      } else {
        // 출근 기록 없이 퇴근하는 경우 (예외적 상황)
        final insertResult = await Supabase.instance.client
            .from('attendance_records')
            .insert({
              'date': todayStr,
              'employee_id': userId,
              'employee_name': userName,
              'clock_out': now.toIso8601String().substring(11, 19),
              'status': '퇴근',
              'created_at': now.toIso8601String(),
            });
      }
    } catch (e) {
      errorMessage = '퇴근 등록 중 오류가 발생했습니다. 다시 시도해주세요.';
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
    // 자정에 새로운 날 준비 (데이터 초기화 및 새로고침)
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);
    Timer(duration, () {
      _initToday(); // 새로운 날의 출근 상태 확인
      fetchRecentHistory(); // 출근 기록 새로고침
      _startMidnightResetTimer(); // 다음 자정을 위한 타이머 재설정
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