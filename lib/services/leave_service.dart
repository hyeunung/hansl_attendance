import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leave_request.dart';

// 연차/출장 등 휴가 관련 DB 연동 서비스
class LeaveService {
  final _client = Supabase.instance.client;
  final String table = 'leave';

  // leave 전체 조회 (달력용) - 모든 사용자가 승인된 연차/출장 조회 가능
  Future<List<Map<String, dynamic>>> fetchAllLeavesRaw() async {
    try {
      print('🔍 fetchAllLeavesRaw 시작 - 승인된 연차/출장만 조회');
      
      // 현재 사용자의 이메일 가져오기
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        print('❌ 인증되지 않은 사용자');
        return [];
      }
      
      final userEmail = currentUser.email;
      if (userEmail == null) {
        print('❌ 사용자 이메일이 없음');
        return [];
      }
      
      print('👤 현재 사용자: $userEmail');
      
      // 모든 사용자가 승인된 연차/출장 + 본인의 모든 신청 조회 가능
      final response = await _client
        .from('leave')
        .select('*')
        .or('user_email.eq.$userEmail,status.eq.approved')
        .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> leaveList = (response as List).cast<Map<String, dynamic>>();
      print('📋 leave 테이블에서 조회된 데이터 수: ${leaveList.length}');
      
      // employees 데이터 조회 및 결합
      final employeesResponse = await _client
        .from('employees')
        .select('email, name, role, is_admin, department');
      
      final List<Map<String, dynamic>> employeesList = (employeesResponse as List).cast<Map<String, dynamic>>();
      
      // 이메일을 기준으로 데이터 결합
      final Map<String, Map<String, dynamic>> employeesMap = {};
      for (final emp in employeesList) {
        if (emp['email'] != null) {
          employeesMap[emp['email']] = emp;
        }
      }
      
      // leave 데이터에 employee 정보 추가
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
      
      print('✅ fetchAllLeavesRaw 완료 - 반환할 데이터 수: ${leaveList.length}');
      return leaveList;
    } catch (e) {
      print('❌ fetchAllLeavesRaw error: $e');
      // 오류 발생 시 fallback 방식 사용
      return await _fetchAllLeavesRawFallback();
    }
  }

  // Fallback 메서드 - 기존 방식 (RLS 제한 있음)
  Future<List<Map<String, dynamic>>> _fetchAllLeavesRawFallback() async {
    try {
      print('🔍 fetchAllLeavesRaw Fallback 시작');
      
      // 1. leave 데이터 조회
      final leaveResponse = await _client
        .from('leave')
        .select('*')
        .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> leaveList = (leaveResponse as List).cast<Map<String, dynamic>>();
      print('📋 leave 테이블에서 조회된 데이터 수: ${leaveList.length}');
      
      // 2. employees 데이터 조회
      final employeesResponse = await _client
        .from('employees')
        .select('email, name, role, is_admin, department');
      
      final List<Map<String, dynamic>> employeesList = (employeesResponse as List).cast<Map<String, dynamic>>();
      print('👥 employees 테이블에서 조회된 데이터 수: ${employeesList.length}');
      
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
      
      print('✅ fetchAllLeavesRaw Fallback 완료 - 반환할 데이터 수: ${leaveList.length}');
      return leaveList;
    } catch (e) {
      print('❌ fetchAllLeavesRaw Fallback error: $e');
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

  // leave 신청 (insert)
  Future<void> insertLeave(Map<String, dynamic> data) async {
    await _client.from(table).insert(data);
  }

  // leave 상태변경 (update)
  Future<void> updateLeaveStatus(int id, String status) async {
    await _client.from(table).update({'status': status}).eq('id', id);
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
}
