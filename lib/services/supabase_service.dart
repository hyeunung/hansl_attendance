import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Supabase 연동 관련 메서드 작성 예정

  Future<String?> getEmployeeNameByEmail(String email) async {
    final response = await Supabase.instance.client
        .from('employees')
        .select('name')
        .eq('email', email)
        .single();
    if (response != null && response['name'] != null) {
      return response['name'] as String;
    }
    return null;
  }

  Future<List<String>> fetchEmployees() async {
    final response = await Supabase.instance.client
        .from('employees')
        .select('name');
    if (response is List) {
      return response.map((e) => e['name'] as String).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> getEmployeeByEmail(String email) async {
    final response = await Supabase.instance.client
        .from('employees')
        .select('*')
        .eq('email', email)
        .single();
    if (response != null && response['email'] != null) {
      return response as Map<String, dynamic>;
    }
    return null;
  }

  /// 현재 로그인한 사용자의 role과 is_admin 값을 조회합니다.
  Future<Map<String, dynamic>> loadUserRole() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }
    final response = await Supabase.instance.client
        .from('employees')
        .select('role, is_admin')
        .eq('id', userId)
        .single();

    if (response == null || response['role'] == null || response['is_admin'] == null) {
      throw Exception('역할 조회 실패: 데이터가 없습니다.');
    }
    return {
      'role': response['role'] as String,
      'isAdmin': response['is_admin'] as bool,
    };
  }
} 