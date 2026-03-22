import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_optimization_service.dart';

class SupabaseService {
  final DatabaseOptimizationService _dbOptim =
      DatabaseOptimizationService.instance;

  /// Get employee name by email with optimized caching
  Future<String?> getEmployeeNameByEmail(String email) async {
    final employee = await _dbOptim.getEmployeeByEmail(
      email,
      selectFields: ['name'],
      cacheKey: 'employee_name',
    );
    return employee?['name'] as String?;
  }

  /// Fetch all employee names with caching
  Future<List<String>> fetchEmployees() async {
    final response = await Supabase.instance.client
        .from('employees')
        .select('name');
    return response.map((e) => e['name'] as String).toList();
  }

  /// Get complete employee data by email with optimized caching
  Future<Map<String, dynamic>?> getEmployeeByEmail(String email) async {
    return await _dbOptim.getEmployeeByEmail(email);
  }

  /// Get current user role and admin status with optimized caching
  Future<Map<String, dynamic>> loadUserRole() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    final roleData = await _dbOptim.getEmployeeRole(userId);

    if (roleData == null) {
      throw Exception('역할 조회 실패: 데이터가 없습니다.');
    }

    return {
      'department': roleData['department'],
      'roles': roleData['roles'],
      'attendance_role': roleData['attendance_role'],
      'purchase_role': roleData['purchase_role'],
    };
  }
}
