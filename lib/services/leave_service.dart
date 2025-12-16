import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_optimization_service.dart';

// 연차/출장 등 휴가 관련 DB 연동 서비스
class LeaveService {
  
  final _client = Supabase.instance.client;
  final String table = 'leave';

  Future<List<Map<String, dynamic>>> fetchAllLeavesRaw({
    bool approvedOnly = false,
  }) async {
    try {
      // Debug code removed

      // 현재 사용자의 이메일 가져오기
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        // Debug code removed
        return [];
      }

      final userEmail = currentUser.email;
      if (userEmail == null) {
        // Debug code removed
        return [];
      }

      // Debug code removed

      if (approvedOnly) {
        return await _fetchAllApprovedLeavesViaEdgeFunction();
      }

      return await _fetchAllLeavesForApprovalViaEdgeFunction();
    } catch (e) {
      // Debug code removed
      // 오류 발생 시 fallback 방식 사용
      return await _fetchAllLeavesRawFallback();
    }
  }

  Future<List<Map<String, dynamic>>>
  _fetchAllLeavesForApprovalViaEdgeFunction() async {
    try {
      // Debug code removed

      // Supabase Functions API 직접 사용
      final response = await _client.functions.invoke(
        'get_all_leaves_for_approval',
      );

      if (response.status == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          final leaves = List<Map<String, dynamic>>.from(
            responseData['data'] ?? [],
          );

          // Debug code removed

          return leaves;
        }
      }

      // Debug code removed
      // Edge Function 실패 시 기존 방식 사용
      return await _fetchAllLeavesRawFallback();
    } catch (e) {
      // Debug code removed
      return await _fetchAllLeavesRawFallback();
    }
  }

  Future<List<Map<String, dynamic>>>
  _fetchAllApprovedLeavesViaEdgeFunction() async {
    try {
      // Debug code removed

      // Supabase Functions API 직접 사용
      final response = await _client.functions.invoke(
        'get_all_approved_leaves',
      );

      if (response.status == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          final leaves = List<Map<String, dynamic>>.from(
            responseData['data'] ?? [],
          );

          // Debug code removed

          return leaves;
        }
      }

      // Debug code removed
      // Edge Function 실패 시 기존 방식 사용
      return await _fetchAllLeavesRawFallback();
    } catch (e) {
      // Debug code removed
      return await _fetchAllLeavesRawFallback();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllLeavesRawFallback() async {
    try {
      // Debug code removed

      // 1. leave 데이터 조회
      final leaveResponse = await _client
          .from('leave')
          .select('*')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> leaveList = (leaveResponse as List)
          .cast<Map<String, dynamic>>();
      // Debug code removed

      // 2. employees 데이터 조회
      final employeesResponse = await _client
          .from('employees')
          .select('email, name, department, attendance_role');

      final List<Map<String, dynamic>> employeesList =
          (employeesResponse as List).cast<Map<String, dynamic>>();
      // Debug code removed

      // 3. 이메일을 기준으로 데이터 결합
      final Map<String, Map<String, dynamic>> employeesMap = {};
      for (final emp in employeesList) {
        if (emp['email'] != null) {
          employeesMap[emp['email']] = emp;
        }
      }

      // 4. leave 데이터에 employee 정보 추가
      for (final leave in leaveList) {
        final userEmail = leave['user_email'];
        if (userEmail != null && employeesMap.containsKey(userEmail)) {
          leave['employees'] = employeesMap[userEmail];
        } else {
          // 기본값 설정
          leave['employees'] = {
            'name': leave['name'] ?? '알 수 없음',
            'email': userEmail ?? '',
            'department': null,
            'attendance_role': null,
          };
        }
      }

      // Debug code removed
      return leaveList;
    } catch (e) {
      // Debug code removed
      rethrow;
    }
  }

  // 내 leave 내역 조회
  Future<List<Map<String, dynamic>>> fetchMyLeavesRaw(String userEmail) async {
    final response = await _client
        .from(table)
        .select('*')
        .eq('user_email', userEmail);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> insertLeave(Map<String, dynamic> data) async {
    await _client.from(table).insert(data);

    // 캐시 무효화 - DatabaseOptimizationService 캐시도 클리어
    final dbOptim = DatabaseOptimizationService.instance;
    await dbOptim.invalidateCache(patterns: ['leave']);
    // Debug code removed
  }

  Future<void> updateLeaveStatus(int id, String status) async {
    try {
      // Debug code removed

      final response = await _client.functions.invoke(
        'update_leave_status',
        body: {'id': id, 'status': status},
      );

      // FunctionResponse는 data만 반환함
      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        throw Exception(responseData['error'] ?? 'Unknown error');
      }

      // Debug code removed

      // 캐시 무효화 - 상태 변경 시 관련된 모든 캐시를 클리어
      final dbOptim = DatabaseOptimizationService.instance;
      await dbOptim.invalidateCache(patterns: ['leave']);

      // Debug code removed
    } catch (e) {
      // Debug code removed
      rethrow;
    }
  }

  /// 출장 신청 저장
  /// 화면(`BusinessTripRequestScreenOptimized`)에서 사용합니다.
  /// - DB 스키마상 별도 컬럼이 없어 상세 정보는 `reason`에 요약하여 저장합니다.
  /// - 성공 시 삽입된 레코드를 반환합니다(널이 아니면 성공으로 간주하도록 호출부가 구성되어 있음).
  Future<Map<String, dynamic>?> submitLeaveRequest({
    required String email,
    required String name,
    required String leaveDate, // yyyy-MM-dd 형식
    required String place,
    required String purpose,
    required String transport,
    String? companions,
  }) async {
    // 출장자 배열 생성 (본인 + 동행자)
    final List<String> bizTripAttendees = [name];
    if ((companions ?? '').trim().isNotEmpty) {
      final companionsList = companions!
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      bizTripAttendees.addAll(companionsList);
    }

    final Map<String, dynamic> data = {
      'user_email': email,
      'name': name,
      'type': 'biztrip',
      'start_date': leaveDate,
      'end_date': leaveDate,
      // reason에는 출장 "업무 내용"이 들어가야 함 (현재 입력값 = purpose)
      'reason': purpose,
      '출장자': bizTripAttendees,      // 출장자 + 동행자 전체 배열
      'place': place,                 // 장소
      'transport': transport,         // 교통수단
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    final inserted = await _client
        .from(table)
        .insert(data)
        .select()
        .maybeSingle();

    // 캐시 무효화 - 출장 신청 후에도 캐시를 클리어해야 관리자 탭에 즉시 반영됨
    final dbOptim = DatabaseOptimizationService.instance;
    await dbOptim.invalidateCache(patterns: ['leave']);
    // Debug code removed

    if (inserted is Map<String, dynamic>) {
      return Map<String, dynamic>.from(inserted);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchTodayLeavesRaw(DateTime today) async {
    final todayStr = today.toIso8601String().substring(0, 10);
    final response = await _client
        .from(table)
        .select('*')
        .eq('status', 'approved')
        .lte('start_date', todayStr)
        .gte('end_date', todayStr);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> deleteLeaveViaEdgeFunction({
    required int leaveId,
    String? userEmail,
    bool isAdmin = false,
  }) async {
    try {
      // Debug code removed

      final response = await _client.functions.invoke(
        'delete_leave',
        body: {'leaveId': leaveId, 'userEmail': userEmail, 'isAdmin': isAdmin},
      );

      if (response.status != 200) {
        throw Exception('삭제 실패: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      // Debug code removed

      if (data['success'] != true) {
        throw Exception(data['message'] ?? '삭제 실패');
      }

      return data;
    } catch (e) {
      // Debug code removed
      rethrow;
    }
  }
}
