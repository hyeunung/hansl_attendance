import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// iOS 18 성능 최적화 유틸리티
class PerformanceOptimizer {
  static final _preloadedWidgets = <Type, Widget>{};
  
  /// 화면 전환 전 미리 렌더링
  static void preloadScreen(Widget screen) {
    if (!kDebugMode) return;
    
    final type = screen.runtimeType;
    if (!_preloadedWidgets.containsKey(type)) {
      // Debug code removed
      _preloadedWidgets[type] = screen;
    }
  }
  
  /// 캐시된 화면 가져오기
  static Widget? getCachedScreen(Type type) {
    return _preloadedWidgets[type];
  }
  
  /// 이미지 프리캐싱
  static Future<void> precacheImages(BuildContext context) async {
    final images = [
      'assets/images/logo.png',
      'assets/images/ic_launcher.png',
      // 필요한 이미지들 추가
    ];
    
    for (final image in images) {
      try {
        await precacheImage(AssetImage(image), context);
      } catch (e) {
        // 이미지가 없어도 계속 진행
      }
    }
  }
  
  /// 네비게이션 최적화
  static Future<T?> navigateWithPreload<T>({
    required BuildContext context,
    required Widget destination,
    bool replace = false,
  }) async {
    // 화면 프리로드
    preloadScreen(destination);
    
    // 약간의 지연으로 렌더링 준비
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (replace) {
      if (context.mounted) {
        return Navigator.pushReplacement<T, void>(
          context,
          PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
        );
      }
    } else {
      if (context.mounted) {
        return Navigator.push<T>(
          context,
          PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
        );
      }
    }
    return null;
  }
}