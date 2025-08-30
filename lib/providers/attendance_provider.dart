import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
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

  // Edge Functions endpoints
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
  
  // 지각 통계 추가
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
        await fetchLateStatistics(); // 지각 통계 로드 추가
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

    if (kDebugMode) {
      debugPrint('🔄 Initializing today: $todayStr');
      debugPrint('🔄 User ID: $userId');
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

      if (kDebugMode) {
        debugPrint('📊 DB Record found: ${record != null}');
        if (record != null) {
          debugPrint('📊 Clock in: ${record['clock_in']}');
          debugPrint('📊 Clock out: ${record['clock_out']}');
          debugPrint('📊 Status: ${record['status']}');
        }
      }

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
          if (kDebugMode) print('✅ Status: 퇴근 완료');
        } else {
          // 출근만 있고 퇴근은 없음
          status = isLate ? AttendanceStatus.late : AttendanceStatus.working;
          if (kDebugMode) print('✅ Status: 근무 중');
        }
        canClockIn = false;
      } else {
        // DB에 오늘 기록이 전혀 없음 - 완전 초기화
        if (kDebugMode) {
          debugPrint('✅ No record for today - resetting to initial state');
        }
        status = AttendanceStatus.beforeWork;
        clockInTime = null;
        clockOutTime = null;
        isLate = false;
        canClockIn = true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading today data: $e');
      }
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
    if (kDebugMode) {
      debugPrint(
        'Validating location: lat=$latitude, lng=$longitude, userId=$userId',
      );
    }

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

      if (kDebugMode) {
        debugPrint('Location validation response status: ${response.status}');
        debugPrint('Location validation response data: ${response.data}');
      }

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
      if (kDebugMode) print('Location validation error details: $e');
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
        Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high),
        Future.delayed(
          const Duration(seconds: 10),
          () => throw async_ops.TimeoutException(
            'GPS timeout',
            const Duration(seconds: 10),
          ),
        ),
      ]);
      token.throwIfCancelled();

      // DEBUG: 시뮬레이터에서 테스트를 위해 회사 위치 사용
      if (kDebugMode) {
        debugPrint('Original position: lat=${pos.latitude}, lng=${pos.longitude}');
        // 시뮬레이터에서는 회사 위치로 override
        pos = Position(
          latitude: 35.844541, // 회사 위도
          longitude: 128.506439, // 회사 경도
          timestamp: DateTime.now(),
          accuracy: pos.accuracy,
          altitude: pos.altitude,
          altitudeAccuracy: pos.altitudeAccuracy,
          heading: pos.heading,
          headingAccuracy: pos.headingAccuracy,
          speed: pos.speed,
          speedAccuracy: pos.speedAccuracy,
        );
        debugPrint('DEBUG: Using company location for testing');
      }
    } catch (e) {
      _updateErrorAndLoading('위치 정보를 가져오는데 실패했습니다.', false);
      return;
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
      } catch (e, stackTrace) {
        // 에러 로깅
        if (kDebugMode) {
          debugPrint('🚨 Edge Function 오류: $e');
          debugPrint('Stack trace: $stackTrace');
        }

        // Edge Function 오류 시 클라이언트 사이드 검증으로 폴백
        final distance = _calculateDistance(
          pos.latitude,
          pos.longitude,
          _companyLat,
          _companyLng,
        );

        if (kDebugMode) {
          debugPrint('📍 Fallback to client validation');
          debugPrint(
            '📍 Distance: ${distance.round()}m (max: ${_allowedDistance}m)',
          );
        }

        if (distance > _allowedDistance) {
          _updateErrorAndLoading('출근 가능한 장소가 아닙니다.', false);
          return;
        }

        // 위치는 맞지만 서버 연결 문제가 있을 때
        // 사용자에게 알리지만 출근은 허용
        debugPrint('📍 위치 검증 서버 연결 실패 - 클라이언트 검증으로 처리');

        // 사용자에게 서버 연결 문제를 알림 (위치는 확인됨)
        // 이 메시지는 출근은 되지만 서버 연결이 불안정함을 알려줌
        // 나중에 제거하거나 수정 필요
      }
    } else {
      debugPrint('DEBUG: Skipping location validation');
    }

    token.throwIfCancelled();

    // 서버사이드 시간 검증
    Map<String, dynamic> timeResult = {'isValid': true, 'isLate': false};
    if (!kDebugMode) {
      try {
        timeResult = await _validateWorkTimeWithServer('clockIn', token);

        if (!timeResult['isValid']) {
          debugPrint('⚠️ Server time validation failed: ${timeResult['message']}');
          // 서버 검증 실패 시 클라이언트에서 지각 여부만 판단하고 계속 진행
          final now = DateTime.now();
          final hour = now.hour;
          final minute = now.minute;
          isLate = hour >= 9 || (hour == 8 && minute > 30);
          debugPrint('🕔 Using client time: $hour:$minute, isLate: $isLate');
          // return 제거 - 출근은 계속 진행
        } else {
          isLate = timeResult['isLate'] ?? false;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Time validation error (출근): $e');
        }
        // 시간 검증 실패해도 출근은 허용 (시간만 클라이언트에서 체크)
        final now = DateTime.now();
        final hour = now.hour;
        final minute = now.minute;
        isLate = hour >= 9 || (hour == 8 && minute > 30);
      }
    } else {
      if (kDebugMode) {
        debugPrint('DEBUG: Skipping time validation in debug mode');
      }
      // 8시 30분 이후면 지각으로 설정
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;
      isLate = hour >= 9 || (hour == 8 && minute > 30);
    }

    var now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    debugPrint('💾 ========== CLOCK IN DB SAVE START ==========');
    debugPrint('💾 Date: $todayStr');
    debugPrint('💾 User ID: $userId');
    debugPrint('💾 User Name: $userName');
    debugPrint('💾 Is Late: $isLate');
    debugPrint('💾 Time: ${now.toIso8601String()}');

    try {
      token.throwIfCancelled();

      debugPrint('🔍 Checking existing attendance record...');

      // Supabase client를 직접 사용하여 오늘 기록 조회
      final existingRecords = await Supabase.instance.client
          .from('attendance_records')
          .select()
          .eq('employee_id', userId)
          .eq('date', todayStr)
          .limit(1);

      debugPrint('🔍 Query completed. Records found: ${existingRecords.length}');
      if (existingRecords.isNotEmpty) {
        debugPrint('🔍 Existing record: ${existingRecords.first}');
      }

      final record = existingRecords.isNotEmpty ? existingRecords.first : null;
      token.throwIfCancelled();

      if (record != null) {
        // 기존 레코드가 있으면 UPDATE
        debugPrint('📝 Found existing record ID: ${record['id']}');

        final updateData = {
          'clock_in': now.toIso8601String().substring(11, 19),
          'status': isLate ? '지각' : '정상 출근',
          'updated_at': now.toIso8601String(),
        };
        debugPrint('📝 Updating with data: $updateData');

        final updateResult = await Supabase.instance.client
            .from('attendance_records')
            .update(updateData)
            .eq('id', record['id'])
            .select();

        debugPrint('✅ Update result: $updateResult');

        if (kDebugMode) {
          debugPrint('✅ Updated existing attendance record for $todayStr');
          debugPrint('✅ Clock in time: ${now.toIso8601String().substring(11, 19)}');
        }
      } else {
        // 기존 레코드가 없으면 INSERT (새로 생성)
        debugPrint('📝 No existing record found, creating new record');

        final insertData = {
          'date': todayStr,
          'employee_id': userId,
          'employee_name': userName,
          'clock_in': now.toIso8601String().substring(11, 19),
          'status': isLate ? '지각' : '정상 출근',
          'created_at': now.toIso8601String(),
        };

        debugPrint('📝 Insert data: $insertData');

        final insertResult = await Supabase.instance.client
            .from('attendance_records')
            .insert(insertData)
            .select();

        debugPrint('✅ Insert result: $insertResult');
      }

      debugPrint('💾 ========== CLOCK IN DB SAVE SUCCESS ==========');
    } catch (e, stackTrace) {
      debugPrint('❌ ========== DB ERROR ==========');
      debugPrint('❌ Database error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('❌ ==============================');

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
      this.isLate = isLate;
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

    if (kDebugMode) print('✅ Clock in successful at ${now.toString()}');

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
        Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high),
        Future.delayed(
          const Duration(seconds: 10),
          () => throw async_ops.TimeoutException(
            'GPS timeout',
            const Duration(seconds: 10),
          ),
        ),
      ]);
      token.throwIfCancelled();

      // DEBUG: 시뮬레이터에서 테스트를 위해 회사 위치 사용 (퇴근도 동일)
      if (kDebugMode) {
        debugPrint(
          'Original position (clock out): lat=${pos.latitude}, lng=${pos.longitude}',
        );
        // 시뮬레이터에서는 회사 위치로 override
        pos = Position(
          latitude: 35.844541, // 회사 위도
          longitude: 128.506439, // 회사 경도
          timestamp: DateTime.now(),
          accuracy: pos.accuracy,
          altitude: pos.altitude,
          altitudeAccuracy: pos.altitudeAccuracy,
          heading: pos.heading,
          headingAccuracy: pos.headingAccuracy,
          speed: pos.speed,
          speedAccuracy: pos.speedAccuracy,
        );
        debugPrint('DEBUG: Using company location for testing (clock out)');
      }
    } catch (e) {
      _updateErrorAndLoading('위치 정보를 가져오는데 실패했습니다.', false);
      return;
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
      } catch (e, stackTrace) {
        // 에러 로깅
        if (kDebugMode) {
          debugPrint('🚨 Edge Function error (clock out): $e');
          debugPrint('Stack trace: $stackTrace');
        }

        // Edge Function 오류 시 클라이언트 사이드 검증으로 폴백
        final distance = _calculateDistance(
          pos.latitude,
          pos.longitude,
          _companyLat,
          _companyLng,
        );

        if (kDebugMode) {
          debugPrint('📍 Fallback to client validation (clock out)');
          debugPrint(
            '📍 Distance: ${distance.round()}m (max: ${_allowedDistance}m)',
          );
        }

        if (distance > _allowedDistance) {
          _updateErrorAndLoading('퇴근 가능한 장소가 아닙니다.', false);
          return;
        }

        // 위치는 맞지만 서버 연결 문제가 있을 때
        debugPrint('📍 퇴근 위치 검증 서버 연결 실패 - 클라이언트 검증으로 처리');

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
        if (kDebugMode) {
          debugPrint('Clock out time validation error: $e');
          debugPrint('Time validation error (퇴근): $e');
        }
        // 시간 검증 실패해도 퇴근은 허용 - 계속 진행
      }
    } else {
      if (kDebugMode) {
        debugPrint('DEBUG: Skipping time validation for clock out in debug mode');
      }
    }

    var now = DateTime.now();

    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      token.throwIfCancelled();

      if (kDebugMode) {
        debugPrint(
          '📝 Checking existing attendance record for clock out: $todayStr',
        );
        debugPrint('📝 Employee ID: $userId');
      }

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
        if (kDebugMode) {
          debugPrint('📝 Found existing record ID for clock out: ${record['id']}');
        }

        await Supabase.instance.client
            .from('attendance_records')
            .update({
              'clock_out': now.toIso8601String().substring(11, 19),
              'status': '퇴근',
              'updated_at': now.toIso8601String(),
            })
            .eq('id', record['id']);

        if (kDebugMode) {
          debugPrint('✅ Updated attendance record with clock out for $todayStr');
          debugPrint('✅ Clock out time: ${now.toIso8601String().substring(11, 19)}');
        }
      } else {
        // 출근 기록 없이 퇴근하는 경우 (예외적 상황)
        if (kDebugMode) {
          debugPrint(
            '⚠️ No existing record found for clock out, creating new record',
          );
        }

        final insertData = {
          'date': todayStr,
          'employee_id': userId,
          'employee_name': userName,
          'clock_out': now.toIso8601String().substring(11, 19),
          'status': '퇴근',
          'created_at': now.toIso8601String(),
        };

        if (kDebugMode) {
          debugPrint('📝 Insert data for clock out: $insertData');
        }

        await Supabase.instance.client
            .from('attendance_records')
            .insert(insertData);

        if (kDebugMode) {
          debugPrint(
            '⚠️ Created new attendance record with only clock out for $todayStr',
          );
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Database error on clock out: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        debugPrint('❌ User ID: $userId');
        debugPrint('❌ Date: $todayStr');
      }

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

    if (kDebugMode) print('✅ Clock out successful at ${now.toString()}');
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
          if (kDebugMode) print('❌ Midnight reset failed: $e');
          return false;
        });

        // Schedule next midnight reset
        _scheduleMidnightReset();
      },
    );

    if (kDebugMode) {
      debugPrint(
        '⏰ Midnight reset scheduled in ${duration.inHours}h ${duration.inMinutes % 60}m',
      );
    }
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
          if (kDebugMode) print('❌ Auto clock-out failed: $e');
        });

        // Schedule next auto clock-out
        _scheduleAutoClockOut();
      },
    );

    if (kDebugMode) {
      debugPrint(
        '⏰ Auto clock-out scheduled in ${duration.inHours}h ${duration.inMinutes % 60}m',
      );
    }
  }

  void _performMaintenance() {
    // Clean up expired cache entries
    _cache.getStats();

    // Log timer statistics in debug mode
    if (kDebugMode) {
      final timerStats = TimerManager.instance.getStats();
      final asyncStats = async_ops.AsyncOperationManager.instance.getStats();
      debugPrint(
        '🧹 Maintenance - Timers: ${timerStats.activeTimers}, Operations: ${asyncStats.activeOperations}',
      );
    }
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

        if (kDebugMode) {
          debugPrint('✅ Auto clock-out saved to DB at 18:00 for $todayStr');
        }

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
        if (kDebugMode) {
          debugPrint('❌ Auto clock-out DB update failed: $e');
        }
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
        if (kDebugMode) {
          debugPrint(
            '🔍 Found ${missingClockOuts.length} missing clock-outs for $yesterdayStr',
          );
        }

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

          if (kDebugMode) {
            debugPrint(
              '✅ Auto clock-out applied for ${record['employee_name']} on $yesterdayStr',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error processing yesterday missing clock-outs: $e');
      }
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

    if (kDebugMode)
      debugPrint('🗑️ Attendance caches invalidated for user: $userId');
  }

  /// Force refresh all attendance data
  Future<void> forceRefreshAll() async {
    if (kDebugMode) print('🔄 Force refreshing all attendance data...');

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

    if (kDebugMode) print('🔄 Force refresh completed');
  }

  /// 지각 통계 로드
  Future<void> fetchLateStatistics() async {
    print('🔵 fetchLateStatistics called');
    try {
      final now = DateTime.now();
      final year = now.year;
      final month = now.month;
      
      // 이번 달 시작일과 종료일
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);
      
      // 올해 시작일
      final yearStart = DateTime(year, 1, 1);
      
      // 이번 달 지각 카운트
      final monthlyRecords = await Supabase.instance.client
          .from('attendance_records')
          .select('status')
          .eq('employee_id', userId)
          .eq('status', '지각')
          .gte('date', monthStart.toIso8601String().split('T')[0])
          .lte('date', monthEnd.toIso8601String().split('T')[0]);
      
      // 올해 지각 카운트  
      final yearlyRecords = await Supabase.instance.client
          .from('attendance_records')
          .select('status')
          .eq('employee_id', userId)
          .eq('status', '지각')
          .gte('date', yearStart.toIso8601String().split('T')[0]);
      
      _monthlyLateCount = monthlyRecords.length;
      _yearlyLateCount = yearlyRecords.length;
      
      if (kDebugMode) {
        debugPrint('📊 Late Statistics - Monthly: $_monthlyLateCount, Yearly: $_yearlyLateCount');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to fetch late statistics: $e');
      }
      // 실패해도 앱 동작에는 영향 없도록 에러를 삼킴
      _monthlyLateCount = 0;
      _yearlyLateCount = 0;
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
