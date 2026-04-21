import 'package:supabase_flutter/supabase_flutter.dart';

/// 전체 근태 관리 서비스 (HR/SuperAdmin 전용)
///
/// attendance_records + employees + leave + business_trips를 조합하여
/// 특정 날짜의 전 직원 근태 현황을 반환.
///
/// 웹앱 hanslworkspace의 employeeService.ts 로직을 Flutter로 이식.
class AdminAttendanceService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 특정 날짜의 전체 직원 근태 리스트 조회
  ///
  /// [date]: 조회 대상 날짜 (YYYY-MM-DD)
  ///
  /// Returns: 직원 정보 + 근태 기록 + 연차/출장 상태가 병합된 리스트
  Future<List<Map<String, dynamic>>> fetchAttendanceByDate(
    DateTime date,
  ) async {
    final dateStr = _formatDate(date);

    // 1. 활성 직원 전체 조회
    final employeesResponse = await _client
        .from('employees')
        .select('id, email, name, department, roles, position, is_active')
        .eq('is_active', true)
        .order('department')
        .order('name');

    final employees =
        (employeesResponse as List).cast<Map<String, dynamic>>();

    // 2. 해당 날짜의 attendance_records 조회
    final attendanceResponse = await _client
        .from('attendance_records')
        .select(
            'id, date, employee_id, employee_name, user_email, clock_in, clock_out, status, remarks, note, updated_at')
        .eq('date', dateStr);

    final attendanceRecords =
        (attendanceResponse as List).cast<Map<String, dynamic>>();

    // 3. 해당 날짜를 포함하는 승인된 leave 조회
    final leaveResponse = await _client
        .from('leave')
        .select('user_email, type, start_date, end_date, status')
        .eq('status', 'approved')
        .lte('start_date', dateStr)
        .gte('end_date', dateStr);

    final leaves = (leaveResponse as List).cast<Map<String, dynamic>>();

    // 4. 해당 날짜를 포함하는 승인된 business_trips 조회
    final biztripResponse = await _client
        .from('business_trips')
        .select(
            'requester_id, trip_start_date, trip_end_date, approval_status, companions')
        .inFilter('approval_status', ['approved', 'completed'])
        .lte('trip_start_date', dateStr)
        .gte('trip_end_date', dateStr);

    final biztrips =
        (biztripResponse as List).cast<Map<String, dynamic>>();

    // 5. 조합: 각 직원별로 매핑
    final attendanceByEmail = <String, Map<String, dynamic>>{};
    for (final rec in attendanceRecords) {
      final email = rec['user_email'] as String?;
      if (email != null) attendanceByEmail[email] = rec;
    }

    final leaveByEmail = <String, Map<String, dynamic>>{};
    for (final lv in leaves) {
      final email = lv['user_email'] as String?;
      if (email != null) leaveByEmail[email] = lv;
    }

    final biztripByRequesterId = <String, Map<String, dynamic>>{};
    for (final bt in biztrips) {
      final reqId = bt['requester_id'] as String?;
      if (reqId != null) biztripByRequesterId[reqId] = bt;
      // 동행자도 포함
      final companions = bt['companions'];
      if (companions is List) {
        for (final c in companions) {
          if (c is Map && c['id'] != null) {
            biztripByRequesterId[c['id'] as String] = bt;
          }
        }
      }
    }

    // 각 직원에 대해 근태 정보 조합
    final List<Map<String, dynamic>> result = [];
    for (final emp in employees) {
      final email = emp['email'] as String?;
      final empId = emp['id'] as String?;

      if (email == null) continue;

      final attendance = attendanceByEmail[email];
      final leave = leaveByEmail[email];
      final biztrip = empId != null ? biztripByRequesterId[empId] : null;

      // 상태 판정 로직
      String? computedStatus = attendance?['status'];
      String? clockIn = attendance?['clock_in'];
      String? clockOut = attendance?['clock_out'];

      // 수동 상태가 없을 때만 자동 판정
      if (computedStatus == null || computedStatus.isEmpty) {
        if (clockIn != null) {
          // 출근 시간 기준 정상/지각 판정 (08:30 기준, 아르바이트 09:00)
          final position = (emp['position'] ?? '') as String;
          final threshold = position.contains('아르바이트') ? '09:00' : '08:30';
          computedStatus = _compareTime(clockIn, threshold) > 0 ? '지각' : '정상 출근';
          if (clockOut != null) {
            computedStatus = '퇴근';
          }
        } else if (biztrip != null) {
          computedStatus = '출장';
        } else if (leave != null) {
          computedStatus = _leaveTypeToStatus(leave['type'] as String?);
        } else {
          computedStatus = '-';
        }
      }

      result.add({
        'attendance_id': attendance?['id'],
        'employee_id': empId,
        'employee_name': emp['name'],
        'email': email,
        'department': emp['department'],
        'position': emp['position'],
        'roles': emp['roles'],
        'date': dateStr,
        'clock_in': clockIn,
        'clock_out': clockOut,
        'status': computedStatus,
        'remarks': attendance?['remarks'],
        'note': attendance?['note'],
        'has_leave': leave != null,
        'leave_type': leave?['type'],
        'has_biztrip': biztrip != null,
        'updated_at': attendance?['updated_at'],
      });
    }

    return result;
  }

  /// 근태 기록 수정 (hr/superadmin 전용)
  ///
  /// [attendanceId]: attendance_records.id (신규 기록이면 null)
  /// [employeeId]: 직원 UUID
  /// [employeeName]: 직원 이름
  /// [userEmail]: 직원 이메일
  /// [date]: 근태 날짜
  /// [clockIn]/[clockOut]/[status]/[remarks]: 수정할 필드 (null이면 유지)
  ///
  /// 기존 기록이 없으면 INSERT, 있으면 UPDATE.
  Future<void> updateAttendanceRecord({
    int? attendanceId,
    required String employeeId,
    required String employeeName,
    required String userEmail,
    required String date,
    String? clockIn,
    String? clockOut,
    String? status,
    String? remarks,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final updateData = <String, dynamic>{
      'updated_at': now,
    };

    if (clockIn != null) updateData['clock_in'] = clockIn.isEmpty ? null : clockIn;
    if (clockOut != null) updateData['clock_out'] = clockOut.isEmpty ? null : clockOut;
    if (status != null) updateData['status'] = status.isEmpty ? null : status;
    if (remarks != null) updateData['remarks'] = remarks.isEmpty ? null : remarks;

    if (attendanceId != null) {
      // UPDATE 기존 기록
      await _client
          .from('attendance_records')
          .update(updateData)
          .eq('id', attendanceId);
    } else {
      // INSERT 신규 기록
      await _client.from('attendance_records').insert({
        ...updateData,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'user_email': userEmail,
        'date': date,
        'created_at': now,
      });
    }
  }

  // ========== Helpers ==========

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  /// "HH:MM" 형식 시간 비교. a > b면 양수
  int _compareTime(String a, String b) {
    return a.compareTo(b);
  }

  String _leaveTypeToStatus(String? type) {
    switch (type) {
      case 'annual':
        return '연차';
      case 'half_am':
        return '오전반차';
      case 'half_pm':
        return '오후반차';
      case 'official':
        return '공가';
      case 'biztrip':
        return '출장';
      default:
        return type ?? '-';
    }
  }
}
