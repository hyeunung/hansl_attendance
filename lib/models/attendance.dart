// 출퇴근(근태) 데이터 모델 정의
class Attendance {
  // 출퇴근 정보 필드 및 생성자 작성 예정
} 

// 한 번의 출근/퇴근 기록을 나타내는 클래스
class AttendanceRecord {
  final int? id; // 고유 ID(옵션)
  final DateTime date; // 날짜(yyyy-MM-dd)
  final String employeeId; // 직원 ID
  final String employeeName; // 직원 이름
  final String? status; // 상태(정상 출근, 지각, 퇴근 등)
  final DateTime? clockIn; // 출근 시간
  final DateTime? clockOut; // 퇴근 시간
  final String? note; // 메모
  final DateTime? createdAt; // 생성일
  final DateTime? updatedAt; // 수정일
  final bool isLate; // 지각 여부

  AttendanceRecord({
    this.id,
    required this.date,
    required this.employeeId,
    required this.employeeName,
    this.status,
    this.clockIn,
    this.clockOut,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.isLate = false,
  });

  // Map(JSON)에서 AttendanceRecord 객체로 변환
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int?,
      date: DateTime.parse(json['date']),
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      status: json['status'] as String?,
      clockIn: json['clock_in'] != null
          ? DateTime.parse('${json['date']}T${json['clock_in']}')
          : null,
      clockOut: json['clock_out'] != null
          ? DateTime.parse('${json['date']}T${json['clock_out']}')
          : null,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isLate: json['is_late'] == true,
    );
  }

  // AttendanceRecord 객체를 Map(JSON)으로 변환
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String().substring(0, 10),
      'employee_id': employeeId,
      'employee_name': employeeName,
      'status': status,
      'clock_in': clockIn?.toIso8601String().substring(11, 19),
      'clock_out': clockOut?.toIso8601String().substring(11, 19),
      'note': note,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_late': isLate,
    };
  }
}
