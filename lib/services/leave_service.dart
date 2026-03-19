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

      // 1. leave 데이터 조회 (biztrip_migrated 제외)
      final leaveResponse = await _client
          .from('leave')
          .select('*')
          .not('type', 'eq', 'biztrip_migrated')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> leaveList = (leaveResponse as List)
          .cast<Map<String, dynamic>>();
      // Debug code removed

      // 2. employees 데이터 조회
      final employeesResponse = await _client
          .from('employees')
          .select('id, email, name, department, attendance_role');

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

      // 5. business_trips 데이터 조회 및 합산
      try {
        final btResponse = await _client
            .from('business_trips')
            .select('*')
            .order('created_at', ascending: false);
        final btList = (btResponse as List).cast<Map<String, dynamic>>();

        for (final bt in btList) {
          // requester_id로 직원 찾기
          final requester = employeesList.firstWhere(
            (e) => e['id'] == bt['requester_id'],
            orElse: () => <String, dynamic>{},
          );
          final requesterEmail = (requester['email'] ?? '') as String;
          final requesterName = (requester['name'] ?? '알 수 없음') as String;

          final companionNames = <String>[];
          if (bt['companions'] != null && bt['companions'] is List) {
            for (final c in bt['companions']) {
              if (c is Map && c['name'] != null) companionNames.add(c['name'].toString());
            }
          }

          leaveList.add({
            'id': 'bt_${bt['id']}',
            'business_trip_id': bt['id'],
            'user_email': requesterEmail,
            'name': requesterName,
            'type': 'biztrip',
            'start_date': bt['trip_start_date'],
            'end_date': bt['trip_end_date'],
            'reason': bt['trip_purpose'],
            'place': bt['trip_destination'],
            '출장자': [requesterName, ...companionNames],
            'status': bt['approval_status'] == 'completed' ? 'approved' : bt['approval_status'],
            'created_at': bt['created_at'],
            'updated_at': bt['updated_at'],
            'trip_code': bt['trip_code'],
            'is_business_trip': true,
            'employees': employeesMap[requesterEmail] ?? {
              'name': requesterName,
              'email': requesterEmail,
              'department': bt['request_department'],
              'attendance_role': null,
            },
          });
        }
      } catch (e) {
        // business_trips 조회 실패해도 leave 데이터는 반환
      }

      // Debug code removed
      return leaveList;
    } catch (e) {
      // Debug code removed
      rethrow;
    }
  }

  // 내 leave 내역 조회 (leave + business_trips 합산)
  Future<List<Map<String, dynamic>>> fetchMyLeavesRaw(String userEmail) async {
    // 1. leave 테이블 (biztrip_migrated 제외)
    final leaveResponse = await _client
        .from(table)
        .select('*')
        .eq('user_email', userEmail)
        .not('type', 'eq', 'biztrip_migrated');
    final leaveList = (leaveResponse as List).cast<Map<String, dynamic>>();

    // 2. business_trips 테이블 (본인이 신청자인 건)
    // 먼저 employee id 조회
    final empResponse = await _client
        .from('employees')
        .select('id, name')
        .eq('email', userEmail)
        .maybeSingle();

    if (empResponse != null) {
      final employeeId = empResponse['id'];
      final employeeName = empResponse['name'] ?? '';

      final btResponse = await _client
          .from('business_trips')
          .select('*')
          .eq('requester_id', employeeId)
          .order('created_at', ascending: false);

      final btList = (btResponse as List).cast<Map<String, dynamic>>();

      // business_trips를 leave 형식으로 변환
      for (final bt in btList) {
        final companionNames = <String>[];
        if (bt['companions'] != null && bt['companions'] is List) {
          for (final c in bt['companions']) {
            if (c is Map && c['name'] != null) {
              companionNames.add(c['name'].toString());
            }
          }
        }
        final allTravelers = [employeeName, ...companionNames];

        leaveList.add({
          'id': 'bt_${bt['id']}',
          'business_trip_id': bt['id'],
          'user_email': userEmail,
          'name': employeeName,
          'type': 'biztrip',
          'start_date': bt['trip_start_date'],
          'end_date': bt['trip_end_date'],
          'reason': bt['trip_purpose'],
          'place': bt['trip_destination'],
          'transport': null,
          '출장자': allTravelers,
          'status': bt['approval_status'] == 'completed' ? 'approved' : bt['approval_status'],
          'approved_at': bt['approved_at'],
          'created_at': bt['created_at'],
          'updated_at': bt['updated_at'],
          'trip_code': bt['trip_code'],
          'rejection_reason': bt['rejection_reason'],
          'is_business_trip': true,
        });
      }
    }

    // 최신순 정렬
    leaveList.sort((a, b) =>
        DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

    return leaveList;
  }

  Future<void> insertLeave(Map<String, dynamic> data) async {
    await _client.from(table).insert(data);

    // 캐시 무효화 - DatabaseOptimizationService 캐시도 클리어
    final dbOptim = DatabaseOptimizationService.instance;
    await dbOptim.invalidateCache(patterns: ['leave']);
    // Debug code removed
  }

  /// business_trips 테이블 승인/반려
  Future<void> updateBusinessTripStatus(dynamic id, String status, {String? rejectionReason}) async {
    try {
      final response = await _client.functions.invoke(
        'update_leave_status',
        body: {
          'id': id,
          'status': status,
          'is_business_trip': true,
          'rejection_reason': rejectionReason,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] != true) {
        throw Exception(responseData['error'] ?? 'Unknown error');
      }

      final dbOptim = DatabaseOptimizationService.instance;
      await dbOptim.invalidateCache(patterns: ['leave']);
    } catch (e) {
      rethrow;
    }
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

  Future<List<Map<String, dynamic>>> fetchTodayLeavesRaw(DateTime today) async {
    final todayStr = today.toIso8601String().substring(0, 10);

    // 1. leave 테이블 (biztrip_migrated 제외)
    final leaveResponse = await _client
        .from(table)
        .select('*')
        .eq('status', 'approved')
        .not('type', 'eq', 'biztrip_migrated')
        .lte('start_date', todayStr)
        .gte('end_date', todayStr);
    final result = (leaveResponse as List).cast<Map<String, dynamic>>();

    // 2. business_trips 테이블 (오늘 포함된 승인 건)
    final btResponse = await _client
        .from('business_trips')
        .select('*, employees:requester_id(name, email)')
        .inFilter('approval_status', ['approved', 'completed'])
        .lte('trip_start_date', todayStr)
        .gte('trip_end_date', todayStr);
    final btList = (btResponse as List).cast<Map<String, dynamic>>();

    for (final bt in btList) {
      final requester = bt['employees'] as Map<String, dynamic>?;
      final requesterName = requester?['name'] ?? '알 수 없음';
      final requesterEmail = requester?['email'] ?? '';
      final destination = bt['trip_destination'] ?? '';
      final purpose = bt['trip_purpose'] ?? '';

      // 요청자 행 추가
      result.add({
        'id': 'bt_${bt['id']}',
        'user_email': requesterEmail,
        'name': requesterName,
        'type': 'biztrip',
        'start_date': bt['trip_start_date'],
        'end_date': bt['trip_end_date'],
        'reason': purpose,
        'place': destination,
        'status': 'approved',
        'is_business_trip': true,
      });

      // 동행자 각각 개별 행으로 추가 (is_companion 플래그로 구분)
      if (bt['companions'] != null && bt['companions'] is List) {
        for (final c in bt['companions']) {
          if (c is Map && c['name'] != null) {
            result.add({
              'id': 'bt_${bt['id']}_${c['id'] ?? c['name']}',
              'user_email': '',
              'name': c['name'].toString(),
              'type': 'biztrip',
              'start_date': bt['trip_start_date'],
              'end_date': bt['trip_end_date'],
              'reason': purpose,
              'place': destination,
              'status': 'approved',
              'is_business_trip': true,
              'is_companion': true,
            });
          }
        }
      }
    }

    return result;
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
