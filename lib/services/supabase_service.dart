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
} 