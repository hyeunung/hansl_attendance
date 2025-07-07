import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leave_request.dart';

class LeaveService {
  final _client = Supabase.instance.client;
  final String table = 'leave';

  // leave 전체 조회 (디버그/관리자용) - 외래키 관계 없이 별도 쿼리로 구현
  Future<List<Map<String, dynamic>>> fetchAllLeavesRaw() async {
    try {
      // 1. leave 데이터 조회
      final leaveResponse = await _client
        .from('leave')
        .select('*')
        .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> leaveList = (leaveResponse as List).cast<Map<String, dynamic>>();
      
      // 2. employees 데이터 조회
      final employeesResponse = await _client
        .from('employees')
        .select('email, name, role, is_admin, department');
      
      final List<Map<String, dynamic>> employeesList = (employeesResponse as List).cast<Map<String, dynamic>>();
      
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
      
      return leaveList;
    } catch (e) {
      print('fetchAllLeavesRaw error: $e');
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