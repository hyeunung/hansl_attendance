import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 폼팩터 구간. 폴더블 펼침(Fold 8 933×704dp, iPhone Duo 951×669pt)은 expanded.
enum LayoutClass { compact, medium, expanded }

class AdaptiveLayout {
  AdaptiveLayout._();

  /// 이 값 이상의 최소변(shortestSide)이면 가로 회전을 허용한다.
  static const double rotatableShortestSide = 600;

  /// 이 값 이상의 폭이면 좌/우 분할(펼침) 레이아웃을 쓴다.
  static const double expandedMinWidth = 840;

  static LayoutClass classOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= expandedMinWidth) return LayoutClass.expanded;
    if (width >= 600) return LayoutClass.medium;
    return LayoutClass.compact;
  }

  static bool isExpanded(BuildContext context) =>
      classOf(context) == LayoutClass.expanded;

  /// 접힌 폴더블의 커버 화면인지 (Fold8 475×751dp, iPhone Duo 466×678pt).
  ///
  /// 커버 화면은 일반 폰보다 넓고 짧다(가로÷세로 0.63~0.69, 일반 폰은 0.45~0.47).
  /// 세로 공간이 부족하므로 네비게이션 바를 하단 대신 오른쪽 세로로 둔다.
  static const double coverMinWidth = 440;
  static const double coverMinAspect = 0.58;

  static bool isFoldableCover(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width >= 600 || size.height <= size.width) return false;
    return size.width >= coverMinWidth &&
        size.width / size.height >= coverMinAspect;
  }
}

/// 화면 크기에 따라 회전 허용을 바꾼다.
/// - 폰/접힌 폴더블(최소변 < 600): 세로 고정 (기존 동작 유지)
/// - 펼친 폴더블/태블릿(최소변 ≥ 600): 모든 방향 허용 → 가로형 내부 화면에서 앱이 눕지 않음
class AdaptiveOrientation extends StatefulWidget {
  const AdaptiveOrientation({super.key, required this.child});

  final Widget child;

  /// Dart에서 화면 방향을 직접 제어하는 플랫폼인지.
  /// iOS는 AppDelegate(`supportedInterfaceOrientationsFor`)가 담당한다.
  static bool get controlsOrientation =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  @override
  State<AdaptiveOrientation> createState() => _AdaptiveOrientationState();
}

class _AdaptiveOrientationState extends State<AdaptiveOrientation>
    with WidgetsBindingObserver {
  bool? _rotatable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _apply();

  void _apply() {
    if (!AdaptiveOrientation.controlsOrientation) return;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final view = views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    final rotatable =
        logical.shortestSide >= AdaptiveLayout.rotatableShortestSide;
    if (rotatable == _rotatable) return;
    _rotatable = rotatable;
    SystemChrome.setPreferredOrientations(
      rotatable
          ? const []
          : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
  }

  @override
  Widget build(BuildContext context) => _SideCutoutFix(child: widget.child);
}

/// 세로로 든 폰에서 카메라 구멍이 "옆 안전영역"으로 보고되는 기기 보정
/// (iPhone Duo 외부 화면: top 0 / right 84).
///
/// 그대로 두면 SafeArea·AppBar·하단 탭이 전부 한쪽으로 밀려 화면이 쏠려 보인다.
/// 카메라는 우상단 모서리에만 있으므로:
/// - 좌우 인셋은 0으로 (본문·하단 탭은 전체 폭 사용)
/// - 위 인셋은 최소 [_minTop]으로 (본문 첫 줄이 카메라 아래에서 시작)
/// - AppBar의 actions만 카메라 폭만큼 안쪽으로 (제목은 화면 중앙 유지)
class _SideCutoutFix extends StatelessWidget {
  const _SideCutoutFix({required this.child});

  final Widget child;

  static const double _minSideInset = 40;
  static const double _minTop = 10;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final left = mq.padding.left;
    final right = mq.padding.right;
    final isPortraitPhone = mq.size.height > mq.size.width &&
        mq.size.shortestSide < AdaptiveLayout.rotatableShortestSide;
    final hasSideCutout = left >= _minSideInset || right >= _minSideInset;
    if (!isPortraitPhone || !hasSideCutout || mq.padding.top >= 20) {
      return child;
    }

    final top = mq.padding.top < _minTop ? _minTop : mq.padding.top;
    final theme = Theme.of(context);
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(left: 0, right: 0, top: top),
        viewPadding: mq.viewPadding.copyWith(left: 0, right: 0, top: top),
      ),
      child: Theme(
        data: theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(
            actionsPadding: EdgeInsets.only(left: left, right: right),
          ),
        ),
        child: child,
      ),
    );
  }
}
