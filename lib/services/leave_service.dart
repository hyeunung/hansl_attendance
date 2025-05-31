import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leave_request.dart';

class LeaveService {
  final _client = Supabase.instance.client;
  final String table = 'leave';

  // leave 전체 조회 (디버그/관리자용)
  Future<List<Map<String, dynamic>>> fetchAllLeavesRaw() async {
    final response = await _client
      .from('leave')
      .select('*, employees!inner(name, email, role, is_admin, department)')
      .order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
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