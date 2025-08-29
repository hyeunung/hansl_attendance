import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hansl/widgets/common/notification_banner_widget.dart';

void main() {
  group('NotificationBannerWidget', () {
    testWidgets('메시지가 없을 때 빈 위젯 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationBannerWidget(
              message: null,
            ),
          ),
        ),
      );

      // SizedBox.shrink()가 렌더링되므로 아무것도 표시되지 않음
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('성공 메시지 표시 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationBannerWidget(
              message: '신청이 완료되었습니다.',
              type: BannerType.success,
            ),
          ),
        ),
      );

      expect(find.text('신청이 완료되었습니다.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('에러 메시지 표시 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationBannerWidget(
              message: '오류가 발생했습니다.',
              type: BannerType.error,
            ),
          ),
        ),
      );

      expect(find.text('오류가 발생했습니다.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('경고 메시지 표시 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationBannerWidget(
              message: '주의가 필요합니다.',
              type: BannerType.warning,
            ),
          ),
        ),
      );

      expect(find.text('주의가 필요합니다.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('정보 메시지 표시 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationBannerWidget(
              message: '정보입니다.',
              type: BannerType.info,
            ),
          ),
        ),
      );

      expect(find.text('정보입니다.'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('닫기 버튼 동작 테스트', (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationBannerWidget(
              message: '닫을 수 있는 메시지',
              type: BannerType.info,
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      // 닫기 버튼이 표시되는지 확인
      expect(find.byIcon(Icons.close), findsOneWidget);

      // 닫기 버튼 탭
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('onDismiss가 없을 때 닫기 버튼 미표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationBannerWidget(
              message: '닫기 버튼이 없는 메시지',
              type: BannerType.info,
            ),
          ),
        ),
      );

      // 닫기 버튼이 표시되지 않는지 확인
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });

  group('BannerControllerMixin', () {
    testWidgets('배너 표시 및 숨기기 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(const _TestBannerWidget());

      // 초기 상태: 배너가 표시되지 않음
      expect(find.text('테스트 메시지'), findsNothing);

      // 배너 표시 버튼 탭
      await tester.tap(find.text('Show Banner'));
      await tester.pump();

      // 배너가 표시됨
      expect(find.text('테스트 메시지'), findsOneWidget);

      // 배너 숨기기 버튼 탭
      await tester.tap(find.text('Hide Banner'));
      await tester.pump();

      // 배너가 숨겨짐
      expect(find.text('테스트 메시지'), findsNothing);
    });

    testWidgets('배너 자동 숨기기 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(const _TestBannerWidget());

      // 자동 숨기기 배너 표시
      await tester.tap(find.text('Show Auto Hide'));
      await tester.pump();

      // 배너가 표시됨
      expect(find.text('자동으로 사라지는 메시지'), findsOneWidget);

      // 1초 후 배너가 자동으로 사라짐
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(); // 애니메이션 완료

      // 배너가 숨겨짐
      expect(find.text('자동으로 사라지는 메시지'), findsNothing);
    });

    testWidgets('배너 타입 변경 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(const _TestBannerWidget());

      // 성공 배너 표시
      await tester.tap(find.text('Show Success'));
      await tester.pump();

      expect(find.text('성공 메시지'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // 에러 배너로 변경
      await tester.tap(find.text('Show Error'));
      await tester.pump();

      expect(find.text('에러 메시지'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}

// BannerControllerMixin 테스트를 위한 테스트 위젯
class _TestBannerWidget extends StatefulWidget {
  const _TestBannerWidget();

  @override
  State<_TestBannerWidget> createState() => _TestBannerWidgetState();
}

class _TestBannerWidgetState extends State<_TestBannerWidget>
    with BannerControllerMixin {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            buildBanner(),
            ElevatedButton(
              onPressed: () => showBanner('테스트 메시지'),
              child: const Text('Show Banner'),
            ),
            ElevatedButton(
              onPressed: () => hideBanner(),
              child: const Text('Hide Banner'),
            ),
            ElevatedButton(
              onPressed: () => showBanner(
                '자동으로 사라지는 메시지',
                duration: const Duration(seconds: 1),
              ),
              child: const Text('Show Auto Hide'),
            ),
            ElevatedButton(
              onPressed: () => showBanner(
                '성공 메시지',
                type: BannerType.success,
              ),
              child: const Text('Show Success'),
            ),
            ElevatedButton(
              onPressed: () => showBanner(
                '에러 메시지',
                type: BannerType.error,
              ),
              child: const Text('Show Error'),
            ),
          ],
        ),
      ),
    );
  }
}