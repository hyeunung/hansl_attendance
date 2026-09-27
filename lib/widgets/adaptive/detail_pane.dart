import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../shared/flat_section.dart';

/// 펼친 폴더블(폭 ≥ 840)에서 화면 오른쪽 절반을 차지하는 상세 패널의 상태.
///
/// 패널은 자체 [Navigator]를 가진다.
/// - 첫 라우트: 탭별 "주 작업"(연차 신청, 업로드 등) 또는 빈 상태
/// - 그 위 라우트: 왼쪽에서 항목을 탭했을 때의 상세
/// 패널 안 화면은 평소처럼 `Navigator.pop/push`, 바텀시트를 쓰면 패널 안에서 동작한다.
class DetailPaneController extends ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final Map<Type, WidgetBuilder> _primaryBuilders = {};

  Type? _currentScreen;
  int _primaryVersion = 0;
  Route<dynamic>? _activeRoute;
  WidgetBuilder? _activeBuilder;
  Object? _activeKey;

  Type? get currentScreen => _currentScreen;
  int get primaryVersion => _primaryVersion;
  bool get hasDetail => _activeRoute != null;
  Object? get detailKey => _activeKey;

  /// 탭 화면(runtimeType)별 주 작업 위젯 등록. 같은 타입은 덮어쓴다.
  void registerPrimary(Type screen, WidgetBuilder builder) {
    _primaryBuilders[screen] = builder;
  }

  WidgetBuilder? primaryFor(Type? screen) =>
      screen == null ? null : _primaryBuilders[screen];

  /// 탭 전환. 열려 있던 상세는 닫고 그 탭의 주 작업으로 돌아간다.
  /// build 중에 호출되므로 실제 반영은 프레임 이후로 미룬다.
  void setCurrentScreen(Type screen) {
    if (screen == _currentScreen) return;
    _currentScreen = screen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      closeDetail();
      notifyListeners();
    });
  }

  /// 주 작업이 보여주는 데이터가 바뀌었을 때 다시 그리게 한다.
  void refresh() => notifyListeners();

  /// 주 작업을 새로 만든다(신청 완료 후 폼 초기화 등).
  void resetPrimary() {
    _primaryVersion++;
    notifyListeners();
  }

  /// 상세를 패널에 띄운다. 이미 떠 있던 상세는 교체한다.
  /// 반환값은 그 상세가 닫힐 때의 결과(`Navigator.pop(context, result)`)다.
  Future<T?> showDetail<T>(WidgetBuilder builder, {Object? key}) {
    final nav = navigatorKey.currentState;
    if (nav == null) return Future<T?>.value(null);
    final route = MaterialPageRoute<T>(builder: builder);
    _activeRoute = route;
    _activeBuilder = builder;
    _activeKey = key;
    route.popped.whenComplete(() {
      if (identical(_activeRoute, route)) {
        _activeRoute = null;
        _activeBuilder = null;
        _activeKey = null;
        notifyListeners();
      }
    });
    final result = nav.pushAndRemoveUntil<T>(route, (r) => r.isFirst);
    notifyListeners();
    return result;
  }

  void closeDetail() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
  }

  /// 접힘 전환 시 오른쪽에 열려 있던 상세를 꺼낸다(전체 화면으로 이어 보여주기 위해).
  WidgetBuilder? takeDetail() {
    final builder = _activeBuilder;
    _activeRoute = null;
    _activeBuilder = null;
    _activeKey = null;
    return builder;
  }
}

/// 하위 화면에서 [DetailPaneController]를 찾기 위한 스코프.
class DetailPaneScope extends InheritedNotifier<DetailPaneController> {
  const DetailPaneScope({
    super.key,
    required DetailPaneController controller,
    required this.split,
    required super.child,
  }) : super(notifier: controller);

  /// 지금 좌/우 분할(펼침) 상태인지. 좌우 절반은 MediaQuery가 폰 폭으로 덮여 있어
  /// 화면 폭으로는 판별할 수 없으므로 스코프가 직접 들고 있는다.
  final bool split;

  @override
  bool updateShouldNotify(DetailPaneScope oldWidget) =>
      split != oldWidget.split || super.updateShouldNotify(oldWidget);

  static DetailPaneController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DetailPaneScope>()
      ?.notifier;

  static DetailPaneScope? _scope(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DetailPaneScope>();

  static DetailPaneController? _read(BuildContext context) =>
      _scope(context)?.notifier;

  /// 콜백(onTap 등) 안에서 컨트롤러가 필요할 때. 의존을 등록하지 않는다.
  static DetailPaneController? read(BuildContext context) => _read(context);

  /// 분할(펼침) 상태면 컨트롤러, 아니면 null. build에서 쓰면 상태 변화에 다시 그려진다.
  static DetailPaneController? expandedOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<DetailPaneScope>();
    return (scope != null && scope.split) ? scope.notifier : null;
  }
}

/// 화면 코드에서 시트/다이얼로그/화면 이동 대신 호출하는 진입점.
class DetailPane {
  DetailPane._();

  /// 펼침이면 오른쪽 패널에 [builder]를 띄우고, 아니면 [fallback](기존 시트·다이얼로그)을 실행한다.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required Future<T?> Function() fallback,
    Object? key,
  }) {
    final controller = _expanded(context);
    if (controller == null) return fallback();
    return controller.showDetail<T>(builder, key: key);
  }

  /// 화면 이동. 펼침이면 오른쪽 패널에, 아니면 기존처럼 전체 화면으로 push.
  static Future<T?> push<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    Object? key,
  }) {
    final controller = _expanded(context);
    if (controller == null) {
      return Navigator.push<T>(context, MaterialPageRoute<T>(builder: builder));
    }
    return controller.showDetail<T>(builder, key: key);
  }

  /// 다이얼로그/시트를 띄울 context.
  /// 분할(펼침) 상태면 오른쪽 패널의 Navigator context를, 아니면 받은 context를 돌려준다.
  /// `showDialog(context: DetailPane.hostContext(context), useRootNavigator: DetailPane.useRootNavigator(context))`
  /// 처럼 쓰면 펼침에서는 오른쪽 절반 안에, 폰에서는 기존과 동일하게 뜬다.
  static BuildContext hostContext(BuildContext context) =>
      _expanded(context)?.navigatorKey.currentContext ?? context;

  static bool useRootNavigator(BuildContext context) =>
      _expanded(context)?.navigatorKey.currentContext == null;

  /// 패널에 새 상세(다이얼로그/시트 포함)를 띄우기 전에 이전 것을 정리한다.
  static void clear(BuildContext context) {
    _expanded(context)?.closeDetail();
  }

  /// 오른쪽 패널에 떠 있는 상세를 닫는다.
  static void close(BuildContext context) {
    DetailPaneScope._read(context)?.closeDetail();
  }

  /// 이 위젯이 오른쪽 패널 안에서 그려지는 중인지.
  static bool isInside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DetailPaneHost>() != null;

  /// 화면을 닫는 공통 동작.
  /// - 패널의 주 작업(첫 라우트): 폼을 초기화
  /// - 그 외: 기존처럼 `Navigator.pop`(패널 상세면 패널 안에서 닫힘)
  static void popOrClose<T>(BuildContext context, [T? result]) {
    if (isInside(context) && !Navigator.canPop(context)) {
      DetailPaneScope._read(context)?.resetPrimary();
      return;
    }
    Navigator.pop(context, result);
  }

  static DetailPaneController? _expanded(BuildContext context) {
    // 패널 안에서 호출되면(상세에서 또 상세로) 같은 패널을 재사용한다.
    final scope = DetailPaneScope._scope(context);
    if (scope == null || !scope.split) return null;
    return scope.notifier;
  }
}

/// [DetailPaneView]가 자식 위에 심는 표식. 화면이 "패널 안"인지 판별하는 데 쓴다.
class DetailPaneHost extends InheritedWidget {
  const DetailPaneHost({super.key, required super.child});

  @override
  bool updateShouldNotify(DetailPaneHost oldWidget) => false;
}

/// 상세로 쓰이는 시트 본문(높이가 내용만큼인 Column)을 패널 한 장으로 감싼다.
class DetailPanePage extends StatelessWidget {
  const DetailPanePage({super.key, required this.child, this.scrollable = true});

  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: scrollable ? SingleChildScrollView(child: child) : child,
      ),
    );
  }
}

/// 오른쪽 절반에 그려지는 패널 본체.
class DetailPaneView extends StatelessWidget {
  const DetailPaneView({super.key, required this.controller});

  final DetailPaneController controller;

  @override
  Widget build(BuildContext context) {
    return DetailPaneHost(
      child: Navigator(
        key: controller.navigatorKey,
        onGenerateInitialRoutes: (_, __) => [
          MaterialPageRoute<void>(
            builder: (_) => _PrimaryHost(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _PrimaryHost extends StatelessWidget {
  const _PrimaryHost({required this.controller});

  final DetailPaneController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final primary = controller.primaryFor(controller.currentScreen);
        if (primary != null) {
          return KeyedSubtree(
            key: ValueKey(
              '${controller.currentScreen}#${controller.primaryVersion}',
            ),
            child: Builder(builder: primary),
          );
        }
        return const Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlatEmptyState(
                icon: Icons.touch_app_outlined,
                message: '왼쪽에서 항목을 선택하면 여기에 표시됩니다',
              ),
            ],
          ),
        );
      },
    );
  }
}
