import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance.dart';
import '../services/timer_manager.dart';
import '../services/async_operation_manager.dart';
import '../services/cache_service.dart';
import '../services/database_optimization_service.dart';

enum AttendanceStatus { beforeWork, working, late, offWork }

class AttendanceProvider extends ChangeNotifier with TimerManagementMixin, AsyncOperationMixin {
  final String userId;
  final String userName;
  
  // 회사 위치 정보 (임시: 클라이언트 사이드 검증)
  static const double _companyLat = 35.844541;
  static const double _companyLng = 128.506440;
  static const double _allowedDistance = 100.0;  // meters

  AttendanceStatus status = AttendanceStatus.beforeWork;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  bool isLate = false;
  String? errorMessage;
  List<AttendanceRecord> history = [];


  bool isLoading = true;
  
  // Cache service for performance optimization
  final CacheService _cache = CacheService.instance;
  final DatabaseOptimizationService _dbOptim = DatabaseOptimizationService.instance;
  
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
  bool get canClockOut => status == AttendanceStatus.working || status == AttendanceStatus.late;

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
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    // 최적화된 데이터베이스 서비스를 사용하여 오늘 출근 기록 조회
    final records = await _dbOptim.getAttendanceRecords(
      userId,
      date: now,
      limit: 1,
      cacheTtl: CacheConfig.attendanceTodayTtl,
    );
    
    final record = records.isNotEmpty ? records.first : null;

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
    
    _updateLoadingState(false);
  }

  Future<void> fetchRecentHistory() async {
    return await executeScopedOperation(
      key: 'fetch_history',
      operation: (token) async {
        token.throwIfCancelled();
        
        // 최적화된 데이터베이스 서비스를 사용하여 최근 이력 조회
        final records = await _dbOptim.getAttendanceRecords(
          userId,
          limit: 5,
          includeHistory: true,
          cacheTtl: CacheConfig.attendanceHistoryTtl,
          cancellationToken: token,
        );
        
        token.throwIfCancelled();
        
        if (records.isNotEmpty) {
          _processHistoryRecords(records);
        }
        
        return true;
      },
      timeout: const Duration(seconds: 30),
      cancelPrevious: true,
      description: 'Fetch attendance history',
    );
  }
  
  void _processHistoryRecords(List<Map<String, dynamic>> records) {
    final newHistory = records.map<AttendanceRecord>((r) {
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
    
    // 히스토리가 실제로 변경된 경우에만 알림
    if (!_isHistoryEqual(history, newHistory)) {
      _batchUpdate(() {
        history = newHistory;
      });
    }
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
    
    // Use async operation manager with cancellation support
    return await executeScopedOperation(
      key: 'clock_in',
      operation: (token) => _performClockIn(token),
      timeout: const Duration(seconds: 30),
      cancelPrevious: true,
      description: 'Clock in operation',
    );
  }
  
  Future<void> _performClockIn(CancellationToken token) async {
    _updateLoadingState(true);
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
        Future.delayed(const Duration(seconds: 10), () => throw TimeoutException('GPS timeout', const Duration(seconds: 10))),
      ]);
      token.throwIfCancelled();
    } catch (e) {
      _updateErrorAndLoading('위치 정보를 가져오는데 실패했습니다.', false);
      return;
    }
    
    // 클라이언트 사이드 위치 검증 (임시)
    if (!_validateLocation(pos.latitude, pos.longitude)) {
      final distance = _calculateDistance(pos.latitude, pos.longitude, _companyLat, _companyLng);
      _updateErrorAndLoading('회사에서 ${distance.round()}m 떨어져 있습니다. 허용 범위: ${_allowedDistance.round()}m', false);
      return;
    }
    
    token.throwIfCancelled();
    
    // 클라이언트 사이드 시간 검증 (임시)
    if (!_validateWorkTime()) {
      _updateErrorAndLoading('출근 가능한 시간이 아닙니다. (00:00 ~ 18:00)', false);
      return;
    }
    
    // 지각 여부 판정
    var now = DateTime.now();
    isLate = _isLateClockIn();
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    try {
      token.throwIfCancelled();
      
      // 최적화된 데이터베이스 서비스를 사용하여 오늘 기록 조회
      final existingRecords = await _dbOptim.getAttendanceRecords(
        userId,
        date: now,
        limit: 1,
        cancellationToken: token,
      );
      
      final record = existingRecords.isNotEmpty ? existingRecords.first : null;
      token.throwIfCancelled();
      
      if (record != null) {
        // 기존 레코드가 있으면 UPDATE
        await _dbOptim.optimizedUpdate(
          table: 'attendance_records',
          data: {
            'clock_in': now.toIso8601String().substring(11, 19),
            'status': isLate ? '지각' : '정상 출근',
          },
          match: {'id': record['id']},
          invalidateCachePatterns: [
            'attendance_${userId}_$todayStr',
            'attendance_${userId}_',
          ],
          cancellationToken: token,
        );
      } else {
        // 기존 레코드가 없으면 INSERT (새로 생성)
        await _dbOptim.optimizedInsert(
          table: 'attendance_records',
          data: {
            'date': todayStr,
            'employee_id': userId,
            'employee_name': userName,
            'clock_in': now.toIso8601String().substring(11, 19),
            'status': isLate ? '지각' : '정상 출근',
            'created_at': now.toIso8601String(),
          },
          invalidateCachePatterns: [
            'attendance_${userId}_$todayStr',
            'attendance_${userId}_',
          ],
          cancellationToken: token,
        );
      }
    } catch (e) {
      _updateErrorAndLoading('출근 등록 중 오류가 발생했습니다. 다시 시도해주세요.', false);
      return;
    }
    
    // 모든 상태 변경을 배치로 처리 및 캐시 무효화
    await _invalidateAttendanceCaches();
    
    _batchUpdate(() {
      clockInTime = now;
      status = isLate ? AttendanceStatus.late : AttendanceStatus.working;
      canClockIn = false;
      isLoading = false;
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
  
  Future<void> _performClockOut(CancellationToken token) async {
    _updateLoadingState(true);
    
    token.throwIfCancelled();
    
    // 퇴근 시간 확인 (임시: 클라이언트 사이드)
    var now = DateTime.now();
    
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    try {
      token.throwIfCancelled();
      
      // 최적화된 데이터베이스 서비스를 사용하여 오늘 기록 조회
      final existingRecords = await _dbOptim.getAttendanceRecords(
        userId,
        date: now,
        limit: 1,
        cancellationToken: token,
      );
      
      final record = existingRecords.isNotEmpty ? existingRecords.first : null;
      token.throwIfCancelled();
      
      if (record != null) {
        // 기존 레코드가 있으면 UPDATE
        await _dbOptim.optimizedUpdate(
          table: 'attendance_records',
          data: {
            'clock_out': now.toIso8601String().substring(11, 19),
            'status': '퇴근',
          },
          match: {'id': record['id']},
          invalidateCachePatterns: [
            'attendance_${userId}_$todayStr',
            'attendance_${userId}_',
          ],
          cancellationToken: token,
        );
      } else {
        // 출근 기록 없이 퇴근하는 경우 (예외적 상황)
        await _dbOptim.optimizedInsert(
          table: 'attendance_records',
          data: {
            'date': todayStr,
            'employee_id': userId,
            'employee_name': userName,
            'clock_out': now.toIso8601String().substring(11, 19),
            'status': '퇴근',
            'created_at': now.toIso8601String(),
          },
          invalidateCachePatterns: [
            'attendance_${userId}_$todayStr',
            'attendance_${userId}_',
          ],
          cancellationToken: token,
        );
      }
    } catch (e) {
      _updateErrorAndLoading('퇴근 등록 중 오류가 발생했습니다. 다시 시도해주세요.', false);
      return;
    }
    
    // 모든 상태 변경을 배치로 처리 및 캐시 무효화
    await _invalidateAttendanceCaches();
    
    _batchUpdate(() {
      clockOutTime = now;
      status = AttendanceStatus.offWork;
      isLoading = false;
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
        });
        
        // Schedule next midnight reset
        _scheduleMidnightReset();
      },
    );
    
    if (kDebugMode) {
      print('⏰ Midnight reset scheduled in ${duration.inHours}h ${duration.inMinutes % 60}m');
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
            return true;
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
      print('⏰ Auto clock-out scheduled in ${duration.inHours}h ${duration.inMinutes % 60}m');
    }
  }
  
  void _performMaintenance() {
    // Clean up expired cache entries
    _cache.getStats();
    
    // Log timer statistics in debug mode
    if (kDebugMode) {
      final timerStats = TimerManager.instance.getStats();
      final asyncStats = AsyncOperationManager.instance.getStats();
      print('🧹 Maintenance - Timers: ${timerStats.activeTimers}, Operations: ${asyncStats.activeOperations}');
    }
  }

  void _autoClockOut() {
    if (clockInTime != null && clockOutTime == null) {
      // 퇴근 미처리 시 18:00 자동 퇴근
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final autoOut = DateTime(now.year, now.month, now.day, 18, 0);
      
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
      });
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
  String get clockInStr => clockInTime == null ? '-' : _formatTime(clockInTime!);
  String get clockOutStr => clockOutTime == null ? '-' : _formatTime(clockOutTime!);

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
      delay: const Duration(milliseconds: 100),
      callback: () {
        if (_shouldNotify) {
          notifyListeners();
        }
      },
    );
  }
  
  // 히스토리 비교 헬퍼
  bool _isHistoryEqual(List<AttendanceRecord> old, List<AttendanceRecord> newList) {
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
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    await _cache.invalidate('$_todayAttendanceCacheKey${userId}_$todayStr');
    await _cache.invalidate('$_attendanceHistoryCacheKey$userId');
    
    if (kDebugMode) print('🗑️ Attendance caches invalidated for user: $userId');
  }
  
  /// Force refresh all attendance data
  Future<void> forceRefreshAll() async {
    await _cache.invalidatePattern('attendance_');
    await _initToday();
    await fetchRecentHistory();
    
    if (kDebugMode) print('🔄 Force refreshed all attendance data');
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