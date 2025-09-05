import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_optimization_service.dart';

// 연차/출장 등 휴가 관련 DB 연동 서비스
class LeaveService {
  final _client = Supabase.instance.client;
  final String table = 'leave';

  // leave 전체 조회 - 달력용(approved) 또는 관리자용(전체)
  Future<List<Map<String, dynamic>>> fetchAllLeavesRaw({bool approvedOnly = false}) async {
    try {
      if (kDebugMode) {
        if (kDebugMode) print('🔍 fetchAllLeavesRaw 시작 - 최적화된 조회 (approvedOnly: $approvedOnly)');
      }

      // 현재 사용자의 이메일 가져오기
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          if (kDebugMode) print('❌ 인증되지 않은 사용자');
        }
        return [];
      }

      final userEmail = currentUser.email;
      if (userEmail == null) {
        if (kDebugMode) {
          if (kDebugMode) print('❌ 사용자 이메일이 없음');
        }
        return [];
      }

      if (kDebugMode) {
        if (kDebugMode) print('👤 현재 사용자: $userEmail');
      }

      // 달력용 승인된 데이터는 Edge Function으로 전체 조회 (RLS 우회)
      if (approvedOnly) {
        return await _fetchAllApprovedLeavesViaEdgeFunction();
      }

      // 관리자 화면용도 Edge Function으로 전체 조회 (RLS 우회)
      return await _fetchAllLeavesForApprovalViaEdgeFunction();
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ fetchAllLeavesRaw error: $e');
      }
      // 오류 발생 시 fallback 방식 사용
      return await _fetchAllLeavesRawFallback();
    }
  }

  // Edge Function으로 승인 화면용 전체 leave 조회 (RLS 우회)
  Future<List<Map<String, dynamic>>> _fetchAllLeavesForApprovalViaEdgeFunction() async {
    try {
      if (kDebugMode) {
        if (kDebugMode) print('🚀 Edge Function으로 승인 화면용 전체 leave 조회 시작');
      }

      const projectId = 'qvhbigvdfyvhoegkhvef';
      final functionUrl = 'https://$projectId.supabase.co/functions/v1/get_all_leaves_for_approval';

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_client.auth.currentSession?.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final leaves = List<Map<String, dynamic>>.from(responseData['data'] ?? []);

          if (kDebugMode) {
            if (kDebugMode) print('✅ Edge Function 성공 - 전체 leave: ${leaves.length}개');
            final pendingCount = leaves.where((l) => l['status'] == 'pending').length;
            if (kDebugMode) print('  - Pending: $pendingCount개');
            // 몇 명의 직원 데이터가 있는지 확인
            final uniqueEmails = leaves.map((l) => l['user_email']).toSet();
            if (kDebugMode) print('  - 총 ${uniqueEmails.length}명의 직원 데이터 포함');
          }

          return leaves;
        }
      }

      if (kDebugMode) {
        if (kDebugMode) print('⚠️ Edge Function 실패, fallback 사용');
      }
      // Edge Function 실패 시 기존 방식 사용
      return await _fetchAllLeavesRawFallback();
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ Edge Function 오류: $e, fallback 사용');
      }
      return await _fetchAllLeavesRawFallback();
    }
  }

  // Edge Function으로 전체 승인된 leave 조회 (RLS 우회)
  Future<List<Map<String, dynamic>>> _fetchAllApprovedLeavesViaEdgeFunction() async {
    try {
      if (kDebugMode) {
        if (kDebugMode) print('🚀 Edge Function으로 전체 승인된 leave 조회 시작');
      }

      const projectId = 'qvhbigvdfyvhoegkhvef';
      final functionUrl = 'https://$projectId.supabase.co/functions/v1/get_all_approved_leaves';

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_client.auth.currentSession?.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final leaves = List<Map<String, dynamic>>.from(responseData['data'] ?? []);

          if (kDebugMode) {
            if (kDebugMode) print('✅ Edge Function 성공 - 전체 직원 승인된 연차/출장: ${leaves.length}개');
            // 몇 명의 직원 데이터가 있는지 확인
            final uniqueEmails = leaves.map((l) => l['user_email']).toSet();
            if (kDebugMode) print('  - 총 ${uniqueEmails.length}명의 직원 데이터 포함');
          }

          return leaves;
        }
      }

      if (kDebugMode) {
        if (kDebugMode) print('⚠️ Edge Function 실패, fallback 사용');
      }
      // Edge Function 실패 시 기존 방식 사용
      return await _fetchAllLeavesRawFallback();
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ Edge Function 오류: $e, fallback 사용');
      }
      return await _fetchAllLeavesRawFallback();
    }
  }

  // Fallback 메서드 - 기존 방식 (RLS 제한 있음)
  Future<List<Map<String, dynamic>>> _fetchAllLeavesRawFallback() async {
    try {
      if (kDebugMode) {
        if (kDebugMode) print('🔍 fetchAllLeavesRaw Fallback 시작');
      }

      // 1. leave 데이터 조회
      final leaveResponse = await _client
          .from('leave')
          .select('*')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> leaveList = (leaveResponse as List)
          .cast<Map<String, dynamic>>();
      if (kDebugMode) {
        if (kDebugMode) print('📋 leave 테이블에서 조회된 데이터 수: ${leaveList.length}');
      }

      // 2. employees 데이터 조회
      final employeesResponse = await _client
          .from('employees')
          .select('email, name, role, is_admin, department');

      final List<Map<String, dynamic>> employeesList = (employeesResponse as List)
          .cast<Map<String, dynamic>>();
      if (kDebugMode) {
        if (kDebugMode) print('👥 employees 테이블에서 조회된 데이터 수: ${employeesList.length}');
      }

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
            'role': null,
            'is_admin': false,
            'department': null,
          };
        }
      }

      if (kDebugMode) {
        if (kDebugMode) print('✅ fetchAllLeavesRaw Fallback 완료 - 반환할 데이터 수: ${leaveList.length}');
      }
      return leaveList;
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ fetchAllLeavesRaw Fallback error: $e');
      }
      rethrow;
    }
  }

  // 내 leave 내역 조회
  Future<List<Map<String, dynamic>>> fetchMyLeavesRaw(String userEmail) async {
    final response = await _client.from(table).select('*').eq('user_email', userEmail);
    return (response as List).cast<Map<String, dynamic>>();
  }

  // leave 신청 (insert)
  Future<void> insertLeave(Map<String, dynamic> data) async {
    await _client.from(table).insert(data);

    // 캐시 무효화 - DatabaseOptimizationService 캐시도 클리어
    final dbOptim = DatabaseOptimizationService.instance;
    await dbOptim.invalidateCache(patterns: ['leave']);
    if (kDebugMode) {
      if (kDebugMode) print('✅ Leave 신청 완료 및 캐시 무효화: ${data['type']} - ${data['name']}');
    }
  }

  // leave 상태변경 (update) - Edge Function 사용 (RLS 우회)
  Future<void> updateLeaveStatus(int id, String status) async {
    try {
      if (kDebugMode) {
        if (kDebugMode) print('🔄 Leave 상태 업데이트 시작: ID=$id, Status=$status');
        final currentUser = _client.auth.currentUser;
        if (kDebugMode) print('📱 현재 사용자: ${currentUser?.email}');
        if (kDebugMode) print('🔑 세션 존재: ${_client.auth.currentSession != null}');
      }

      // Edge Function 호출 (Service Role로 RLS 우회)
      final response = await _client.functions.invoke(
        'update_leave_status',
        body: {'id': id, 'status': status},
      );

      // FunctionResponse는 data만 반환함
      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        throw Exception(responseData['error'] ?? 'Unknown error');
      }

      if (kDebugMode) {
        if (kDebugMode) print('✅ Edge Function 응답: ${responseData['message']}');
        if (kDebugMode) print('✅ DB 업데이트 결과: ${responseData['data']}');
      }

      // 캐시 무효화 - 상태 변경 시 관련된 모든 캐시를 클리어
      final dbOptim = DatabaseOptimizationService.instance;
      await dbOptim.invalidateCache(patterns: ['leave']);

      if (kDebugMode) {
        if (kDebugMode) print('✅ Leave 상태 변경 완료 및 캐시 무효화: ID=$id, Status=$status');
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ Leave 상태 업데이트 오류: $e');
      }
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
    final String summarizedReason = [
      '장소: ' + place,
      '목적: ' + purpose,
      '교통수단: ' + transport,
      if ((companions ?? '').trim().isNotEmpty) '동행: ' + (companions ?? ''),
    ].join('\n');

    final Map<String, dynamic> data = {
      'user_email': email,
      'name': name,
      'type': 'biztrip',
      'start_date': leaveDate,
      'end_date': leaveDate,
      'reason': summarizedReason,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    final inserted = await _client.from(table).insert(data).select().maybeSingle();

    // 캐시 무효화 - 출장 신청 후에도 캐시를 클리어해야 관리자 탭에 즉시 반영됨
    final dbOptim = DatabaseOptimizationService.instance;
    await dbOptim.invalidateCache(patterns: ['leave']);
    if (kDebugMode) {
      if (kDebugMode) print('✅ 출장 신청 완료 및 캐시 무효화: ${data['type']} - ${data['name']}');
    }

    if (inserted is Map<String, dynamic>) {
      return Map<String, dynamic>.from(inserted);
    }
    return null;
  }

  // 오늘자 leave (status=approved, 오늘 포함)
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

  // Edge Function을 통한 leave 삭제 (RLS 우회)
  Future<Map<String, dynamic>> deleteLeaveViaEdgeFunction({
    required int leaveId,
    String? userEmail,
    bool isAdmin = false,
  }) async {
    try {
      if (kDebugMode) {
        if (kDebugMode) print('🗑️ Edge Function을 통한 leave 삭제: ID=$leaveId, isAdmin=$isAdmin');
      }

      final response = await _client.functions.invoke(
        'delete_leave',
        body: {'leaveId': leaveId, 'userEmail': userEmail, 'isAdmin': isAdmin},
      );

      if (response.status != 200) {
        throw Exception('삭제 실패: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      if (kDebugMode) {
        if (kDebugMode) print('✅ Edge Function 삭제 응답: $data');
      }

      if (data['success'] != true) {
        throw Exception(data['message'] ?? '삭제 실패');
      }

      return data;
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ Edge Function 삭제 에러: $e');
      }
      rethrow;
    }
  }
}
