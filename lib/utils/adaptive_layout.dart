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
}

/// 화면 크기에 따라 회전 허용을 바꾼다.
/// - 폰/접힌 폴더블(최소변 < 600): 세로 고정 (기존 동작 유지)
/// - 펼친 폴더블/태블릿(최소변 ≥ 600): 모든 방향 허용 → 가로형 내부 화면에서 앱이 눕지 않음
class AdaptiveOrientation extends StatefulWidget {
  const AdaptiveOrientation({super.key, required this.child});

  final Widget child;

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
  Widget build(BuildContext context) => widget.child;
}
