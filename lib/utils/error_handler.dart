import 'package:flutter/material.dart';
import 'logger.dart';

/// 전역 에러 처리 유틸리티
class ErrorHandler {
  /// 에러 타입별 처리
  static Future<void> handleError(
    BuildContext context,
    dynamic error, {
    StackTrace? stackTrace,
    String? userMessage,
    bool showSnackBar = true,
  }) async {
    // 로깅
    AppLogger.error('에러 발생', error, stackTrace);

    // 사용자 메시지 결정
    final message = userMessage ?? _getErrorMessage(error);

    // UI 피드백
    if (showSnackBar && context.mounted) {
      _showErrorSnackBar(context, message);
    }

    // 특별 처리가 필요한 에러
    if (_isNetworkError(error)) {
      await _handleNetworkError(context);
    } else if (_isAuthError(error)) {
      await _handleAuthError(context);
    }
  }

  /// 에러 메시지 생성
  static String _getErrorMessage(dynamic error) {
    if (error == null) {
      return '알 수 없는 오류가 발생했습니다.';
    }

    final errorStr = error.toString().toLowerCase();

    // 네트워크 에러
    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout')) {
      return '네트워크 연결을 확인해주세요.';
    }

    // 인증 에러
    if (errorStr.contains('auth') ||
        errorStr.contains('permission') ||
        errorStr.contains('unauthorized')) {
      return '인증이 필요합니다. 다시 로그인해주세요.';
    }

    // 서버 에러
    if (errorStr.contains('500') || errorStr.contains('server')) {
      return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }

    // 유효성 에러
    if (errorStr.contains('validation') || errorStr.contains('invalid')) {
      return '입력한 정보를 다시 확인해주세요.';
    }

    // 기본 메시지
    return '오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
  }

  /// 네트워크 에러 확인
  static bool _isNetworkError(dynamic error) {
    if (error == null) return false;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout');
  }

  /// 인증 에러 확인
  static bool _isAuthError(dynamic error) {
    if (error == null) return false;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('auth') ||
        errorStr.contains('permission') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('401') ||
        errorStr.contains('403');
  }

  /// 네트워크 에러 처리
  static Future<void> _handleNetworkError(BuildContext context) async {
    // 네트워크 상태 확인 로직
    AppLogger.warning('네트워크 에러 감지됨');

    // 재시도 옵션 제공
    if (context.mounted) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('네트워크 오류'),
          content: const Text('인터넷 연결을 확인해주세요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('재시도')),
          ],
        ),
      );

      if (retry == true) {
        // 재시도 로직 구현
        AppLogger.info('네트워크 재시도 요청');
      }
    }
  }

  /// 인증 에러 처리
  static Future<void> _handleAuthError(BuildContext context) async {
    AppLogger.warning('인증 에러 감지됨');

    if (context.mounted) {
      // 로그인 화면으로 이동
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('인증 만료'),
          content: const Text('세션이 만료되었습니다. 다시 로그인해주세요.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                // 로그인 화면으로 이동 로직
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  /// 에러 스낵바 표시
  static void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '닫기',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Try-Catch 래퍼
  static Future<T?> tryAsync<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    String? errorMessage,
    bool showError = true,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      await handleError(
        context,
        e,
        stackTrace: stackTrace,
        userMessage: errorMessage,
        showSnackBar: showError,
      );
      return null;
    }
  }

  /// 동기 Try-Catch 래퍼
  static T? trySync<T>({
    required T Function() operation,
    required BuildContext context,
    String? errorMessage,
    bool showError = true,
  }) {
    try {
      return operation();
    } catch (e, stackTrace) {
      handleError(
        context,
        e,
        stackTrace: stackTrace,
        userMessage: errorMessage,
        showSnackBar: showError,
      );
      return null;
    }
  }
}
