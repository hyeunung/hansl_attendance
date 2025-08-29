import '../../models/leave_request.dart';

/// 연차/출장 신청 관련 검증 로직
class LeaveValidators {
  // 이메일 검증 정규식
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // SQL Injection 방지를 위한 특수문자 패턴
  static final RegExp _sqlInjectionPattern = RegExp(
    r"[';\\-]|(\b(DROP|DELETE|INSERT|UPDATE|SELECT|FROM|WHERE)\b)",
    caseSensitive: false,
  );

  // XSS 방지를 위한 HTML 태그 패턴
  static final RegExp _htmlTagPattern = RegExp(r'<[^>]*>|&[^;]+;');

  /// 이메일 검증
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return '이메일을 입력해주세요';
    }
    if (!_emailRegExp.hasMatch(email)) {
      return '올바른 이메일 형식이 아닙니다';
    }
    return null;
  }

  /// 사유 검증 (XSS, SQL Injection 방지)
  static String? validateMemo(String? memo, {bool isRequired = true}) {
    if (isRequired && (memo == null || memo.trim().isEmpty)) {
      return '사유를 입력해주세요';
    }

    if (memo != null && memo.isNotEmpty) {
      // 길이 체크
      if (memo.length > 500) {
        return '사유는 500자 이내로 입력해주세요';
      }

      // SQL Injection 패턴 체크
      if (_sqlInjectionPattern.hasMatch(memo)) {
        return '사용할 수 없는 문자가 포함되어 있습니다';
      }

      // HTML 태그 체크
      if (_htmlTagPattern.hasMatch(memo)) {
        return 'HTML 태그는 사용할 수 없습니다';
      }
    }

    return null;
  }

  /// 날짜 선택 검증
  static String? validateDates(Map<LeaveType, Set<DateTime>> selectedDates) {
    // 최소 1일 선택 확인
    bool hasSelection = false;
    for (var dates in selectedDates.values) {
      if (dates.isNotEmpty) {
        hasSelection = true;
        break;
      }
    }

    if (!hasSelection) {
      return '최소 1일 이상 선택해주세요';
    }

    // 미래 날짜만 선택 가능 (오늘 포함)
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (var dates in selectedDates.values) {
      for (var date in dates) {
        if (date.isBefore(todayOnly)) {
          return '과거 날짜는 선택할 수 없습니다';
        }
      }
    }

    // 최대 연속 신청 일수 체크 (30일)
    for (var dates in selectedDates.values) {
      if (dates.isNotEmpty) {
        final sortedDates = dates.toList()..sort();
        final firstDate = sortedDates.first;
        final lastDate = sortedDates.last;

        if (lastDate.difference(firstDate).inDays > 30) {
          return '한 번에 최대 30일까지만 신청 가능합니다';
        }
      }
    }

    return null;
  }

  /// 출장지 검증
  static String? validatePlace(String? place) {
    if (place == null || place.trim().isEmpty) {
      return '출장지를 입력해주세요';
    }

    if (place.length > 100) {
      return '출장지는 100자 이내로 입력해주세요';
    }

    // SQL Injection 방지
    if (_sqlInjectionPattern.hasMatch(place)) {
      return '사용할 수 없는 문자가 포함되어 있습니다';
    }

    return null;
  }

  /// 업무 내용 검증
  static String? validatePurpose(String? purpose) {
    if (purpose == null || purpose.trim().isEmpty) {
      return '업무 내용을 입력해주세요';
    }

    // 10자 제한 제거 - 짧은 내용도 가능하도록

    if (purpose.length > 1000) {
      return '업무 내용은 1000자 이내로 입력해주세요';
    }

    // SQL Injection 방지
    if (_sqlInjectionPattern.hasMatch(purpose)) {
      return '사용할 수 없는 문자가 포함되어 있습니다';
    }

    return null;
  }

  /// 입력값 정제 (sanitize)
  static String sanitizeInput(String input) {
    // HTML 태그 제거
    String sanitized = input.replaceAll(_htmlTagPattern, '');

    // 앞뒤 공백 제거
    sanitized = sanitized.trim();

    // 연속된 공백을 하나로
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    return sanitized;
  }

  /// 연차 잔여일수 검증
  static String? validateRemainingDays(double remaining, double requested) {
    if (requested > remaining) {
      return '신청 가능한 연차가 부족합니다 (잔여: ${remaining}일)';
    }
    return null;
  }
}
