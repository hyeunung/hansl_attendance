class Attendance {
  // 출퇴근 정보 필드 및 생성자 작성 예정
} 

class AttendanceRecord {
  final int? id;
  final DateTime date;
  final String employeeId;
  final String employeeName;
  final String? status;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isLate;

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

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int?,
      date: DateTime.parse(json['date']),
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      status: json['status'] as String?,
      clockIn: json['clock_in'] != null ? DateTime.parse('${json['date']}T${json['clock_in']}') : null,
      clockOut: json['clock_out'] != null ? DateTime.parse('${json['date']}T${json['clock_out']}') : null,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      isLate: json['is_late'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String().substring(0, 10),
      'employee_id': employeeId,
      'employee_name': employeeName,
      'status': status,
      'clock_in': clockIn != null ? clockIn!.toIso8601String().substring(11, 19) : null,
      'clock_out': clockOut != null ? clockOut!.toIso8601String().substring(11, 19) : null,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_late': isLate,
    };
  }
} 