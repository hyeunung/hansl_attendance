import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import '../models/attendance.dart';
import '../services/timer_manager.dart';
import '../services/async_operation_manager.dart' as async_ops;
import '../services/cache_service.dart';

enum AttendanceStatus { beforeWork, working, late, offWork }

class AttendanceProvider extends ChangeNotifier
    with TimerManagementMixin, async_ops.AsyncOperationMixin {
  final String userId;
  final String userName;
  String? userEmail;

  // Edge Functions endpoints
  // 위치 기반 자동 출근 기능 제거에 따라 사용하지 않음
  static const String _validateLocationEndpoint = 'validate_location';
  static const String _validateWorkTimeEndpoint = 'validate_work_time';

  // 회사 위치 (클라이언트 사이드 폴백용)
  static const double _companyLat = 35.844541;
  static const double _companyLng = 128.506439;
  static const double _allowedDistance = 100.0; // meters

  AttendanceStatus status = AttendanceStatus.beforeWork;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  bool isLate = false;
  String? errorMessage;
  List<AttendanceRecord> history = [];

  bool isLoading = true;
  bool isClockInLoading = false;
  bool isClockOutLoading = false;

  // 지각 통계
  int _monthlyLateCount = 0;
  int _yearlyLateCount = 0;

  // Cache service for performance optimization
  final CacheService _cache = CacheService.instance;

  // Cache keys
  static const String _todayAttendanceCacheKey = 'today_attendance_';
  static const String _attendanceHistoryCacheKey = 'attendance_history_';

  // Batch update support
  bool _shouldNotify = true;

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
  bool get canClockOut =>
      status == AttendanceStatus.working || status == AttendanceStatus.late;

  // 지각 통계 Getters
  int get monthlyLateCount => _monthlyLateCount;
  int get yearlyLateCount => _yearlyLateCount;

  AttendanceProvider({required this.userId, required this.userName}) {
    _initializeProvider();
  }

  void setUserEmail(String email) {
    
    userEmail = email;
    // email이 설정되면 지각 통계 다시 로드
    fetchLateStatistics();
  }

  Future<void> _initializeProvider() async {
    // Initialize cache service
    await _cache.init();

    // Initialize today's data with cancellation support
    await executeScopedOperation(
      key: 'init_today',
      operation: (token) async {
        token.throwIfCancelled();
        await _initToday();
        token.throwIfCancelled();
        await fetchRecentHistory();
        token.throwIfCancelled();
        await fetchLateStatistics(); // 지각 통계 로드
        return true;
      },
      timeout: const Duration(seconds: 30),
      description: 'Initialize attendance provider',
    );

    // Start optimized timers
    _startOptimizedTimers();
  }

  Future<void> _initToday() async {
    _updateLoadingState(true);
    final now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    

    // userId가 비어있거나 유효하지 않으면 기본값 설정
    if (userId.isEmpty || userId == '') {
      
      status = AttendanceStatus.beforeWork;
      clockInTime = null;
      clockOutTime = null;
      isLate = false;
      canClockIn = false; // 로그인 전에는 출근 버튼 비활성화
      _updateLoadingState(false);
      notifyListeners();
      return;
    }

    try {
      // Supabase를 사용하여 오늘 출근 기록 조회
      // auth.users.id로 조회 (Edge Function이 이 ID로 생성함)
      final records = await Supabase.instance.client
          .from('attendance_records')
          .select()
          .eq('employee_id', userId)
          .eq('date', todayStr)
          .limit(1);

      final record = records.isNotEmpty ? records.first : null;

      if (record != null && record['clock_in'] != null) {
        // DB에 출근 기록이 있음
        clockInTime = DateTime.parse('${todayStr}T${record['clock_in']}');
        clockOutTime = record['clock_out'] != null
            ? DateTime.tryParse('${todayStr}T${record['clock_out']}')
            : null;
        isLate = record['status'] == '지각';

        if (clockOutTime != null) {
          // 출근 + 퇴근 모두 있음
          status = AttendanceStatus.offWork;
        } else {
          // 출근만 있고 퇴근은 없음
          status = isLate ? AttendanceStatus.late : AttendanceStatus.working;
        }
        canClockIn = false;
      } else {
        // DB에 오늘 기록이 전혀 없음 - 완전 초기화
        
        status = AttendanceStatus.beforeWork;
        clockInTime = null;
        clockOutTime = null;
        isLate = false;
        canClockIn = true;
      }
    } catch (e) {
      
      // 에러 발생 시 안전한 초기 상태로
      status = AttendanceStatus.beforeWork;
      clockInTime = null;
      clockOutTime = null;
      isLate = false;
      canClockIn = true;
    }

    _updateLoadingState(false);
    notifyListeners(); // 강제로 UI 업데이트
  }

  Future<void> fetchRecentHistory() async {
    // userId가 비어있으면 건너뛰기
    if (userId.isEmpty || userId == '') {
      
      history = [];
      notifyListeners();
      return;
    }

    return await executeScopedOperation(
      key: 'fetch_history',
      operation: (token) async {
        token.throwIfCancelled();

        // Supabase를 사용하여 최근 이력 조회
        final records = await Supabase.instance.client
            .from('attendance_records')
            .select()
            .eq('employee_id', userId)
            .order('date', ascending: false)
            .limit(5);

        token.throwIfCancelled();

        if (records.isNotEmpty) {
          _processHistoryRecords(records);
        }
      },
      timeout: const Duration(seconds: 30),
      cancelPrevious: true,
      description: 'Fetch attendance history',
    );
  }

  void _processHistoryRecords(List<Map<String, dynamic>> records) {
    final newHistory = records.map<AttendanceRecord>((r) {
      final date = DateTime.parse(r['date']);
      final clockIn = r['clock_in'] != null
          ? DateTime.parse('${r['date']}T${r['clock_in']}')
          : null;
      final clockOut = r['clock_out'] != null
          ? DateTime.parse('${r['date']}T${r['clock_out']}')
          : null;
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

    // 히스토리가 실제로 변경된 경우에만 알림
    if (!_isHistoryEqual(history, newHistory)) {
      _batchUpdate(() {
        history = newHistory;
      });
    }
  }

  // 두 지점 간의 거리 계산 (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // 지구의 반지름 (미터)
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // 서버사이드 위치 검증 호출
  Future<Map<String, dynamic>> _validateLocationWithServer(
    double latitude,
    double longitude,
    async_ops.CancellationToken token,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        _validateLocationEndpoint,
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'employeeId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      token.throwIfCancelled();

      

      // Supabase Edge Function은 status가 null일 수 있음
      final status = response.status;

      if (status != 200) {
        throw Exception('서버 오류: HTTP $status');
      }

      if (response.data == null) {
        throw Exception('위치 검증 실패: 응답 데이터 없음');
      }

      // response.data가 String인 경우 처리 (JSON 파싱 필요)
      Map<String, dynamic> responseData;
      if (response.data is String) {
        try {
          responseData = json.decode(response.data);
        } catch (e) {
          throw Exception('응답 파싱 실패: ${response.data}');
        }
      } else if (response.data is Map) {
        responseData = response.data as Map<String, dynamic>;
      } else {
        throw Exception('예상치 못한 응답 형식: ${response.data.runtimeType}');
      }

      // Check if error exists in response
      if (responseData['error'] != null) {
        throw Exception(responseData['error']);
      }

      return responseData;
    } catch (e) {
      rethrow;
    }
  }

  // 서버사이드 시간 검증 호출
  Future<Map<String, dynamic>> _validateWorkTimeWithServer(
    String action,
    async_ops.CancellationToken token,
  ) async {
    final response = await Supabase.instance.client.functions.invoke(
      _validateWorkTimeEndpoint,
      body: {
        'employeeId': userId,
        'action': action,
        'clientTime': DateTime.now().toIso8601String(),
      },
    );

    token.throwIfCancelled();

    if (response.data == null) {
      throw Exception('시간 검증 실패');
    }

    return response.data as Map<String, dynamic>;
  }

  Future<void> tryClockIn() async {
    if (isLoading) return;

    // Use async operation manager with cancellation support
    return await executeScopedOperation(
      key: 'clock_in',
      operation: (token) => _performClockIn(token),
      timeout: const Duration(seconds: 30),
      cancelPrevious: true,
      description: 'Clock in operation',
    );
  }

  Future<void> _performClockIn(async_ops.CancellationToken token) async {
    // Don't update loading state here to avoid flickering
    errorMessage = null;

    token.throwIfCancelled();

    // 위치 권한 체크
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _updateErrorAndLoading('위치 서비스를 켜주세요.', false);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _updateErrorAndLoading('위치 권한이 필요합니다.', false);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _updateErrorAndLoading('위치 권한이 영구적으로 거부되었습니다.', false);
      return;
    }

    // GPS 위치 획득 with cancellation support
    Position pos;
    try {
      pos = await Future.any([
        Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium, // 안드로이드에서 더 빠른 위치 획득
          forceAndroidLocationManager: true, // 안드로이드에서 더 안정적인 위치 획득
          timeLimit: const Duration(seconds: 20), // 내부 타임아웃도 설정
        ),
        Future.delayed(
          const Duration(seconds: 20), // 타임아웃을 20초로 연장
          () => throw async_ops.TimeoutException(
            'GPS timeout',
            const Duration(seconds: 20),
          ),
        ),
      ]);
      token.throwIfCancelled();

      // DEBUG: 시뮬레이터에서 테스트를 위해 회사 위치 사용
      
    } catch (e) {
      

      // 안드로이드에서 위치 획득 실패 시 한 번 더 시도
      if (Platform.isAndroid) {
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low, // 더 낮은 정확도로 재시도
            forceAndroidLocationManager: true,
            timeLimit: const Duration(seconds: 10),
          );
          token.throwIfCancelled();
        } catch (retryError) {
          
          _updateErrorAndLoading('위치 정보를 가져오는데 실패했습니다. GPS를 확인해주세요.', false);
          return;
        }
      } else {
        _updateErrorAndLoading('위치 정보를 가져오는데 실패했습니다.', false);
        return;
      }
    }

    // 서버사이드 위치 검증
    if (!kDebugMode) {
      try {
        final locationResult = await _validateLocationWithServer(
          pos.latitude,
          pos.longitude,
          token,
        );

        if (!locationResult['isValid']) {
          _updateErrorAndLoading('출근 가능한 장소가 아닙니다.', false);
          return;
        }
      } catch (e) {
        // 에러 로깅
        

        // Edge Function 오류 시 클라이언트 사이드 검증으로 폴백
        final distance = _calculateDistance(
          pos.latitude,
          pos.longitude,
          _companyLat,
          _companyLng,
        );

        

        if (distance > _allowedDistance) {
          _updateErrorAndLoading('출근 가능한 장소가 아닙니다.', false);
          return;
        }

        // 위치는 맞지만 서버 연결 문제가 있을 때
        // 사용자에게 알리지만 출근은 허용

        // 사용자에게 서버 연결 문제를 알림 (위치는 확인됨)
        // 이 메시지는 출근은 되지만 서버 연결이 불안정함을 알려줌
        // 나중에 제거하거나 수정 필요
      }
    } else {
    }

    token.throwIfCancelled();

    // 오늘 날짜 문자열 먼저 생성
    final todayStr =
        "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

    // 서버사이드 시간 검증 (일단 일반 직원 기준으로 처리)
    Map<String, dynamic> timeResult = {'isValid': true, 'isLate': false};
    if (!kDebugMode) {
      try {
        timeResult = await _validateWorkTimeWithServer('clockIn', token);

        if (!timeResult['isValid']) {
          // 서버 검증 실패 시 클라이언트에서 지각 여부만 판단하고 계속 진행
          final now = DateTime.now();
          final hour = now.hour;
          final minute = now.minute;
          // 일단 일반 직원 기준으로 처리 (오전반차는 나중에 레코드 확인 후 재판단)
          isLate = hour >= 9 || (hour == 8 && minute > 30);
        } else {
          isLate = timeResult['isLate'] ?? false;
        }
      } catch (e) {
        
        // 시간 검증 실패해도 출근은 허용 (시간만 클라이언트에서 체크)
        final now = DateTime.now();
        final hour = now.hour;
        final minute = now.minute;
        isLate = hour >= 9 || (hour == 8 && minute > 30);
      }
    } else {
      
      // 8시 30분 이후면 지각으로 설정
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;
      isLate = hour >= 9 || (hour == 8 && minute > 30);
    }

    var now = DateTime.now();
    // todayStr은 이미 위에서 선언됨

    try {
      token.throwIfCancelled();

      // Supabase client를 직접 사용하여 오늘 기록 조회
      final existingRecords = await Supabase.instance.client
          .from('attendance_records')
          .select()
          .eq('employee_id', userId)
          .eq('date', todayStr)
          .limit(1);

      if (existingRecords.isNotEmpty) {
      }

      final record = existingRecords.isNotEmpty ? existingRecords.first : null;
      token.throwIfCancelled();

      if (record != null) {
        // 기존 레코드가 있으면 UPDATE

        // 오전반차인 경우 특별 처리
        String newStatus;
        if (record['status'] == '오전반차') {
          // 오전반차 직원의 지각 판단: 13:30 기준
          final hour = now.hour;
          final minute = now.minute;
          final halfAmLate = hour > 13 || (hour == 13 && minute > 30);
          newStatus = halfAmLate ? '지각' : '정상 출근';
        } else {
          // 기존 로직 유지 (일반 직원 8:30 기준)
          newStatus = isLate ? '지각' : '정상 출근';
        }

        final updateData = {
          'clock_in': now.toIso8601String().substring(11, 19),
          'status': newStatus,
          'updated_at': now.toIso8601String(),
        };

        await Supabase.instance.client
            .from('attendance_records')
            .update(updateData)
            .eq('id', record['id'])
            .select();
      } else {
        // 기존 레코드가 없으면 INSERT (새로 생성)

        final insertData = {
          'date': todayStr,
          'employee_id': userId,
          'employee_name': userName,
          'clock_in': now.toIso8601String().substring(11, 19),
          'status': isLate ? '지각' : '정상 출근',
          'created_at': now.toIso8601String(),
        };

        await Supabase.instance.client
            .from('attendance_records')
            .insert(insertData)
            .select();
      }
    } catch (e) {
      // 더 구체적인 에러 메시지
      String errorMsg = '출근 등록 중 오류가 발생했습니다.';
      if (e.toString().contains('duplicate')) {
        errorMsg = '이미 출근 기록이 있습니다.';
      } else if (e.toString().contains('permission') ||
          e.toString().contains('RLS')) {
        errorMsg = '권한 오류가 발생했습니다. 관리자에게 문의하세요.';
      } else if (e.toString().contains('network')) {
        errorMsg = '네트워크 연결을 확인해주세요.';
      }

      _updateErrorAndLoading(errorMsg, false);
      return;
    }

    // 모든 상태 변경을 배치로 처리 및 캐시 무효화
    await _invalidateAttendanceCaches();

    _batchUpdate(() {
      clockInTime = now;
      status = isLate ? AttendanceStatus.late : AttendanceStatus.working;
      canClockIn = false;
      isLate = isLate;
      // Don't update isLoading to avoid flickering
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
    });

    // DB에서 최신 상태를 다시 불러와서 UI 업데이트
    await _initToday();
  }

  Future<void> tryClockOut() async {
    if (isLoading) return;
    if (clockInTime == null) {
      return;
    }

    // Use async operation manager with cancellation support
    return await executeScopedOperation(
      key: 'clock_out',
      operation: (token) => _performClockOut(token),
      timeout: const Duration(seconds: 30),
      cancelPrevious: true,
      description: 'Clock out operation',
    );
  }

  Future<void> _performClockOut(async_ops.CancellationToken token) async {
    // Don't update loading state here to avoid flickering

    token.throwIfCancelled();

    // 위치 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _updateErrorAndLoading('위치 권한이 필요합니다.', false);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _updateErrorAndLoading('위치 권한이 영구적으로 거부되었습니다.', false);
      return;
    }

    // GPS 위치 획득 with cancellation support
    Position pos;
    try {
      pos = await Future.any([
        Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium, // 안드로이드에서 더 빠른 위치 획득
          forceAndroidLocationManager: true, // 안드로이드에서 더 안정적인 위치 획득
          timeLimit: const Duration(seconds: 20), // 내부 타임아웃도 설정
        ),
        Future.delayed(
          const Duration(seconds: 20), // 타임아웃을 20초로 연장
          () => throw async_ops.TimeoutException(
            'GPS timeout',
            const Duration(seconds: 20),
          ),
        ),
      ]);
      token.throwIfCancelled();

      // DEBUG: 시뮬레이터에서 테스트를 위해 회사 위치 사용 (퇴근도 동일)
      
    } catch (e) {
      

      // 안드로이드에서 위치 획득 실패 시 한 번 더 시도
      if (Platform.isAndroid) {
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low, // 더 낮은 정확도로 재시도
            forceAndroidLocationManager: true,
            timeLimit: const Duration(seconds: 10),
          );
          token.throwIfCancelled();
        } catch (retryError) {
          
          _updateErrorAndLoading('위치 정보를 가져오는데 실패했습니다. GPS를 확인해주세요.', false);
          return;
        }
      } else {
        _updateErrorAndLoading('위치 정보를 가져오는데 실패했습니다.', false);
        return;
      }
    }

    // 서버사이드 위치 검증 - 퇴근도 동일하게 위치 검증 (디버그 모드 포함)
    // 출근과 동일하게 회사 근처에서만 퇴근 가능
    {
      try {
        final locationResult = await _validateLocationWithServer(
          pos.latitude,
          pos.longitude,
          token,
        );

        if (!locationResult['isValid']) {
          _updateErrorAndLoading('퇴근 가능한 장소가 아닙니다.', false);
          return;
        }
      } catch (e) {
        // 에러 로깅
        

        // Edge Function 오류 시 클라이언트 사이드 검증으로 폴백
        final distance = _calculateDistance(
          pos.latitude,
          pos.longitude,
          _companyLat,
          _companyLng,
        );

        

        if (distance > _allowedDistance) {
          _updateErrorAndLoading('퇴근 가능한 장소가 아닙니다.', false);
          return;
        }

        // 위치는 맞지만 서버 연결 문제가 있을 때

        // 사용자에게 서버 연결 문제를 알림 (위치는 확인됨)
        // 이 메시지는 퇴근은 되지만 서버 연결이 불안정함을 알려줌
        // 나중에 제거하거나 수정 필요
      }
    }

    token.throwIfCancelled();

    // 서버사이드 시간 검증 - 디버그 모드에서는 스킵
    if (!kDebugMode) {
      try {
        final timeResult = await _validateWorkTimeWithServer('clockOut', token);

        if (!timeResult['isValid']) {
          _updateErrorAndLoading(timeResult['message'] ?? '퇴근 시간 검증 실패', false);
          return;
        }
      } catch (e) {
        
        // 시간 검증 실패해도 퇴근은 허용 - 계속 진행
      }
    } else {
      
    }

    var now = DateTime.now();

    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      token.throwIfCancelled();

      

      // Supabase client를 직접 사용하여 오늘 기록 조회
      final existingRecords = await Supabase.instance.client
          .from('attendance_records')
          .select()
          .eq('employee_id', userId)
          .eq('date', todayStr)
          .limit(1);

      final record = existingRecords.isNotEmpty ? existingRecords.first : null;
      token.throwIfCancelled();

      if (record != null) {
        // 기존 레코드가 있으면 UPDATE
        

        await Supabase.instance.client
            .from('attendance_records')
            .update({
              'clock_out': now.toIso8601String().substring(11, 19),
              'status': '퇴근',
              'updated_at': now.toIso8601String(),
            })
            .eq('id', record['id']);
        
      } else {
        // 출근 기록 없이 퇴근하는 경우 (예외적 상황)
        

        final insertData = {
          'date': todayStr,
          'employee_id': userId,
          'employee_name': userName,
          'clock_out': now.toIso8601String().substring(11, 19),
          'status': '퇴근',
          'created_at': now.toIso8601String(),
        };

        

        await Supabase.instance.client
            .from('attendance_records')
            .insert(insertData);
        
      }
    } catch (e) {
      

      // 더 구체적인 에러 메시지
      String errorMsg = '퇴근 등록 중 오류가 발생했습니다.';
      if (e.toString().contains('duplicate')) {
        errorMsg = '이미 퇴근 기록이 있습니다.';
      } else if (e.toString().contains('permission') ||
          e.toString().contains('RLS')) {
        errorMsg = '권한 오류가 발생했습니다. 관리자에게 문의하세요.';
      } else if (e.toString().contains('network')) {
        errorMsg = '네트워크 연결을 확인해주세요.';
      }

      _updateErrorAndLoading(errorMsg, false);
      return;
    }

    // 모든 상태 변경을 배치로 처리 및 캐시 무효화
    await _invalidateAttendanceCaches();

    _batchUpdate(() {
      clockOutTime = now;
      status = AttendanceStatus.offWork;
      // Don't update isLoading to avoid flickering
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
    });
  }

  void _startOptimizedTimers() {
    // Start midnight reset timer (single long-running timer)
    _scheduleMidnightReset();

    // Start auto clock-out timer (single long-running timer)
    _scheduleAutoClockOut();

    // Start periodic maintenance timer (every 30 minutes)
    createScopedPeriodicTimer(
      key: 'maintenance',
      interval: const Duration(minutes: 30),
      callback: (timer) => _performMaintenance(),
    );
  }

  void _scheduleMidnightReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);

    createScopedTimer(
      key: 'midnight_reset',
      delay: duration,
      callback: () {
        // Execute midnight reset with error handling
        executeScopedOperation(
          key: 'midnight_reset_operation',
          operation: (token) async {
            // 자정이 되면 먼저 전날 퇴근 안 찍은 사람들 처리
            await _processYesterdayMissingClockOuts();
            token.throwIfCancelled();
            await _invalidateAttendanceCaches();
            token.throwIfCancelled();
            await _initToday();
            token.throwIfCancelled();
            await fetchRecentHistory();
            return true;
          },
          timeout: const Duration(seconds: 30),
          description: 'Midnight reset operation',
        ).catchError((e) {
          return false;
        });

        // Schedule next midnight reset
        _scheduleMidnightReset();
      },
    );
    
  }

  void _scheduleAutoClockOut() {
    final now = DateTime.now();
    final todaySix = DateTime(now.year, now.month, now.day, 18, 0);
    Duration duration;

    if (now.isBefore(todaySix)) {
      duration = todaySix.difference(now);
    } else {
      // Already past 6 PM, schedule for tomorrow 6 PM
      final tomorrowSix = todaySix.add(const Duration(days: 1));
      duration = tomorrowSix.difference(now);
    }

    createScopedTimer(
      key: 'auto_clock_out',
      delay: duration,
      callback: () {
        // Execute auto clock-out with error handling
        executeScopedOperation(
          key: 'auto_clock_out_operation',
          operation: (token) async {
            await _autoClockOut();
          },
          timeout: const Duration(seconds: 15),
          description: 'Auto clock-out operation',
        ).catchError((e) {
        });

        // Schedule next auto clock-out
        _scheduleAutoClockOut();
      },
    );
    
  }

  void _performMaintenance() {
    // Clean up expired cache entries
    _cache.getStats();

    // Log timer statistics in debug mode
    
  }

  Future<void> _autoClockOut() async {
    if (clockInTime != null && clockOutTime == null) {
      // 퇴근 미처리 시 18:00 자동 퇴근
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final autoOut = DateTime(now.year, now.month, now.day, 18, 0);
      final todayStr =
          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      try {
        // DB에 자동 퇴근 기록 저장
        await Supabase.instance.client
            .from('attendance_records')
            .update({
              'clock_out': '18:00:00',
              'status': '퇴근',
              'updated_at': now.toIso8601String(),
            })
            .eq('employee_id', userId)
            .eq('date', todayStr);

        

        // DB 저장 성공 후 프론트엔드 상태 업데이트
        _batchUpdate(() {
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
            history.insert(
              0,
              AttendanceRecord(
                date: today,
                employeeId: userId,
                employeeName: userName,
                status: '퇴근',
                clockIn: clockInTime,
                clockOut: autoOut,
                isLate: isLate,
              ),
            );
          }
        });
      } catch (e) {
        // 오류 발생 시 무시
      }
    }
  }

  // 자정이 되면 전날 퇴근 안 찍은 기록들을 18:00 퇴근으로 처리
  Future<void> _processYesterdayMissingClockOuts() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        "${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    try {
      // 전날 출근했지만 퇴근 안 찍은 모든 기록 찾기
      final allRecords = await Supabase.instance.client
          .from('attendance_records')
          .select()
          .eq('date', yesterdayStr);

      // clock_in은 있지만 clock_out이 없는 기록 필터링
      final missingClockOuts = allRecords
          .where(
            (record) =>
                record['clock_in'] != null && record['clock_out'] == null,
          )
          .toList();

      if (missingClockOuts.isNotEmpty) {
        

        // 각 기록에 대해 18:00 퇴근 처리
        for (final record in missingClockOuts) {
          await Supabase.instance.client
              .from('attendance_records')
              .update({
                'clock_out': '18:00:00',
                'status': '퇴근',
                'updated_at': now.toIso8601String(),
              })
              .eq('id', record['id']);
          
        }
      }
    } catch (e) {
      // 전날 퇴근 처리 실패 시 무시
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
    return '$h시간 $m분';
  }

  // 출근/퇴근 시간 문자열
  String get clockInStr =>
      clockInTime == null ? '-' : _formatTime(clockInTime!);
  String get clockOutStr =>
      clockOutTime == null ? '-' : _formatTime(clockOutTime!);

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  // 최근 기록(오늘 포함 최대 5개, 최신순)
  List<AttendanceRecord> get recentHistory {
    return history.take(5).toList();
  }

  void clearError() {
    if (errorMessage != null) {
      errorMessage = null;
      _debouncedNotify();
    }
  }

  // 배치 업데이트 헬퍼 메서드들
  void _batchUpdate(VoidCallback updates) {
    _shouldNotify = false;
    updates();
    _shouldNotify = true;
    _debouncedNotify();
  }

  void _updateLoadingState(bool loading) {
    if (isLoading != loading) {
      isLoading = loading;
      _debouncedNotify();
    }
  }

  void _updateErrorAndLoading(String error, bool loading) {
    _batchUpdate(() {
      errorMessage = error;
      isLoading = loading;
    });
  }

  // 디바운싱된 알림 (using TimerManager)
  void _debouncedNotify() {
    scopedDebounce(
      key: 'notify_debounce',
      delay: const Duration(milliseconds: 50), // Reduced for faster UI updates
      callback: () {
        if (_shouldNotify) {
          notifyListeners();
        }
      },
    );
  }

  // 히스토리 비교 헬퍼
  bool _isHistoryEqual(
    List<AttendanceRecord> old,
    List<AttendanceRecord> newList,
  ) {
    if (old.length != newList.length) return false;
    for (int i = 0; i < old.length; i++) {
      if (old[i].date != newList[i].date ||
          old[i].status != newList[i].status ||
          old[i].clockIn != newList[i].clockIn ||
          old[i].clockOut != newList[i].clockOut) {
        return false;
      }
    }
    return true;
  }

  // 캐시 무효화 헬퍼 메서드들
  Future<void> _invalidateAttendanceCaches() async {
    final now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    await _cache.invalidate('$_todayAttendanceCacheKey${userId}_$todayStr');
    await _cache.invalidate('$_attendanceHistoryCacheKey$userId');
    
  }

  /// Force refresh all attendance data
  Future<void> forceRefreshAll() async {
    // 캐시 완전 삭제
    await _cache.invalidatePattern('attendance_');

    // 프론트엔드 상태 완전 리셋
    status = AttendanceStatus.beforeWork;
    clockInTime = null;
    clockOutTime = null;
    isLate = false;
    canClockIn = true;
    errorMessage = null;
    history.clear();

    // DB에서 다시 로드
    await _initToday();
    await fetchRecentHistory();
  }

  /// 지각 통계 로드
  Future<void> fetchLateStatistics() async {
    try {
      // userEmail이 없으면 건너뛰기
      if (userEmail == null || userEmail!.isEmpty) {
        _monthlyLateCount = 0;
        _yearlyLateCount = 0;
        notifyListeners();
        return;
      }

      final now = DateTime.now();
      final year = now.year;
      final month = now.month;

      // 이번 달 시작일과 종료일
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);

      // 올해 시작일
      final yearStart = DateTime(year, 1, 1);

      // 먼저 email로 employee_id 찾기
      final employeeResult = await Supabase.instance.client
          .from('employees')
          .select('id')
          .eq('email', userEmail!)
          .single();

      final employeeId = employeeResult['id'] as String;

      // 이번 달 지각 카운트
      final monthlyRecords = await Supabase.instance.client
          .from('attendance_records')
          .select('status')
          .eq('employee_id', employeeId)
          .eq('status', '지각')
          .gte('date', monthStart.toIso8601String().split('T')[0])
          .lte('date', monthEnd.toIso8601String().split('T')[0]);

      // 올해 지각 카운트
      final yearlyRecords = await Supabase.instance.client
          .from('attendance_records')
          .select('status')
          .eq('employee_id', employeeId)
          .eq('status', '지각')
          .gte('date', yearStart.toIso8601String().split('T')[0]);

      _monthlyLateCount = monthlyRecords.length;
      _yearlyLateCount = yearlyRecords.length;

      notifyListeners();
    } catch (e) {
      // 실패해도 앱 동작에는 영향 없도록 에러를 삼킴
      _monthlyLateCount = 0;
      _yearlyLateCount = 0;
      notifyListeners();
    }
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }

  @override
  void dispose() {
    // Dispose all scoped timers and operations
    disposeScopedTimers();
    disposeScopedOperations();
    super.dispose();
  }
}
