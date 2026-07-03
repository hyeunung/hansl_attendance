import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/leave_service.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../services/request_utils.dart';
import '../services/timer_manager.dart';
import '../services/async_operation_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveProvider extends ChangeNotifier
    with TimerManagementMixin, AsyncOperationMixin {
  final LeaveService _service = LeaveService();
  final CacheService _cache = CacheService.instance;
  final RequestUtils _requestUtils = RequestUtils.instance;

  List<Map<String, dynamic>> myLeaves = [];
  List<Map<String, dynamic>> todayLeaves = [];
  List<Map<String, dynamic>> tomorrowLeaves = [];
  List<Map<String, dynamic>> allLeaves = []; // 승인 화면용 - 모든 상태 포함
  List<Map<String, dynamic>> approvedLeavesForCalendar = []; // 달력용 - 승인된 것만
  List<Map<String, dynamic>> _allLeavesRaw = []; // 그룹화 전 원본 데이터
  List<Map<String, dynamic>> holidays = []; // 공휴일 데이터
  bool isLoading = false; // 초기에는 false로 설정
  bool calendarLoading = false; // 달력 전용 로딩 플래그
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
  
  // 연차 데이터 로드 여부 확인 플래그
  bool _annualLeaveLoaded = false;
  bool get annualLeaveLoaded => _annualLeaveLoaded;

  // 배치 업데이트 지원
  bool _shouldNotify = true;

  // 출장 일수 캐시 (동행자 포함)
  int _biztripDays = 0;
  
  // 대기 중 신청 개수 (본인 신청만)
  int get myPendingCount =>
      myLeaves.where((l) => l['status'] == 'pending').length;

  // 전체 승인 대기 중 신청 개수 (관리자용)
  int get allPendingCount =>
      allLeaves.where((l) => l['status'] == 'pending' || l['modification_status'] == 'extension_pending').length;

  // 대기 중 신청 개수 (대시보드용 - 권한에 따라 다르게 표시)
  int get pendingCount {
    // 본인 대기중 항목만 표시 (대시보드는 개인 현황)
    return myPendingCount;
  }

  // 출장 일수(approved만, 동행자 포함)
  int get biztripDays => _biztripDays;

  // 최근 신청(최신순 5개) - 연속된 날짜는 그룹화
  List<Map<String, dynamic>> get recentLeaves {
    final sorted = [...myLeaves];
    sorted.sort(
      (a, b) => DateTime.parse(
        b['created_at'],
      ).compareTo(DateTime.parse(a['created_at'])),
    );

    // 연속된 날짜 그룹화 (연차와 출장 모두)
    final grouped = _groupContinuousLeaves(sorted);
    return grouped.take(5).toList();
  }

  // 연속된 날짜의 연차/출장 신청을 그룹화
  List<Map<String, dynamic>> _groupContinuousLeaves(
    List<Map<String, dynamic>> leaves,
  ) {
    if (leaves.isEmpty) return [];

    final List<Map<String, dynamic>> grouped = [];
    Map<String, dynamic>? currentGroup;

    for (final leave in leaves) {
      final type = leave['type'];
      final status = leave['status'];
      final startDate = DateTime.parse(leave['start_date']);
      final endDate = DateTime.parse(leave['end_date']);

      // 연차(annual)만 그룹화 대상 (출장은 business_trips 테이블에서 이미 시작일~종료일로 저장)
      if (type != 'annual') {
        grouped.add(leave);
        currentGroup = null;
        continue;
      }

      // 현재 그룹과 연속되는지 확인
      if (currentGroup != null &&
          currentGroup['type'] == type &&
          currentGroup['status'] == status) {
        final groupEndDate = DateTime.parse(currentGroup['end_date']);
        final dayDiff = startDate.difference(groupEndDate).inDays;

        // 1일 차이(연속된 날짜)면 그룹 확장
        if (dayDiff.abs() <= 1) {
          // 그룹의 날짜 범위 확장
          final groupStartDate = DateTime.parse(currentGroup['start_date']);
          currentGroup['start_date'] =
              (startDate.isBefore(groupStartDate) ? startDate : groupStartDate)
                  .toIso8601String();
          currentGroup['end_date'] =
              (endDate.isAfter(groupEndDate) ? endDate : groupEndDate)
                  .toIso8601String();

          // 그룹화된 항목 수 증가
          currentGroup['grouped_count'] =
              (currentGroup['grouped_count'] ?? 1) + 1;

          // created_at은 첫 번째 항목의 신청 시각 유지 (신청 순서 보존)
          continue;
        }
      }

      // 새로운 그룹 시작
      currentGroup = Map<String, dynamic>.from(leave);
      currentGroup['grouped_count'] = 1;
      grouped.add(currentGroup);
    }

    return grouped;
  }

  // 승인 화면용 그룹화 (같은 사용자의 같은 타입, 같은 상태만 그룹화)
  List<Map<String, dynamic>> _groupContinuousLeavesForApproval(
    List<Map<String, dynamic>> leaves,
  ) {
    if (leaves.isEmpty) return [];

    final List<Map<String, dynamic>> grouped = [];
    Map<String, dynamic>? currentGroup;

    for (final leave in leaves) {
      final type = leave['type'];
      final status = leave['status'];
      final userEmail = leave['user_email'];
      final startDate = DateTime.parse(leave['start_date']);
      final endDate = DateTime.parse(leave['end_date']);

      // 연차(annual)만 그룹화 대상
      if (type != 'annual') {
        grouped.add(leave);
        currentGroup = null;
        continue;
      }

      // 현재 그룹과 연속되는지 확인 (같은 사용자, 같은 타입, 같은 상태)
      if (currentGroup != null &&
          currentGroup['user_email'] == userEmail &&
          currentGroup['type'] == type &&
          currentGroup['status'] == status) {
        final groupEndDate = DateTime.parse(currentGroup['end_date']);
        final dayDiff = startDate.difference(groupEndDate).inDays;

        // 1일 차이(연속된 날짜)면 그룹 확장
        if (dayDiff.abs() <= 1) {
          // 그룹의 날짜 범위 확장
          final groupStartDate = DateTime.parse(currentGroup['start_date']);
          currentGroup['start_date'] =
              (startDate.isBefore(groupStartDate) ? startDate : groupStartDate)
                  .toIso8601String();
          currentGroup['end_date'] =
              (endDate.isAfter(groupEndDate) ? endDate : groupEndDate)
                  .toIso8601String();

          // 그룹화된 항목 수 증가
          currentGroup['grouped_count'] =
              (currentGroup['grouped_count'] ?? 1) + 1;

          // 그룹화된 ID들 저장 (승인/반려 시 사용)
          if (currentGroup['grouped_ids'] == null) {
            currentGroup['grouped_ids'] = [currentGroup['id']];
          }
          currentGroup['grouped_ids'].add(leave['id']);

          // created_at은 첫 번째 항목의 신청 시각 유지 (신청 순서 보존)
          continue;
        }
      }

      // 새로운 그룹 시작
      currentGroup = Map<String, dynamic>.from(leave);
      currentGroup['grouped_count'] = 1;
      currentGroup['grouped_ids'] = [leave['id']];
      grouped.add(currentGroup);
    }

    return grouped;
  }

  Map<String, dynamic>? _employee;
  Map<String, dynamic>? get employee => _employee;

  void setEmployee(Map<String, dynamic>? employee) {
    if (_employee != employee) {
      _employee = employee;
      _debouncedNotify();
    }
  }

  Future<void> fetchMyLeaves({
    required String email,
    bool forceRefresh = false,
  }) async {
    _updateLoadingState(true, null);

    try {
      final cacheKey = '$_myLeavesCacheKey$email';
      List<Map<String, dynamic>>? newLeaves;

      if (forceRefresh) {
        // 캐시 무효화
        await _cache.invalidate(cacheKey);
        // Debug print removed

        // DB에서 직접 가져오기
        newLeaves = await _service.fetchMyLeavesRaw(email);
      } else {
        // 캐시 사용
        newLeaves = await _cache.getOrFetch<List<Map<String, dynamic>>>(
          key: cacheKey,
          fallback: () => _requestUtils.dedupedRequest(
            key: 'fetch_my_leaves_$email',
            request: () => _service.fetchMyLeavesRaw(email),
          ),
          ttl: CacheConfig.leaveDataTtl,
          usePersistentCache: true,
          useMemoryCache: true,
          fromJson: (json) => List<Map<String, dynamic>>.from(json['leaves']),
          toJson: (data) => {
            'leaves': data,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Load annual leave data with caching
      await _loadAnnualLeaveFromDB(email, forceRefresh: forceRefresh);

      // Update UI only if data actually changed
      if (newLeaves != null && !_isLeavesEqual(myLeaves, newLeaves)) {
        _batchUpdate(() {
          myLeaves = newLeaves!;
          isLoading = false;
          error = null;
        });

        // 출장일수 계산 (동행자 포함) - myLeaves 업데이트 후에 계산
        await _calculateBiztripDays(email);

        // Debug print removed
      } else {
        // 데이터가 변경되지 않았어도 출장일수는 다시 계산 (attendance_records 변경 가능)
        await _calculateBiztripDays(email);
        _updateLoadingState(false, null);
      }
    } catch (e) {
      _updateLoadingState(false, e.toString());
      // Debug print removed
    }
  }

  Future<void> fetchTodayLeaves(
    DateTime today, {
    bool forceRefresh = false,
  }) async {
    _updateLoadingState(true, null);

    try {
      final dateStr = today.toIso8601String().substring(0, 10);
      final cacheKey = '$_todayLeavesCacheKey$dateStr';

      // Use shorter TTL for today's data as it changes more frequently
      final newTodayLeaves = await _cache
          .getOrFetch<List<Map<String, dynamic>>>(
            key: cacheKey,
            fallback: () => _requestUtils.dedupedRequest(
              key: 'fetch_today_leaves_$dateStr',
              request: () => _service.fetchTodayLeavesRaw(today),
            ),
            ttl: const Duration(minutes: 5), // Shorter TTL for today's data
            usePersistentCache: true,
            useMemoryCache: true,
            fromJson: (json) => List<Map<String, dynamic>>.from(json['leaves']),
            toJson: (data) => {
              'leaves': data,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );

      if (newTodayLeaves != null &&
          !_isLeavesEqual(todayLeaves, newTodayLeaves)) {
        _batchUpdate(() {
          todayLeaves = newTodayLeaves;
          isLoading = false;
        });

        // Debug print removed
      } else {
        _updateLoadingState(false, null);
      }

      if (forceRefresh) {
        await _cache.invalidate(cacheKey);
      }
    } catch (e) {
      _updateLoadingState(false, e.toString());
      // Debug print removed
    }
  }

  Future<void> fetchTomorrowLeaves({bool forceRefresh = false}) async {
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dateStr = tomorrow.toIso8601String().substring(0, 10);
      final cacheKey = '${_todayLeavesCacheKey}tomorrow_$dateStr';

      final newLeaves = await _cache
          .getOrFetch<List<Map<String, dynamic>>>(
            key: cacheKey,
            fallback: () => _requestUtils.dedupedRequest(
              key: 'fetch_tomorrow_leaves_$dateStr',
              request: () => _service.fetchTodayLeavesRaw(tomorrow),
            ),
            ttl: const Duration(minutes: 10),
            usePersistentCache: true,
            useMemoryCache: true,
            fromJson: (json) => List<Map<String, dynamic>>.from(json['leaves']),
            toJson: (data) => {
              'leaves': data,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );

      if (newLeaves != null && !_isLeavesEqual(tomorrowLeaves, newLeaves)) {
        _batchUpdate(() {
          tomorrowLeaves = newLeaves;
        });
      }

      if (forceRefresh) {
        await _cache.invalidate(cacheKey);
      }
    } catch (_) {
      // 내일 데이터 실패해도 무시
    }
  }

  // 달력용: 승인된 연차/출장만 가져오기
  Future<void> fetchApprovedLeavesForCalendar({
    bool forceRefresh = false,
  }) async {
    _updateCalendarLoadingState(true, null);
    _log('fetchApprovedLeavesForCalendar start forceRefresh=$forceRefresh');

    try {
      if (forceRefresh) {
        await _cache.invalidate('calendar_approved_leaves');
      }

      final approvedLeaves = await _cache
          .getOrFetch<List<Map<String, dynamic>>>(
            key: 'calendar_approved_leaves',
            fallback: () => _requestUtils.dedupedRequest(
              key: 'fetch_calendar_leaves',
              request: () =>
                  _service.fetchAllLeavesRaw(approvedOnly: true), // 승인된 것만
            ),
            ttl: const Duration(minutes: 10), // 달력용은 10분 캐시
            usePersistentCache: true,
            useMemoryCache: true,
            fromJson: (json) => List<Map<String, dynamic>>.from(json['leaves']),
            toJson: (data) => {
              'leaves': data,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );

      if (approvedLeaves != null) {
        _batchUpdate(() {
          approvedLeavesForCalendar =
              approvedLeaves; // allLeaves 대신 approvedLeavesForCalendar 사용
          calendarLoading = false;
          error = null;
        });
        _log('fetchApprovedLeavesForCalendar done (cached=${!forceRefresh}) items=${approvedLeaves.length}');

        // Debug print removed
      } else {
        _updateCalendarLoadingState(false, null);
      }
    } catch (e) {
      _updateCalendarLoadingState(false, e.toString());
      // Debug print removed
      _log('fetchApprovedLeavesForCalendar error=$e');
    }
  }

  // 관리자용: 모든 상태의 연차/출장 가져오기
  Future<void> fetchAllLeaves({bool forceRefresh = false}) async {
    // 첫 로딩시에만 로딩 상태 표시, 캐시가 있으면 즉시 표시
    if (allLeaves.isEmpty) {
      _updateLoadingState(true, null);
    }

    try {
      // forceRefresh가 true면 DB에서 직접 가져오기
      List<Map<String, dynamic>>? newAllLeaves;

      if (forceRefresh) {
        // 캐시 무효화
        await _cache.invalidate(_allLeavesCacheKey);
        // Debug print removed

        // DB에서 직접 가져오기
        newAllLeaves = await _service.fetchAllLeavesRaw(approvedOnly: false);
      } else {
        // 캐시 사용
        newAllLeaves = await _cache.getOrFetch<List<Map<String, dynamic>>>(
          key: _allLeavesCacheKey,
          fallback: () => _requestUtils.dedupedRequest(
            key: 'fetch_all_leaves',
            request: () => _service.fetchAllLeavesRaw(
              approvedOnly: false,
            ), // 관리자 화면용: 모든 상태
          ),
          ttl: CacheConfig.leaveDataTtl,
          usePersistentCache: true,
          useMemoryCache: true,
          fromJson: (json) => List<Map<String, dynamic>>.from(json['leaves']),
          toJson: (data) => {
            'leaves': data,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      if (newAllLeaves != null) {
        // 원본 데이터 저장
        _allLeavesRaw = newAllLeaves;

        // 사용자별로 그룹화 적용
        final groupedByUser = <String, List<Map<String, dynamic>>>{};
        for (final leave in newAllLeaves) {
          final userEmail = leave['user_email'] ?? '';
          if (!groupedByUser.containsKey(userEmail)) {
            groupedByUser[userEmail] = [];
          }
          groupedByUser[userEmail]!.add(leave);
        }

        // 각 사용자별로 그룹화 적용 후 합치기
        final allGroupedLeaves = <Map<String, dynamic>>[];
        for (final userLeaves in groupedByUser.values) {
          // 날짜순 정렬
          userLeaves.sort(
            (a, b) => DateTime.parse(
              a['start_date'],
            ).compareTo(DateTime.parse(b['start_date'])),
          );
          // 그룹화 적용
          final grouped = _groupContinuousLeavesForApproval(userLeaves);
          allGroupedLeaves.addAll(grouped);
        }

        // 최신순으로 정렬
        allGroupedLeaves.sort(
          (a, b) => DateTime.parse(
            b['created_at'],
          ).compareTo(DateTime.parse(a['created_at'])),
        );

        _batchUpdate(() {
          allLeaves = allGroupedLeaves;
          isLoading = false;
        });

        // Debug print removed
      } else {
        _updateLoadingState(false, null);
      }
    } catch (e) {
      _updateLoadingState(false, e.toString());
      // Debug print removed
    }
  }

  // ❌ 삭제됨: _calculateAndUpdateAnnualLeave 함수
  // 이유: 사용되지 않는 중복 함수
  // 연차 계산은 백엔드 update_used_annual_leave 함수에서 전담

  // 서버에서 사용연차 업데이트 (새로운 Edge Function 호출)
  Future<bool> _updateUsedAnnualLeave(String userEmail) async {
    try {
      const projectId = 'qvhbigvdfyvhoegkhvef';
      final functionUrl =
          'https://$projectId.supabase.co/functions/v1/update_used_annual_leave';

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'userEmail': userEmail,
          'targetYear': DateTime.now().year,
          'forceUpdate': true, // 강제 업데이트로 즉시 반영
        }),
      ).timeout(const Duration(seconds: 10)); // 타임아웃 추가

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return true; // 성공 반환
        } else {
          return false; // 실패 반환
        }
      } else {
        return false; // HTTP 에러 반환
      }
    } catch (e) {
      // 사용연차 업데이트 실패는 전체 프로세스를 중단시키지 않음
      return false; // 예외 발생시 실패 반환
    }
  }

  // 출장일수 계산 (business_trips 기반 + attendance_records 동행자 포함)
  Future<void> _calculateBiztripDays(String userEmail) async {
    try {
      int daysFromTrips = 0;

      // 1. myLeaves에서 출장(biztrip) 건 계산 (Edge Function이 business_trips를 biztrip으로 변환하여 포함)
      final leavesToCheck = myLeaves.isNotEmpty ? myLeaves : [];
      for (final l in leavesToCheck) {
        if (l['status'] == 'approved' && l['type'] == 'biztrip') {
          daysFromTrips +=
              (DateTime.parse(l['end_date'])
                  .difference(DateTime.parse(l['start_date']))
                  .inDays) + 1;
        }
      }

      // 2. attendance_records에서 동행자 출장일수 추가
      final supabaseService = SupabaseService();
      final employee = await supabaseService.getEmployeeByEmail(userEmail);

      if (employee != null && employee['id'] != null) {
        final employeeId = employee['id'].toString();

        final attendanceRecords = await Supabase.instance.client
            .from('attendance_records')
            .select('date')
            .eq('employee_id', employeeId)
            .eq('status', '출장');

        final Set<String> biztripDates = {};
        for (final record in attendanceRecords) {
          if (record['date'] != null) {
            biztripDates.add(record['date'] as String);
          }
        }
      
        // myLeaves 출장 기간 날짜 수집
        final Set<String> tripDates = {};
        for (final l in leavesToCheck) {
          if (l['status'] == 'approved' && l['type'] == 'biztrip') {
            final start = DateTime.parse(l['start_date']);
            final end = DateTime.parse(l['end_date']);
            for (var date = start; !date.isAfter(end); date = date.add(const Duration(days: 1))) {
              tripDates.add(date.toIso8601String().substring(0, 10));
            }
          }
        }

        final companionBiztripDays = biztripDates.where((date) => !tripDates.contains(date)).length;

        _batchUpdate(() {
          _biztripDays = daysFromTrips + companionBiztripDays;
        });
      } else {
        _batchUpdate(() {
          _biztripDays = daysFromTrips;
        });
      }
    } catch (e) {
      int days = 0;
      for (final l in myLeaves) {
        if (l['status'] == 'approved' && l['type'] == 'biztrip') {
          days += (DateTime.parse(l['end_date'])
              .difference(DateTime.parse(l['start_date']))
              .inDays) + 1;
        }
      }
      _batchUpdate(() {
        _biztripDays = days;
      });
    }
  }

  // DB에서 계산된 연차 정보 로드 (캐시 적용)
  Future<void> _loadAnnualLeaveFromDB(
    String userEmail, {
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = '$_annualLeaveCacheKey$userEmail';

      // forceRefresh일 경우 먼저 캐시 무효화
      if (forceRefresh) {
        await _cache.invalidate(cacheKey);
        // Debug print removed
      }

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
        // Store employee data for next year calculation
        _employee = employee;

        // 직원 정보를 별도로 캐싱 (requestLeave에서 빠르게 접근하기 위해)
        // CacheService는 getOrFetch만 제공하므로 _employee 변수에 저장

        final newGrantedAnnual =
            (employee['annual_leave_granted_current_year'] ?? 0).toDouble();
        // DB 컬럼명은 used_annual_leave임
        final newUsedAnnual =
            double.tryParse(employee['used_annual_leave']?.toString() ?? '0') ??
            0.0;
        final newRemainAnnual =
            double.tryParse(
              employee['remaining_annual_leave']?.toString() ?? '0',
            ) ??
            0.0;

        // Always update values (캐시 문제 해결을 위해 항상 업데이트)
        _currentGrantedAnnual = newGrantedAnnual;
        _usedAnnual = newUsedAnnual;
        _remainAnnual = newRemainAnnual;
        _annualLeaveLoaded = true;  // 연차 데이터 로드 완료 플래그 설정

        // Always notify to ensure UI updates
        _debouncedNotify();
      } else {
        // employee가 null인 경우도 처리

        _annualLeaveLoaded = true;
        _debouncedNotify();
      }
    } catch (e) {
      // 기본값 유지
      _currentGrantedAnnual = 0;
      _usedAnnual = 0;
      _remainAnnual = 0;
      _annualLeaveLoaded = true;  // 연차가 0이어도 로드 완료로 표시
    }
  }

  // 특정 연도 지급연차 조회 (DB에서)
  double getGrantedAnnualForYear(int year) {
    // 현재 연도인 경우 DB에서 가져온 값 사용
    if (year == DateTime.now().year) {
      return _currentGrantedAnnual;
    }

    // 미래 연도 지급연차 추정 (백엔드 24개월 정책 로직과 동일)
    if (_employee != null && _employee!['join_date'] != null) {
      final joinDate = DateTime.parse(_employee!['join_date']);
      if (joinDate.year > year) {
        return 0.0;
      }

      // 같은 해 입사: 입사월~연말 비례(15일 기준)
      if (joinDate.year == year) {
        final remainingMonths = 13 - joinDate.month;
        final leave = ((15 * remainingMonths) / 12).floor().clamp(0, 15);
        return leave.toDouble();
      }

      final serviceYears = year - joinDate.year;

      // 1~2년차: 15일 고정
      if (serviceYears == 1 || serviceYears == 2) {
        // 1~2년차: 15개 고정
        return 15;
      } else {
        // 3년차 이상: 24개월 정책(추가분을 실제 완료개월 기준으로 제한)
        final fiscalStart = DateTime(year, 1, 1);
        var completedMonths =
            (fiscalStart.year - joinDate.year) * 12 + (fiscalStart.month - joinDate.month);

        final additionalByFiscal = ((serviceYears - 1) / 2).floor();
        final additionalByMonths = (completedMonths / 24).floor().clamp(0, 1000000);
        final additional = additionalByFiscal < additionalByMonths ? additionalByFiscal : additionalByMonths;

        final totalLeave = (15 + additional).clamp(0, 25);
        return totalLeave.toDouble();
      }
    }

    return 15.0; // 기본값
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
      // 캐시된 직원 정보 사용 (DB 조회 최소화)
      String name = '';

      // _employee에 캐시된 정보가 있으면 사용
      if (_employee != null) {
        name = _employee?['name'] ?? '';
      } else {
        // 캐시에 없을 경우만 DB 조회
        final supabaseService = SupabaseService();
        final employee = await supabaseService.getEmployeeByEmail(userEmail);
        if (employee != null) {
          _employee = employee; // 메모리에 캐싱
          name = employee['name'] ?? '';
        }
      }

      // 출장인 경우 reason에서 정보 파싱하여 별도 필드에 저장
      Map<String, dynamic> leaveData = {
        'user_email': userEmail,
        'name': name,
        'type': type,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      // 출장인 경우 reason 파싱하여 별도 필드에 저장
      // (구형 데이터/구형 앱)에서만 사용: reason에 메타정보가 있을 때만 파싱
      final bool hasBiztripMetaInReason =
          reason != null &&
          (reason.contains('출장자:') ||
              reason.contains('동행:') ||
              reason.contains('장소:') ||
              reason.contains('목적:') ||
              reason.contains('교통수단:'));

      if (type == 'biztrip' && hasBiztripMetaInReason) {
        // 출장자 이름 파싱 (reason에서 "출장자: 이름" 또는 name 필드 사용)
        String travelerName = name;
        final travelerMatch = RegExp(r'출장자\s*:\s*([^\n]+)').firstMatch(reason);
        if (travelerMatch != null) {
          travelerName = travelerMatch.group(1)?.trim() ?? name;
        }
        
        // 출장자 배열 생성 (본인 + 동행자)
        List<String> travelers = [travelerName];
        
        // 동행자 파싱
        final companionMatch = RegExp(r'동행\s*:\s*([^\n]+)').firstMatch(reason);
        if (companionMatch != null) {
          final companionStr = companionMatch.group(1)?.trim() ?? '';
          if (companionStr.isNotEmpty) {
            final companionsList = companionStr
                .split(',')
                .map((c) => c.trim())
                .where((c) => c.isNotEmpty)
                .toList();
            travelers.addAll(companionsList);
          }
        }
        
        leaveData['출장자'] = travelers;
        
        // 장소 파싱
        final placeMatch = RegExp(r'장소\s*:\s*([^\n]+)').firstMatch(reason);
        if (placeMatch != null) {
          leaveData['place'] = placeMatch.group(1)?.trim();
        }
        
        // 레거시 포맷에서 '목적:' 라인이 사실상 업무 내용이었으므로,
        // 목적 라인을 파싱해서 reason(업무내용)에 저장한다. (DB에는 purpose 컬럼이 없음)
        final purposeMatch = RegExp(r'목적\s*:\s*([^\n]+)').firstMatch(reason);
        final parsedWork = purposeMatch?.group(1)?.trim();
        leaveData['reason'] =
            (parsedWork != null && parsedWork.isNotEmpty) ? parsedWork : reason;
        
        // 교통수단 파싱
        final transportMatch = RegExp(r'교통수단\s*:\s*([^\n]+)').firstMatch(reason);
        if (transportMatch != null) {
          leaveData['transport'] = transportMatch.group(1)?.trim();
        }
      }

      // DB에 연차/출장 신청 저장
      await _service.insertLeave(leaveData);

      // 캐시 무효화 - 신청 직후 새로운 데이터를 가져올 수 있도록
      await _cache.invalidate(_allLeavesCacheKey);
      await _cache.invalidate('$_myLeavesCacheKey$userEmail');
      // Debug print removed

      // 푸시 알림은 백엔드 트리거에서 자동으로 처리됨

      // 사용연차 업데이트와 캐시 무효화 (신청 시에는 승인된 연차만 계산되므로 변화 없음)
      try {
        await _invalidateUserRelatedCaches(userEmail);
      } catch (e) {
        // 에러가 나도 계속 진행
      }

      // 데이터 새로고침 (fetchAllLeaves는 fetchMyLeaves 내부에서 자동 호출됨)
      try {
        await fetchMyLeaves(email: userEmail, forceRefresh: true);
      } catch (e) {
        // 데이터 새로고침 오류 시 무시
      }
      
      // 전체 연차/출장 목록 새로고침 (대시보드 업데이트용)
      try {
        await fetchAllLeaves(forceRefresh: true);
      } catch (e) {
        // 데이터 새로고침 오류 시 무시
      }
      
      // UI 업데이트 알림
      notifyListeners();
      
      _updateLoadingState(false, null);
    } catch (e, stackTrace) {
      _updateLoadingState(false, e.toString());
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  /// business_trips 승인/반려
  Future<void> updateBusinessTripStatus(
    dynamic id,
    String status, {
    String? rejectionReason,
    bool isModification = false,
  }) async {
    try {
      await _service.updateBusinessTripStatus(
        id,
        status,
        rejectionReason: rejectionReason,
        isModification: isModification,
      );

      // 캐시 무효화 및 데이터 새로고침
      await _cache.invalidate(_allLeavesCacheKey);
      await fetchAllLeaves(forceRefresh: true);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 영수증 업로드 가능한 카드 사용 건 조회
  Future<List<Map<String, dynamic>>> fetchMyUploadableCards() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'get_my_card_usages',
      );

      if (response.status == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data'] ?? []);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }


  Future<void> updateLeaveStatus(
    int id,
    String status, {
    bool skipNotification = false,
  }) async {
    try {
      // Debug print removed

      // 1. 원본 데이터에서 찾기 (_allLeavesRaw 사용)
      final rawLeaveIndex = _allLeavesRaw.indexWhere(
        (leave) => leave['id'] == id,
      );

      if (rawLeaveIndex == -1) {
        // Debug print removed
        return;
      }

      final leaveDetails = _allLeavesRaw[rawLeaveIndex];
      final requesterEmail = leaveDetails['user_email'] as String?;

      // 2. DB 상태 업데이트
      await _service.updateLeaveStatus(id, status);
      // Debug print removed

      // 2-1. 원본 데이터 즉시 업데이트
      _allLeavesRaw[rawLeaveIndex]['status'] = status;
      _allLeavesRaw[rawLeaveIndex]['updated_at'] = DateTime.now()
          .toIso8601String();

      // 2-2. 그룹화된 데이터에서도 업데이트
      for (int i = 0; i < allLeaves.length; i++) {
        final leave = allLeaves[i];
        final groupedIds = leave['grouped_ids'] as List<dynamic>?;

        // 그룹화된 항목인 경우
        if (groupedIds != null && groupedIds.contains(id)) {
          // 그룹에서 해당 항목 제거가 필요한지 확인
          if (groupedIds.length > 1) {
            // 그룹에 다른 항목이 있으면, 상태가 다른 항목은 그룹에서 제거
            // 전체 데이터를 다시 그룹화하는 것이 더 안전
            _reprocessGroupedData();
            break;
          } else {
            // 단일 항목이면 상태만 업데이트
            allLeaves[i]['status'] = status;
            allLeaves[i]['updated_at'] = DateTime.now().toIso8601String();
          }
        } else if (leave['id'] == id) {
          // 그룹화되지 않은 단일 항목
          allLeaves[i]['status'] = status;
          allLeaves[i]['updated_at'] = DateTime.now().toIso8601String();
        }
      }

      // myLeaves에서도 업데이트 (동일한 신청이 있다면)
      final myLeaveIndex = myLeaves.indexWhere((leave) => leave['id'] == id);
      if (myLeaveIndex != -1) {
        myLeaves[myLeaveIndex]['status'] = status;
        myLeaves[myLeaveIndex]['updated_at'] = DateTime.now().toIso8601String();
      }

      notifyListeners();

      // 3. 신청자의 사용연차 정보 재계산 (승인/반려 시)
      if (requesterEmail != null && requesterEmail.isNotEmpty) {
        final updateSuccess = await _updateUsedAnnualLeave(requesterEmail);
        
        // 🔧 FIX: 연차 계산 완료 후 UI 즉시 업데이트
        await _loadAnnualLeaveFromDB(requesterEmail);
        notifyListeners(); // 연차 정보 업데이트 후 UI 새로고침
        
        // Edge Function 실패시 경고 (UI는 업데이트됨)
        if (!updateSuccess) {
          // 실패해도 로컬 캐시는 무효화되어 다음 로드시 최신 데이터 가져옴
        }
      }

      // 4. 관련 캐시 무효화 (비동기로 처리하여 UI 차단 방지)
      _invalidateRelatedCaches(requesterEmail);

      // 5. 신청자에게 승인/반려 결과 알림은 백엔드 트리거에서 자동으로 처리됨
      // send_leave_status_change_notification 트리거가 상태 변경 시 알림 발송
    } catch (e) {
      // Debug print removed
      rethrow;
    }
  }

  // 연차 신청 삭제 (출장은 웹에서만 취소 가능)
  Future<void> deleteLeaveRequest({
    required int leaveId,
    required String userEmail,
    required String userName,
    required String leaveType,
    required String startDate,
    required String endDate,
  }) async {
    try {
      // 출장 건은 삭제 불가 (모바일에서 취소 불가)
      if (leaveType == 'biztrip' || leaveType == 'business_trip') {
        throw Exception('출장 건은 웹에서만 취소할 수 있습니다.');
      }

      // 1. Edge Function을 통해 삭제 (RLS 우회)
      await _service.deleteLeaveViaEdgeFunction(
        leaveId: leaveId,
        userEmail: userEmail,
        isAdmin: false,
      );

      // Debug print removed

      // 2. 로컬 데이터 업데이트
      myLeaves.removeWhere((leave) => leave['id'] == leaveId);
      allLeaves.removeWhere((leave) => leave['id'] == leaveId);

      // 3. 캐시 무효화 - 중요!
      await _cache.invalidate('$_myLeavesCacheKey$userEmail');
      await _cache.invalidate(_allLeavesCacheKey);
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      await _cache.invalidate('$_todayLeavesCacheKey$dateStr');

      // Debug print removed

      // 4. 푸시 알림은 백엔드 트리거에서 자동으로 처리됨
      // send_leave_cancel_notification 트리거가 DELETE 시 알림 발송

      // 5. 사용연차 재계산
      await _updateUsedAnnualLeave(userEmail);

      // 6. UI 업데이트 (이미 로컬 데이터 삭제했으므로 추가 새로고침 불필요)
      notifyListeners();

      // Debug print removed
    } catch (e) {
      // Debug print removed
      throw Exception('신청 취소 중 오류가 발생했습니다: $e');
    }
  }

  // 관리자가 연차/출장 수정
  Future<void> updateLeave({
    required int leaveId,
    required String type,
    required String status,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      // Debug print removed

      // Edge Function을 통해 수정
      final response = await Supabase.instance.client.functions.invoke(
        'update_leave',
        body: {
          'leaveId': leaveId,
          'type': type,
          'status': status,
          'startDate': startDate,
          'endDate': endDate,
          'reason': reason,
        },
      );

      if (response.status == 200) {
        // Debug print removed

        // 로컬 데이터 업데이트
        final index = allLeaves.indexWhere((leave) => leave['id'] == leaveId);
        if (index != -1) {
          allLeaves[index] = {
            ...allLeaves[index],
            'type': type,
            'status': status,
            'start_date': startDate,
            'end_date': endDate,
            'reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          };
        }

        final myIndex = myLeaves.indexWhere((leave) => leave['id'] == leaveId);
        if (myIndex != -1) {
          myLeaves[myIndex] = {
            ...myLeaves[myIndex],
            'type': type,
            'status': status,
            'start_date': startDate,
            'end_date': endDate,
            'reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          };
        }

        notifyListeners();
        
        // 성공적으로 수정됨 - 추가 새로고침 불필요 (이미 로컬 데이터 업데이트함)
      } else {
        throw Exception('수정 실패: ${response.data?['error'] ?? '알 수 없는 오류'}');
      }
    } catch (e) {
      // Debug print removed
      throw Exception('수정 중 오류가 발생했습니다: $e');
    }
  }

  // 관리자가 연차/출장 세부사항 수정
  Future<void> updateLeaveDetails({
    required int leaveId,
    required String type,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      // Debug print removed

      // 현재 leave 정보 찾기
      final currentLeave = _allLeavesRaw.firstWhere(
        (leave) => leave['id'] == leaveId,
        orElse: () => {},
      );

      if (currentLeave.isEmpty) {
        // Debug print removed
        throw Exception('수정할 연차/출장 정보를 찾을 수 없습니다.');
      }

      // Debug print removed

      // Edge Function을 통해 수정 - 타임아웃 설정
      final response = await Supabase.instance.client.functions.invoke(
        'update_leave',
        body: {
          'leaveId': leaveId,
          'type': type,
          'status': currentLeave['status'], // 상태는 변경하지 않음 (반려된 것도 수정 가능)
          'startDate': startDate,
          'endDate': endDate,
          'reason': reason,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          // Debug print removed
          throw Exception('요청 시간이 초과되었습니다. 다시 시도해주세요.');
        },
      );
      
      // Debug print removed

      if (response.status == 200) {
        // Debug print removed

        // 로컬 데이터 업데이트
        final rawIndex = _allLeavesRaw.indexWhere((leave) => leave['id'] == leaveId);
        if (rawIndex != -1) {
          _allLeavesRaw[rawIndex] = {
            ..._allLeavesRaw[rawIndex],
            'type': type,
            'start_date': startDate,
            'end_date': endDate,
            'reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          };
        }

        // 그룹화된 데이터 재처리
        _reprocessGroupedData();

        // myLeaves에서도 업데이트
        final myIndex = myLeaves.indexWhere((leave) => leave['id'] == leaveId);
        if (myIndex != -1) {
          myLeaves[myIndex] = {
            ...myLeaves[myIndex],
            'type': type,
            'start_date': startDate,
            'end_date': endDate,
            'reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          };
        }

        // 캐시 무효화
        final requesterEmail = currentLeave['user_email'] ?? '';
        await _invalidateRelatedCaches(requesterEmail);

        // 사용연차 재계산 (타입이나 날짜가 변경된 경우)
        if (requesterEmail.isNotEmpty) {
          await _updateUsedAnnualLeave(requesterEmail);
        }

        notifyListeners();
      } else {
        throw Exception('수정 실패: ${response.data?['error'] ?? '알 수 없는 오류'}');
      }
    } catch (e) {
      // Debug print removed
      throw Exception('수정 중 오류가 발생했습니다: $e');
    }
  }

  // 관리자가 처리완료된 연차/출장 삭제
  Future<void> deleteApprovedLeave({
    required int leaveId,
    required String requesterEmail,
    required String requesterName,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String status,
  }) async {
    try {
      

      // 1. Edge Function을 통해 삭제 (RLS 우회, 관리자 권한)
      await _service.deleteLeaveViaEdgeFunction(
        leaveId: leaveId,
        userEmail: null, // 관리자는 userEmail 체크 불필요
        isAdmin: true,
      );

      // Debug print removed

      // 2. 로컬 데이터 업데이트
      myLeaves.removeWhere((leave) => leave['id'] == leaveId);
      allLeaves.removeWhere((leave) => leave['id'] == leaveId);

      // 3. 캐시 무효화 - 중요!
      await _cache.invalidate('$_myLeavesCacheKey$requesterEmail');
      await _cache.invalidate(_allLeavesCacheKey);
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      await _cache.invalidate('$_todayLeavesCacheKey$dateStr');

      // Debug print removed

      // 4. 신청자 알림은 Edge Function에서 이미 처리됨 (FCM 푸시)
      // 중복 알림 방지를 위해 Provider에서 추가 알림은 제거

      // 5. 사용연차 재계산
      await _updateUsedAnnualLeave(requesterEmail);

      // 6. UI 업데이트 (이미 로컬 데이터 삭제했으므로 추가 새로고침 불필요)
      notifyListeners();

      // Debug print removed
    } catch (e) {
      // Debug print removed
      throw Exception('삭제 중 오류가 발생했습니다: $e');
    }
  }

  // 배치 업데이트 헬퍼 메서드들
  void _batchUpdate(VoidCallback updates) {
    _shouldNotify = false;
    updates();
    _shouldNotify = true;
    _debouncedNotify();
  }

  // 디바운싱된 알림 (using TimerManager)
  void _debouncedNotify() {
    scopedDebounce(
      key: 'notify_debounce',
      delay: const Duration(milliseconds: 300),
      callback: () {
        if (_shouldNotify) {
          notifyListeners();
        }
      },
    );
  }

  void _updateCalendarLoadingState(bool loading, String? errorMsg) {
    if (calendarLoading != loading || error != errorMsg) {
      _batchUpdate(() {
        calendarLoading = loading;
        error = errorMsg;
      });
      _log('calendarLoading=$calendarLoading error=${error ?? "none"}');
    }
  }

  void _updateLoadingState(bool loading, String? errorMsg) {
    if (isLoading != loading || error != errorMsg) {
      _batchUpdate(() {
        isLoading = loading;
        error = errorMsg;
      });
      _log('isLoading=$isLoading error=${error ?? "none"}');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[LeaveProvider] $message');
    }
  }

  @override
  void dispose() {
    // Dispose all scoped timers and operations
    disposeScopedTimers();
    disposeScopedOperations();
    super.dispose();
  }

  // 그룹화된 데이터를 다시 처리하는 메서드 (최적화)
  void _reprocessGroupedData() {
    if (_allLeavesRaw.isEmpty) return;

    // 변경된 상태의 항목만 찾아서 부분 업데이트
    final pendingItems = <Map<String, dynamic>>[];
    final nonPendingItems = <Map<String, dynamic>>[];

    for (final leave in _allLeavesRaw) {
      if (leave['status'] == 'pending') {
        pendingItems.add(leave);
      } else {
        nonPendingItems.add(leave);
      }
    }

    // pending 항목만 그룹화 (승인/반려된 항목은 그룹화 불필요)
    final groupedPending = _groupContinuousLeavesForApproval(pendingItems);

    // 결합하고 정렬
    final allGroupedLeaves = [...groupedPending, ...nonPendingItems];
    allGroupedLeaves.sort(
      (a, b) => DateTime.parse(
        b['created_at'],
      ).compareTo(DateTime.parse(a['created_at'])),
    );

    // 업데이트
    allLeaves = allGroupedLeaves;

    // Debug print removed
  }

  // 리스트 비교 헬퍼
  bool _isLeavesEqual(
    List<Map<String, dynamic>> old,
    List<Map<String, dynamic>> newList,
  ) {
    if (old.length != newList.length) return false;
    for (int i = 0; i < old.length; i++) {
      // ID와 상태만 비교 (핵심 데이터)
      if (old[i]['id'] != newList[i]['id'] ||
          old[i]['status'] != newList[i]['status']) {
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
    // Debug print removed
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

    // Debug print removed
  }

  /// Force refresh all data by clearing cache and reloading
  Future<void> forceRefreshAll({String? userEmail}) async {
    // 캐시만 삭제하고 병렬로 필요한 데이터만 가져오기
    await _cache.clearAll();

    // 병렬 처리로 성능 개선
    final futures = <Future>[];

    if (userEmail != null) {
      futures.add(fetchMyLeaves(email: userEmail, forceRefresh: true));
    }

    // 승인 화면에서는 fetchAllLeaves만 필요
    futures.add(fetchAllLeaves(forceRefresh: true));

    // todayLeaves는 필요할 때만 가져오도록 (일반적으로 필요 없음)
    // futures.add(fetchTodayLeaves(DateTime.now(), forceRefresh: true));

    await Future.wait(futures);

    // Debug print removed
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }

  /// 공휴일 데이터 가져오기
  Future<void> fetchHolidays({bool forceRefresh = false}) async {
    try {
      final currentYear = DateTime.now().year;

      // 올해와 앞으로 3년치 공휴일 가져오기
      final response = await Supabase.instance.client
          .from('holidays')
          .select('*')
          .gte('year', currentYear)
          .lte('year', currentYear + 3) // 4년치 데이터 가져오기
          .order('date', ascending: true);

      holidays = List<Map<String, dynamic>>.from(response);

      // 데이터가 부족한 경우 자동 동기화 실행
      if (holidays.isEmpty || !_hasHolidaysForYear(currentYear + 1)) {
        // Debug print removed
        await _triggerHolidaySync();

        // 동기화 후 다시 조회
        final retryResponse = await Supabase.instance.client
            .from('holidays')
            .select('*')
            .gte('year', currentYear)
            .lte('year', currentYear + 3)
            .order('date', ascending: true);

        holidays = List<Map<String, dynamic>>.from(retryResponse);
      }

      // 여전히 데이터가 없으면 하드코딩 데이터 사용 (fallback)
      if (holidays.isEmpty) {
        // Debug print removed
        holidays = [
          {
            'date': '2025-01-01',
            'name': '신정',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-01-28',
            'name': '설날 연휴',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-01-29',
            'name': '설날',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-01-30',
            'name': '설날 연휴',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-03-01',
            'name': '삼일절',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-05-05',
            'name': '어린이날',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-05-06',
            'name': '어린이날 대체공휴일',
            'year': 2025,
            'is_alternative': true,
          },
          {
            'date': '2025-06-06',
            'name': '현충일',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-08-15',
            'name': '광복절',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-10-03',
            'name': '개천절',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-10-05',
            'name': '추석 연휴',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-10-06',
            'name': '추석',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-10-07',
            'name': '추석 연휴',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-10-08',
            'name': '추석 대체공휴일',
            'year': 2025,
            'is_alternative': true,
          },
          {
            'date': '2025-10-09',
            'name': '한글날',
            'year': 2025,
            'is_alternative': false,
          },
          {
            'date': '2025-12-25',
            'name': '크리스마스',
            'year': 2025,
            'is_alternative': false,
          },
        ];
      }

      notifyListeners();
    } catch (e) {
      // Debug print removed

      // 에러 발생시 빈 배열로 설정
      holidays = [];
      notifyListeners();
    }
  }

  /// 특정 날짜가 공휴일인지 확인
  bool isHoliday(DateTime date) {
    final dateStr = date.toIso8601String().substring(0, 10);
    return holidays.any((h) => h['date'] == dateStr);
  }

  /// 특정 날짜의 공휴일 정보 가져오기
  Map<String, dynamic>? getHolidayInfo(DateTime date) {
    final dateStr = date.toIso8601String().substring(0, 10);
    try {
      return holidays.firstWhere((h) => h['date'] == dateStr);
    } catch (e) {
      return null;
    }
  }

  /// 특정 연도의 공휴일 데이터가 있는지 확인
  bool _hasHolidaysForYear(int year) {
    return holidays.any((h) => h['year'] == year);
  }

  /// 공휴일 자동 동기화 트리거
  Future<void> _triggerHolidaySync() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'sync-holidays-cron',
        body: {},
      );

      if (response.data != null && response.data['success'] == true) {
        // Debug print removed
      } else {
        // Debug print removed
      }
    } catch (e) {
      // Debug print removed
    }
  }
}
