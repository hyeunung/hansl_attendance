import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceService {
  final supabase = Supabase.instance.client;

  Future<void> recordClockIn({
    required String employeeId,
    required String employeeName,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now().toIso8601String().substring(11, 19);
    try {
      final res = await supabase
          .from('attendance_records')
          .insert({
        'date': today,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'status': '출근',
        'clock_in': now,
      });
      print('recordClockIn insert result: $res');
    } catch (e) {
      print('recordClockIn error: $e');
      rethrow;
    }
  }

  Future<void> recordClockOut({
    required String employeeId,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now().toIso8601String().substring(11, 19);
    try {
      final res = await supabase
          .from('attendance_records')
          .update({
        'status': '퇴근',
        'clock_out': now,
      }).match({
        'date': today,
        'employee_id': employeeId,
      });
      print('recordClockOut update result: $res');
    } catch (e) {
      print('recordClockOut error: $e');
      rethrow;
    }
  }

  // 출퇴근 관련 메서드 작성 예정
}