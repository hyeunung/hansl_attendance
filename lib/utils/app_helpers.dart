import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// 앱 전체에서 사용하는 공통 헬퍼 클래스
class AppHelpers {
  AppHelpers._(); // private constructor to prevent instantiation
  
  // 자주 사용되는 UI 상수들
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultRadius = 12.0;
  static const double smallRadius = 8.0;
  static const double largeRadius = 16.0;
  
  /// Supabase 클라이언트 싱글톤
  static SupabaseClient get supabase => Supabase.instance.client;
  
  /// 현재 사용자
  static User? get currentUser => supabase.auth.currentUser;
  
  /// 현재 사용자 이메일
  static String? get currentUserEmail => currentUser?.email;
  
  /// 현재 시간을 ISO 8601 문자열로 변환
  static String get nowIso => DateTime.now().toIso8601String();
  
  /// 날짜만 ISO 형식으로 (YYYY-MM-DD)
  static String get todayIso => DateTime.now().toIso8601String().substring(0, 10);
  
  /// 날짜를 ISO 형식으로 변환
  static String dateToIso(DateTime date) => date.toIso8601String().substring(0, 10);
  
  /// 공통 로딩 인디케이터
  static Widget get loadingIndicator => const Center(
    child: CircularProgressIndicator(),
  );
  
  /// 공통 로딩 인디케이터 (색상 지정)
  static Widget loadingIndicatorWithColor(Color color) => Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(color),
    ),
  );
  
  /// 공통 구분선
  static Widget get divider => Container(
    height: 1,
    color: const Color(0xFFEEEEEE),
  );
  
  /// 공통 구분선 (두께 지정)
  static Widget dividerWithHeight(double height) => Container(
    height: height,
    color: const Color(0xFFEEEEEE),
  );
  
  /// 안전한 Navigator.pop
  static void safePop(BuildContext context, [dynamic result]) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }
  
  /// 공통 에러 다이얼로그
  static Future<void> showErrorDialog(
    BuildContext context,
    String message, {
    String title = '오류',
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  /// 공통 확인 다이얼로그
  static Future<bool> showConfirmDialog(
    BuildContext context,
    String message, {
    String title = '확인',
    String confirmText = '확인',
    String cancelText = '취소',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  
  /// 공통 스낵바 표시
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
      ),
    );
  }
  
  /// try-catch 래퍼
  static Future<T?> tryAsync<T>({
    required Future<T> Function() action,
    required void Function(dynamic error) onError,
    void Function()? onFinally,
  }) async {
    try {
      return await action();
    } catch (e) {
      onError(e);
      return null;
    } finally {
      onFinally?.call();
    }
  }
  
  /// 동기 try-catch 래퍼
  static T? trySync<T>({
    required T Function() action,
    required void Function(dynamic error) onError,
    void Function()? onFinally,
  }) {
    try {
      return action();
    } catch (e) {
      onError(e);
      return null;
    } finally {
      onFinally?.call();
    }
  }
  
  /// 디버그 로그 헬퍼
  static void log(String message) {
    // Debug code removed
  }
  
  /// 멀티라인 디버그 로그 헬퍼
  static void logMultiple(List<String> messages) {
    // Debug code removed
  }
  
  // 자주 사용되는 Spacing 위젯들
  static const Widget vSpace8 = SizedBox(height: 8);
  static const Widget vSpace16 = SizedBox(height: 16);
  static const Widget vSpace24 = SizedBox(height: 24);
  static const Widget vSpace32 = SizedBox(height: 32);
  
  static const Widget hSpace8 = SizedBox(width: 8);
  static const Widget hSpace16 = SizedBox(width: 16);
  static const Widget hSpace24 = SizedBox(width: 24);
  static const Widget hSpace32 = SizedBox(width: 32);
  
  // 자주 사용되는 Padding 위젯 생성
  static EdgeInsets get defaultPaddingAll => const EdgeInsets.all(defaultPadding);
  static EdgeInsets get smallPaddingAll => const EdgeInsets.all(smallPadding);
  static EdgeInsets get largePaddingAll => const EdgeInsets.all(largePadding);
  
  static EdgeInsets get defaultPaddingHorizontal => const EdgeInsets.symmetric(horizontal: defaultPadding);
  static EdgeInsets get defaultPaddingVertical => const EdgeInsets.symmetric(vertical: defaultPadding);
  
  // 자주 사용되는 BorderRadius
  static BorderRadius get defaultBorderRadius => BorderRadius.circular(defaultRadius);
  static BorderRadius get smallBorderRadius => BorderRadius.circular(smallRadius);
  static BorderRadius get largeBorderRadius => BorderRadius.circular(largeRadius);
}