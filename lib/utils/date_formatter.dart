import 'package:intl/intl.dart';

/// 공통 날짜 포맷팅 유틸리티 클래스
class DateFormatter {
  // 날짜 포맷 상수
  static const String DATE_FORMAT_DOT = 'yyyy.MM.dd';
  static const String DATE_FORMAT_DASH = 'yyyy-MM-dd';
  static const String DATE_FORMAT_SLASH = 'yyyy/MM/dd';
  static const String DATE_TIME_FORMAT = 'yyyy.MM.dd HH:mm';
  static const String TIME_FORMAT = 'HH:mm';
  static const String MONTH_DAY_FORMAT = 'MM.dd';
  static const String KOREAN_DATE_FORMAT = 'yyyy년 MM월 dd일';
  
  // 날짜 포맷팅 메서드
  static String formatDate(DateTime date, {String format = DATE_FORMAT_DOT}) {
    return DateFormat(format).format(date);
  }
  
  static String formatDateWithDot(DateTime date) {
    return DateFormat(DATE_FORMAT_DOT).format(date);
  }
  
  static String formatDateWithDash(DateTime date) {
    return DateFormat(DATE_FORMAT_DASH).format(date);
  }
  
  static String formatDateTime(DateTime date) {
    return DateFormat(DATE_TIME_FORMAT).format(date);
  }
  
  static String formatTime(DateTime date) {
    return DateFormat(TIME_FORMAT).format(date);
  }
  
  static String formatKoreanDate(DateTime date) {
    return DateFormat(KOREAN_DATE_FORMAT).format(date);
  }
  
  static String formatMonthDay(DateTime date) {
    return DateFormat(MONTH_DAY_FORMAT).format(date);
  }
  
  /// 기간 문자열 생성 (시작일 ~ 종료일)
  static String formatPeriod(DateTime start, DateTime end, {String format = DATE_FORMAT_DOT}) {
    final startStr = DateFormat(format).format(start);
    final endStr = DateFormat(format).format(end);
    return '$startStr ~ $endStr';
  }
  
  /// 기간 문자열 생성 (일수 포함)
  static String formatPeriodWithDays(DateTime start, DateTime end, {String format = DATE_FORMAT_DOT}) {
    final days = end.difference(start).inDays + 1;
    return '${formatPeriod(start, end, format: format)} ($days일)';
  }
  
  /// 상대적 시간 표시 (몇 분 전, 몇 시간 전 등)
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}년 전';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}달 전';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}