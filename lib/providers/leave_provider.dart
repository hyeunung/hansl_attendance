import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/leave_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/cache_service.dart';
import '../services/request_utils.dart';
import '../services/timer_manager.dart';
import '../services/async_operation_manager.dart';
import '../constants/app_strings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveProvider extends ChangeNotifier with TimerManagementMixin, AsyncOperationMixin {
  final LeaveService _service = LeaveService();
  final CacheService _cache = CacheService.instance;
  final RequestUtils _requestUtils = RequestUtils.instance;
  
  List<Map<String, dynamic>> myLeaves = [];
  List<Map<String, dynamic>> todayLeaves = [];
  List<Map<String, dynamic>> allLeaves = [];
  bool isLoading = false;
  String? error;
  
  // Cache keys for different data types
  static const String _myLeavesCacheKey = 'my_leaves_';
  static const String _todayLeavesCacheKey = 'today_leaves_';
  static const String _allLeavesCacheKey = 'all_leaves';
  static const String _employeeCacheKey = 'employee_';
  static const String _annualLeaveCacheKey = 'annual_leave_';

  double _remainAnnual = 0;
  double get remainAnnual => _remainAnnual;

  double _currentGrantedAnnual = 0;
  double get currentGrantedAnnual => _currentGrantedAnnual;

  double _usedAnnual = 0;
  double get usedAnnual => _usedAnnual;
  
  // 배치 업데이트 지원
  bool _shouldNotify = true;

  // 대기 중 신청 개수
  int get pendingCount => myLeaves.where((l) => l['status'] == 'pending').length;

  // 출장 일수(approved만)
  int get biztripDays {
    int days = 0;
    for (final l in myLeaves) {
      if (l['status'] == 'approved' && l['type'] == 'biztrip') {
        days += (DateTime.parse(l['end_date']).difference(DateTime.parse(l['start_date'])).inDays) + 1;
      }
    }
    return days;
  }

  // 최근 신청(최신순 5개)
  List<Map<String, dynamic>> get recentLeaves {
    final sorted = [...myLeaves];
    sorted.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
    return sorted.take(5).toList();
  }

  Map<String, dynamic>? _employee;
  Map<String, dynamic>? get employee => _employee;

  void setEmployee(Map<String, dynamic>? employee) {
    if (_employee != employee) {
      _employee = employee;
      _debouncedNotify();
    }
  }

  Future<void> fetchMyLeaves({required String email, bool forceRefresh = false}) async {
    _updateLoadingState(true, null);
    
    try {
      final cacheKey = '$_myLeavesCacheKey$email';
      
      // Use cache with fallback to API
      final newLeaves = await _cache.getOrFetch<List<Map<String, dynamic>>>(
        key: cacheKey,
        fallback: () => _requestUtils.dedupedRequest(
          key: 'fetch_my_leaves_$email',
          request: () => _service.fetchMyLeavesRaw(email),
        ),
        ttl: CacheConfig.leaveDataTtl,
        usePersistentCache: true,
        useMemoryCache: true,
        fromJson: (json) => List<Map<String, dynamic>>.from(json['leaves']),
        toJson: (data) => {'leaves': data, 'timestamp': DateTime.now().toIso8601String()},
      );
      
      // Load annual leave data with caching
      await _loadAnnualLeaveFromDB(email, forceRefresh: forceRefresh);
      
      // Update UI only if data actually changed
      if (newLeaves != null && !_isLeavesEqual(myLeaves, newLeaves)) {
        _batchUpdate(() {
          myLeaves = newLeaves;
          isLoading = false;
        });
        
        if (kDebugMode) print('✅ My leaves updated from ${forceRefresh ? 'API' : 'cache'}: ${newLeaves.length} items');
      } else {
        _updateLoadingState(false, null);
      }
      
      // Force refresh if requested
      if (forceRefresh) {
        await _cache.invalidate(cacheKey);
      }
      
    } catch (e) {
      _updateLoadingState(false, e.toString());
      if (kDebugMode) print('❌ Failed to fetch my leaves: $e');
    }
  }

  Future<void> fetchTodayLeaves(DateTime today, {bool forceRefresh = false}) async {
    _updateLoadingState(true, null);
    
    try {
      final dateStr = today.toIso8601String().substring(0, 10);
      final cacheKey = '$_todayLeavesCacheKey$dateStr';
      
      // Use shorter TTL for today's data as it changes more frequently
      final newTodayLeaves = await _cache.getOrFetch<List<Map<String, dynamic>>>(
        key: cacheKey,
        fallback: () => _requestUtils.dedupedRequest(
          key: 'fetch_today_leaves_$dateStr',
          request: () => _service.fetchTodayLeavesRaw(today),
        ),
        ttl: const Duration(minutes: 5), // Shorter TTL for today's data
        usePersistentCache: true,
        useMemoryCache: true,
        fromJson: (json) => List<Map<String, dynamic>>.from(json['leaves']),
        toJson: (data) => {'leaves': data, 'timestamp': DateTime.now().toIso8601String()},
      );
      
      if (newTodayLeaves != null && !_isLeavesEqual(todayLeaves, newTodayLeaves)) {
        _batchUpdate(() {
          todayLeaves = newTodayLeaves;
          isLoading = false;
        });
        
        if (kDebugMode) print('✅ Today leaves updated: ${newTodayLeaves.length} items');
      } else {
        _updateLoadingState(false, null);
      }
      
      if (forceRefresh) {
        await _cache.invalidate(cacheKey);
      }
      
    } catch (e) {
      _updateLoadingState(false, e.toString());
      if (kDebugMode) print('❌ Failed to fetch today leaves: $e');
    }
  }

  Future<void> fetchAllLeaves({bool forceRefresh = false}) async {
    _updateLoadingState(true, null);
    
    try {
      final newAllLeaves = await _cache.getOrFetch<List<Map<String, dynamic>>>(
        key: _allLeavesCacheKey,
        fallback: () => _requestUtils.dedupedRequest(
          key: 'fetch_all_leaves',
          request: () => _service.fetchAllLeavesRaw(),
        ),
        ttl: CacheConfig.leaveDataTtl,
        usePersistentCache: true,
        useMemoryCache: true,
        fromJson: (json) => List<Map<String, dynamic>>.from(json['leaves']),
        toJson: (data) => {'leaves': data, 'timestamp': DateTime.now().toIso8601String()},
      );
      
      if (newAllLeaves != null && !_isLeavesEqual(allLeaves, newAllLeaves)) {
        _batchUpdate(() {
          allLeaves = newAllLeaves;
          isLoading = false;
        });
        
        if (kDebugMode) print('✅ All leaves updated: ${newAllLeaves.length} items');
      } else {
        _updateLoadingState(false, null);
      }
      
      if (forceRefresh) {
        await _cache.invalidate(_allLeavesCacheKey);
      }
      
    } catch (e) {
      _updateLoadingState(false, e.toString());
      if (kDebugMode) print('❌ Failed to fetch all leaves: $e');
    }
  }

  // ❌ 삭제됨: _calculateAndUpdateAnnualLeave 함수 
  // 이유: 사용되지 않는 중복 함수
  // 연차 계산은 백엔드 update_used_annual_leave 함수에서 전담

  // 서버에서 사용연차 업데이트 (새로운 Edge Function 호출)
  Future<void> _updateUsedAnnualLeave(String userEmail) async {
    try {
      const projectId = 'qvhbigvdfyvhoegkhvef';
      final functionUrl = 'https://$projectId.supabase.co/functions/v1/update_used_annual_leave';
      
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'userEmail': userEmail,
          'targetYear': DateTime.now().year,
        }),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          if (kDebugMode) { print('✅ 서버 사용연차 업데이트 완료: ${responseData['message']}'); }
        } else {
          if (kDebugMode) { print('❌ 서버 사용연차 업데이트 실패: ${responseData['error']}'); }
        }
      } else {
        if (kDebugMode) { print('❌ 사용연차 업데이트 Edge Function 호출 실패: ${response.statusCode} - ${response.body}'); }
      }
    } catch (e) {
      if (kDebugMode) { print('❌ 사용연차 업데이트 중 오류: $e'); }
      // 사용연차 업데이트 실패는 전체 프로세스를 중단시키지 않음
    }
  }

  // DB에서 계산된 연차 정보 로드 (캐시 적용)
  Future<void> _loadAnnualLeaveFromDB(String userEmail, {bool forceRefresh = false}) async {
    try {
      final cacheKey = '$_annualLeaveCacheKey$userEmail';
      
      final employee = await _cache.getOrFetch<Map<String, dynamic>>(
        key: cacheKey,
        fallback: () async {
          final supabaseService = SupabaseService();
          final result = await supabaseService.getEmployeeByEmail(userEmail);
          if (result == null) throw Exception('Employee not found');
          return result;
        },
        ttl: CacheConfig.employeeDataTtl,
        usePersistentCache: true,
        useMemoryCache: true,
        fromJson: (json) => Map<String, dynamic>.from(json),
        toJson: (data) => Map<String, dynamic>.from(data),
      );
      
      if (employee != null) {
        final newGrantedAnnual = (employee['annual_leave_granted_current_year'] ?? 0).toDouble();
        final newUsedAnnual = double.tryParse(employee['used_annual_leave']?.toString() ?? '0') ?? 0.0;
        final newRemainAnnual = double.tryParse(employee['remaining_annual_leave']?.toString() ?? '0') ?? 0.0;
        
        // Only update if values changed
        if (_currentGrantedAnnual != newGrantedAnnual || 
            _usedAnnual != newUsedAnnual || 
            _remainAnnual != newRemainAnnual) {
          _currentGrantedAnnual = newGrantedAnnual;
          _usedAnnual = newUsedAnnual;
          _remainAnnual = newRemainAnnual;
          
          if (kDebugMode) {
            print('📊 연차 정보 업데이트: 지급=$_currentGrantedAnnual, 사용=$_usedAnnual, 잔여=$_remainAnnual');
          }
        }
      }
      
      if (forceRefresh) {
        await _cache.invalidate(cacheKey);
      }
      
    } catch (e) {
      if (kDebugMode) { print('❌ DB 연차 정보 로드 실패: $e'); }
      // 기본값 유지
      _currentGrantedAnnual = 0;
      _usedAnnual = 0;
      _remainAnnual = 0;
    }
  }

  // 특정 연도 지급연차 조회 (DB에서)
  double getGrantedAnnualForYear(int year) {
    // 현재는 현재 연도만 지원, 향후 확장 가능
    if (year == DateTime.now().year) {
      return _currentGrantedAnnual;
    }
    return 0.0;
  }

  // 연차/출장 신청
  Future<void> requestLeave({
    required String userEmail,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    _updateLoadingState(true, null);
    try {
      // employees DB에서 name과 department 조회
      final supabaseService = SupabaseService();
      final employee = await supabaseService.getEmployeeByEmail(userEmail);
      final name = employee?['name'] ?? '';
      final department = employee?['department'] ?? '';
      
      // DB에 연차/출장 신청 저장
      await _service.insertLeave({
        'user_email': userEmail,
        'name': name,
        'type': type,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // 푸시 알림 전송 (Manager/일반직원 구분)
      try {
        final typeLabel = _getTypeLabel(type);
        final period = _formatPeriod(startDate, endDate);
        
        // 신청자 구분: Manager / Admin / 일반직원
        final isManager = AppStrings.managerNames.contains(name);
        final isAdmin = userEmail == AppStrings.adminEmail;
        
        if (isAdmin) {
          // Admin 신청 → 아무에게도 알림 안함 (혼자 처리)
          if (kDebugMode) { print('👑 Admin 신청이므로 알림 전송 생략: $name님의 $typeLabel 신청'); }
        } else if (isManager) {
          // Manager 신청 → Admin에게만 알림
          await NotificationService.sendNotificationToAdmins(
            title: '👑 Manager $typeLabel 신청',
            body: '$name 매니저님이 $typeLabel을 신청했습니다.\n기간: $period',
            data: {
              'type': type == 'biztrip' ? 'business_trip' : 'leave_request',
              'requester_email': userEmail,
              'requester_name': name,
              'start_date': startDate.toIso8601String().substring(0, 10),
              'end_date': endDate.toIso8601String().substring(0, 10),
              'leave_type': type,
              'requester_is_manager': 'true',
            },
            requesterDepartment: department,
            requesterEmail: userEmail,
            isManagerRequest: true, // Manager 신청임을 명시
          );
          if (kDebugMode) { print('✅ Admin 알림 전송 완료: $name 매니저님의 $typeLabel 신청'); }
        } else {
          // 일반직원 신청 → 해당 부서 Manager + Admin 둘 다 알림
          await NotificationService.sendNotificationToAdmins(
            title: '📝 새로운 $typeLabel 신청',
            body: '$name님이 $typeLabel을 신청했습니다.\n기간: $period',
            data: {
              'type': type == 'biztrip' ? 'business_trip' : 'leave_request',
              'requester_email': userEmail,
              'requester_name': name,
              'start_date': startDate.toIso8601String().substring(0, 10),
              'end_date': endDate.toIso8601String().substring(0, 10),
              'leave_type': type,
              'requester_is_manager': 'false',
            },
            requesterDepartment: department,
            requesterEmail: userEmail,
            isManagerRequest: false, // 일반직원 신청임을 명시
          );
          if (kDebugMode) { print('✅ 부서 관리자 + Admin 알림 전송 완료: $name님의 $typeLabel 신청'); }
        }
      } catch (notificationError) {
        if (kDebugMode) { print('⚠️ 알림 전송 실패: $notificationError'); }
        // 알림 실패는 전체 프로세스를 중단시키지 않음
      }
      
      // 사용연차 업데이트 후 다시 로드 및 캐시 무효화
      await _updateUsedAnnualLeave(userEmail);
      await _invalidateUserRelatedCaches(userEmail);
      await fetchMyLeaves(email: userEmail, forceRefresh: true);
    } catch (e) {
      _updateLoadingState(false, e.toString());
    }
  }

  // 휴가 타입 라벨 변환 헬퍼 메서드
  String _getTypeLabel(String type) {
    switch (type) {
      case 'annual':
        return '연차';
      case 'half_am':
        return '오전반차';
      case 'half_pm':
        return '오후반차';
      case 'official':
        return '공가';
      case 'biztrip':
        return '출장';
      default:
        return '휴가';
    }
  }

  // 기간 포맷팅 헬퍼 메서드
  String _formatPeriod(DateTime startDate, DateTime endDate) {
    if (startDate.year == endDate.year && startDate.month == endDate.month && startDate.day == endDate.day) {
      return '${startDate.month}월 ${startDate.day}일';
    } else {
      return '${startDate.month}월 ${startDate.day}일 ~ ${endDate.month}월 ${endDate.day}일';
    }
  }

  Future<void> updateLeaveStatus(int id, String status) async {
    try {
      // 1. 승인/반려하기 전에 해당 신청 정보 조회
      final leaveDetails = allLeaves.firstWhere(
        (leave) => leave['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      
      if (leaveDetails.isEmpty) {
        if (kDebugMode) { print('❌ 신청 정보를 찾을 수 없습니다: ID $id'); }
        return;
      }
      
      final requesterEmail = leaveDetails['user_email'] as String?;
      final requesterName = leaveDetails['name'] as String? ?? '사용자';
      final leaveType = leaveDetails['type'] as String? ?? '';
      final startDate = leaveDetails['start_date'] as String? ?? '';
      final endDate = leaveDetails['end_date'] as String? ?? '';
      
      // 2. 상태 업데이트
      await _service.updateLeaveStatus(id, status);
      
      // 3. 신청자의 사용연차 정보 재계산 (승인/반려 시)
      if (requesterEmail != null && requesterEmail.isNotEmpty) {
        await _updateUsedAnnualLeave(requesterEmail);
      }
      
      // 4. 신청자에게 승인/반려 결과 알림 전송
      if (requesterEmail != null && requesterEmail.isNotEmpty) {
        try {
          final typeLabel = _getTypeLabel(leaveType);
          final statusLabel = status == 'approved' ? '승인' : '반려';
          final statusEmoji = status == 'approved' ? '✅' : '❌';
          
          String period = '';
          if (startDate.isNotEmpty && endDate.isNotEmpty) {
            final start = DateTime.parse(startDate);
            final end = DateTime.parse(endDate);
            period = _formatPeriod(start, end);
          }
          
          await NotificationService.sendNotificationToUser(
            userEmail: requesterEmail,
            title: '$statusEmoji $typeLabel $statusLabel',
            body: '$requesterName님의 $typeLabel 신청이 $statusLabel되었습니다.${period.isNotEmpty ? '\n기간: $period' : ''}',
            data: {
              'type': 'leave_result',
              'leave_id': id.toString(),
              'status': status,
              'leave_type': leaveType,
              'start_date': startDate,
              'end_date': endDate,
            },
          );
          if (kDebugMode) { print('✅ 신청자 알림 전송 완료: $requesterName님에게 $typeLabel $statusLabel 알림'); }
        } catch (notificationError) {
          if (kDebugMode) { print('⚠️ 신청자 알림 전송 실패: $notificationError'); }
          // 알림 실패는 전체 프로세스를 중단시키지 않음
        }
      }
      
      // 5. 목록 새로고침 및 캐시 무효화
      await _invalidateRelatedCaches(requesterEmail);
      await fetchAllLeaves(forceRefresh: true);
    } catch (e) {
      if (kDebugMode) { print('❌ 승인/반려 처리 실패: $e'); }
      rethrow;
    }
  }
  
  // 배치 업데이트 헬퍼 메서드들
  void _batchUpdate(VoidCallback updates) {
    _shouldNotify = false;
    updates();
    _shouldNotify = true;
    _debouncedNotify();
  }
  
  void _updateLoadingState(bool loading, String? errorMsg) {
    if (isLoading != loading || error != errorMsg) {
      _batchUpdate(() {
        isLoading = loading;
        error = errorMsg;
      });
    }
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
  
  @override
  void dispose() {
    // Dispose all scoped timers and operations
    disposeScopedTimers();
    disposeScopedOperations();
    super.dispose();
  }
  
  // 리스트 비교 헬퍼
  bool _isLeavesEqual(List<Map<String, dynamic>> old, List<Map<String, dynamic>> newList) {
    if (old.length != newList.length) return false;
    for (int i = 0; i < old.length; i++) {
      // ID와 상태만 비교 (핵심 데이터)
      if (old[i]['id'] != newList[i]['id'] || old[i]['status'] != newList[i]['status']) {
        return false;
      }
    }
    return true;
  }
  
  // 캐시 무효화 헬퍼 메서드들
  Future<void> _invalidateUserRelatedCaches(String userEmail) async {
    await _cache.invalidate('$_myLeavesCacheKey$userEmail');
    await _cache.invalidate('$_annualLeaveCacheKey$userEmail');
    await _cache.invalidate('$_employeeCacheKey$userEmail');
    if (kDebugMode) print('🗑️ User related caches invalidated for: $userEmail');
  }
  
  Future<void> _invalidateRelatedCaches(String? userEmail) async {
    // Invalidate all leaves cache
    await _cache.invalidate(_allLeavesCacheKey);
    
    // Invalidate today's leaves cache for current date
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _cache.invalidate('$_todayLeavesCacheKey$today');
    
    // If user email provided, invalidate user-specific caches
    if (userEmail != null && userEmail.isNotEmpty) {
      await _invalidateUserRelatedCaches(userEmail);
    }
    
    if (kDebugMode) print('🗑️ Related leave caches invalidated');
  }
  
  /// Force refresh all data by clearing cache and reloading
  Future<void> forceRefreshAll({String? userEmail}) async {
    await _cache.clearAll();
    
    if (userEmail != null) {
      await fetchMyLeaves(email: userEmail, forceRefresh: true);
    }
    await fetchAllLeaves(forceRefresh: true);
    await fetchTodayLeaves(DateTime.now(), forceRefresh: true);
    
    if (kDebugMode) print('🔄 Force refreshed all leave data');
  }
  
  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }
} 