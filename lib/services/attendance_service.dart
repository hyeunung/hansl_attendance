import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_optimization_service.dart';

class AttendanceService {
  final supabase = Supabase.instance.client;
  final DatabaseOptimizationService _dbOptim =
      DatabaseOptimizationService.instance;

  Future<void> recordClockIn({
    required String employeeId,
    required String employeeName,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now().toIso8601String().substring(11, 19);

    try {
      await _dbOptim.optimizedInsert(
        table: 'attendance_records',
        data: {
          'date': today,
          'employee_id': employeeId,
          'employee_name': employeeName,
          'status': '출근',
          'clock_in': now,
        },
        invalidateCachePatterns: [
          'attendance_${employeeId}_$today',
          'attendance_${employeeId}_',
        ],
      );

      if (kDebugMode) {
        if (kDebugMode) {
          print('✅ recordClockIn completed with cache invalidation');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ recordClockIn error: $e');
      }
      rethrow;
    }
  }

  Future<void> recordClockOut({required String employeeId}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now().toIso8601String().substring(11, 19);

    try {
      await _dbOptim.optimizedUpdate(
        table: 'attendance_records',
        data: {'status': '퇴근', 'clock_out': now},
        match: {'date': today, 'employee_id': employeeId},
        invalidateCachePatterns: [
          'attendance_${employeeId}_$today',
          'attendance_${employeeId}_',
        ],
      );

      if (kDebugMode) {
        if (kDebugMode) {
          print('✅ recordClockOut completed with cache invalidation');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ recordClockOut error: $e');
      }
      rethrow;
    }
  }

  /// Get attendance records with optimized caching
  Future<List<Map<String, dynamic>>> getAttendanceHistory({
    required String employeeId,
    DateTime? date,
    int? limit,
  }) async {
    return await _dbOptim.getAttendanceRecords(
      employeeId,
      date: date,
      limit: limit,
      includeHistory: limit != null,
    );
  }

  /// Get today's attendance record with optimized caching
  Future<Map<String, dynamic>?> getTodayAttendance(String employeeId) async {
    final records = await _dbOptim.getAttendanceRecords(
      employeeId,
      date: DateTime.now(),
      limit: 1,
    );
    return records.isNotEmpty ? records.first : null;
  }
}
