// 연차/반차 등 휴가 유형을 정의하는 enum
// 출장(biztrip)은 business_trips 테이블로 이관되어 제거됨
enum LeaveType { annual, halfAm, halfPm, official, adjust }

extension LeaveTypeExtension on LeaveType {
  // 화면에 보여줄 한글 라벨
  String get label {
    switch (this) {
      case LeaveType.annual:
        return '연차';
      case LeaveType.halfAm:
        return '오전반차';
      case LeaveType.halfPm:
        return '오후반차';
      case LeaveType.official:
        return '공가';
      case LeaveType.adjust:
        return '수동조정';
    }
  }

  double get days {
    switch (this) {
      case LeaveType.annual:
        return 1.0;
      case LeaveType.halfAm:
      case LeaveType.halfPm:
        return 0.5;
      case LeaveType.official:
        return 0.0;
      case LeaveType.adjust:
        return 0.0; // 실제 조정값은 reason 등에서 별도 처리
    }
  }

  static LeaveType fromString(String value) {
    switch (value) {
      case 'annual':
        return LeaveType.annual;
      case 'half_am':
        return LeaveType.halfAm;
      case 'half_pm':
        return LeaveType.halfPm;
      case 'official':
        return LeaveType.official;
      case 'adjust':
        return LeaveType.adjust;
      default:
        throw Exception('Unknown leave type: $value');
    }
  }

  // DB에 저장할 때 사용하는 문자열 값
  String get dbValue {
    switch (this) {
      case LeaveType.annual:
        return 'annual';
      case LeaveType.halfAm:
        return 'half_am';
      case LeaveType.halfPm:
        return 'half_pm';
      case LeaveType.official:
        return 'official';
      case LeaveType.adjust:
        return 'adjust';
    }
  }
}

// 연차/출장 등 휴가 신청 정보를 담는 데이터 모델
class LeaveRequest {
  final int id; // 고유 ID
  final String userEmail; // 신청자 이메일
  final LeaveType type; // 휴가 유형
  final DateTime startDate; // 시작 날짜
  final DateTime endDate; // 종료 날짜
  final String? reason; // 사유(메모)
  final String status; // 상태: pending, approved, rejected
  final DateTime createdAt; // 신청 생성일
  final String? name; // 직원 이름 (join 결과)

  LeaveRequest({
    required this.id,
    required this.userEmail,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.reason,
    required this.status,
    required this.createdAt,
    this.name,
  });

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      id: map['id'] as int,
      userEmail: map['user_email'] as String,
      type: LeaveType.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (map['type'] as String).replaceAll('_', ''),
      ),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      reason: map['reason'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      name: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_email': userEmail,
      'type': type.dbValue,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'reason': reason,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      // name은 insert/update에 사용하지 않음
    };
  }
}
