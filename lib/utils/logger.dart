import 'package:flutter/foundation.dart';

/// 앱 전체에서 사용할 로깅 유틸리티
/// 프로덕션에서는 자동으로 비활성화됨
class AppLogger {
  static const String _tag = 'HANSL';

  // 로그 레벨
  static const int _levelDebug = 0;
  static const int _levelInfo = 1;
  static const int _levelWarning = 2;
  static const int _levelError = 3;

  // 현재 로그 레벨 (프로덕션에서는 WARNING 이상만)
  static int get _currentLevel => kDebugMode ? _levelDebug : _levelWarning;

  /// 디버그 로그 (개발 모드에서만 출력)
  static void debug(String message, [dynamic data]) {
    if (_currentLevel <= _levelDebug) {
      _log('DEBUG', message, data);
    }
  }

  /// 정보 로그
  static void info(String message, [dynamic data]) {
    if (_currentLevel <= _levelInfo) {
      _log('INFO', message, data);
    }
  }

  /// 경고 로그
  static void warning(String message, [dynamic data]) {
    if (_currentLevel <= _levelWarning) {
      _log('WARNING', message, data);
    }
  }

  /// 에러 로그
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_currentLevel <= _levelError) {
      _log('ERROR', message, error);
      if (stackTrace != null && kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  /// 네트워크 요청 로그 (개발 모드에서만)
  static void network(String method, String url, [dynamic data]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[$_tag] [$timestamp] [NETWORK] $method $url');
      if (data != null) {
        debugPrint('  └─ Data: $data');
      }
    }
  }

  /// 성능 측정 로그
  static void performance(String operation, Duration duration) {
    if (kDebugMode) {
      final ms = duration.inMilliseconds;
      final level = ms > 1000
          ? 'SLOW'
          : ms > 500
          ? 'MODERATE'
          : 'FAST';
      debugPrint('[$_tag] [PERFORMANCE] [$level] $operation took ${ms}ms');
    }
  }

  // 실제 로그 출력
  static void _log(String level, String message, [dynamic data]) {
    if (!kDebugMode && level != 'ERROR' && level != 'WARNING') {
      return; // 프로덕션에서는 ERROR와 WARNING만 출력
    }

    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$_tag] [$timestamp] [$level] $message');

    if (data != null) {
      final dataStr = data.toString();
      if (dataStr.length > 500) {
        debugPrint('  └─ Data: ${dataStr.substring(0, 500)}...');
      } else {
        debugPrint('  └─ Data: $dataStr');
      }
    }
  }

  /// 민감한 정보 마스킹
  static String maskSensitive(String value, {int visibleChars = 3}) {
    if (value.length <= visibleChars) {
      return '*' * value.length;
    }
    final visible = value.substring(0, visibleChars);
    final masked = '*' * (value.length - visibleChars);
    return '$visible$masked';
  }
}
