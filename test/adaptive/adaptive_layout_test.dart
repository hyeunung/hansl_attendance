import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hansl/providers/font_provider.dart';
import 'package:hansl/utils/adaptive_layout.dart';
import 'package:hansl/widgets/adaptive/detail_pane.dart';

/// 주어진 MediaQuery 값으로 AdaptiveOrientation 아래의 padding / AppBar actionsPadding을 읽는다.
Future<({EdgeInsets padding, EdgeInsetsGeometry? actionsPadding})> _probe(
  WidgetTester tester,
  MediaQueryData data,
) async {
  late EdgeInsets padding;
  EdgeInsetsGeometry? actionsPadding;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: data,
        child: AdaptiveOrientation(child: child!),
      ),
      home: Builder(
        builder: (context) {
          padding = MediaQuery.paddingOf(context);
          actionsPadding = Theme.of(context).appBarTheme.actionsPadding;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (padding: padding, actionsPadding: actionsPadding);
}

void main() {
  group('AdaptiveLayout 구간 판정', () {
    Future<LayoutClass> classAt(WidgetTester tester, double width) async {
      late LayoutClass result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 700)),
          child: Builder(
            builder: (context) {
              result = AdaptiveLayout.classOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('일반 폰·접힌 폴더블은 compact', (tester) async {
      expect(await classAt(tester, 402), LayoutClass.compact); // iPhone 17 Pro
      expect(await classAt(tester, 466), LayoutClass.compact); // iPhone Duo 외부
      expect(await classAt(tester, 475), LayoutClass.compact); // Fold8 접힘
    });

    testWidgets('펼친 폴더블은 expanded', (tester) async {
      expect(await classAt(tester, 933), LayoutClass.expanded); // Fold8 펼침
      expect(await classAt(tester, 951), LayoutClass.expanded); // iPhone Duo 펼침
    });
  });

  group('옆 카메라 구멍 보정 (iPhone Duo 외부 화면)', () {
    testWidgets('top 0 / right 84 → 좌우 0, 위 10, actions만 84 안쪽', (
      tester,
    ) async {
      final r = await _probe(
        tester,
        const MediaQueryData(
          size: Size(466, 678),
          padding: EdgeInsets.only(right: 84, bottom: 34),
          viewPadding: EdgeInsets.only(right: 84, bottom: 34),
        ),
      );
      expect(r.padding.left, 0);
      expect(r.padding.right, 0);
      expect(r.padding.top, 10);
      expect(r.padding.bottom, 34);
      expect(r.actionsPadding, const EdgeInsets.only(right: 84));
    });

    testWidgets('일반 아이폰(위 인셋 있음, 옆 인셋 없음)은 그대로', (tester) async {
      const data = MediaQueryData(
        size: Size(402, 874),
        padding: EdgeInsets.only(top: 62, bottom: 34),
        viewPadding: EdgeInsets.only(top: 62, bottom: 34),
      );
      final r = await _probe(tester, data);
      expect(r.padding, data.padding);
      expect(r.actionsPadding, isNull);
    });

    testWidgets('펼친 가로 화면은 보정하지 않음', (tester) async {
      const data = MediaQueryData(
        size: Size(951, 669),
        padding: EdgeInsets.only(left: 50, bottom: 20),
        viewPadding: EdgeInsets.only(left: 50, bottom: 20),
      );
      final r = await _probe(tester, data);
      expect(r.padding, data.padding);
    });
  });

  group('DetailPane 분기', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget app({
      required bool split,
      required DetailPaneController controller,
    }) {
      return ChangeNotifierProvider<FontProvider>(
        create: (_) => FontProvider(),
        child: MaterialApp(
          home: DetailPaneScope(
            controller: controller,
            split: split,
            child: Scaffold(
              body: Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) => Column(
                        children: [
                          TextButton(
                            onPressed: () => DetailPane.push<void>(
                              context,
                              builder: (_) =>
                                  const Scaffold(body: Text('상세 화면')),
                            ),
                            child: const Text('열기'),
                          ),
                          TextButton(
                            onPressed: () => DetailPane.show<void>(
                              context,
                              builder: (_) =>
                                  const Scaffold(body: Text('패널 상세')),
                              fallback: () => showDialog<void>(
                                context: context,
                                builder: (_) =>
                                    const AlertDialog(content: Text('폰 다이얼로그')),
                              ),
                            ),
                            child: const Text('보기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (split)
                    Expanded(child: DetailPaneView(controller: controller)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('펼침: push가 오른쪽 패널에 열리고 왼쪽은 그대로', (tester) async {
      final controller = DetailPaneController();
      await tester.pumpWidget(app(split: true, controller: controller));
      expect(find.text('왼쪽에서 항목을 선택하면 여기에 표시됩니다'), findsOneWidget);

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      expect(find.text('상세 화면'), findsOneWidget);
      expect(find.text('열기'), findsOneWidget); // 왼쪽 화면 유지
      expect(controller.hasDetail, isTrue);

      controller.closeDetail();
      await tester.pumpAndSettle();
      expect(find.text('상세 화면'), findsNothing);
      expect(controller.hasDetail, isFalse);
    });

    testWidgets('펼침: 다른 항목을 열면 이전 상세를 교체', (tester) async {
      final controller = DetailPaneController();
      await tester.pumpWidget(app(split: true, controller: controller));

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('보기'));
      await tester.pumpAndSettle();

      expect(find.text('패널 상세'), findsOneWidget);
      expect(find.text('상세 화면'), findsNothing);
      expect(find.text('폰 다이얼로그'), findsNothing);
    });

    testWidgets('폰: push는 전체 화면, show는 기존 다이얼로그(fallback)', (tester) async {
      final controller = DetailPaneController();
      await tester.pumpWidget(app(split: false, controller: controller));

      await tester.tap(find.text('보기'));
      await tester.pumpAndSettle();
      expect(find.text('폰 다이얼로그'), findsOneWidget);
      expect(controller.hasDetail, isFalse);
      await tester.tapAt(const Offset(5, 5)); // 다이얼로그 닫기
      await tester.pumpAndSettle();

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('상세 화면'), findsOneWidget);
      expect(find.text('열기'), findsNothing); // 전체 화면으로 덮음
      expect(controller.hasDetail, isFalse);
    });

    testWidgets('탭별 주 작업이 오른쪽 기본 화면으로 표시되고 resetPrimary로 새로 만들어짐', (
      tester,
    ) async {
      final controller = DetailPaneController();
      var built = 0;
      controller.registerPrimary(Placeholder, (_) {
        built++;
        return const Scaffold(body: Text('주 작업'));
      });
      await tester.pumpWidget(app(split: true, controller: controller));
      controller.setCurrentScreen(Placeholder);
      await tester.pumpAndSettle();
      expect(find.text('주 작업'), findsOneWidget);

      final before = built;
      controller.resetPrimary();
      await tester.pumpAndSettle();
      expect(built, greaterThan(before));
      expect(find.text('주 작업'), findsOneWidget);
    });

    testWidgets('펼침: 시스템 뒤로가기는 앱을 나가지 않고 패널 상세부터 닫음', (tester) async {
      final controller = DetailPaneController();
      await tester.pumpWidget(app(split: true, controller: controller));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('상세 화면'), findsOneWidget);

      // Android 뒤로가기와 같은 경로
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('상세 화면'), findsNothing);
      expect(find.text('열기'), findsOneWidget);
    });
  });
}
