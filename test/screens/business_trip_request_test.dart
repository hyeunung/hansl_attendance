import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hansl/providers/leave_provider.dart';
import 'package:hansl/providers/user_provider.dart';
import 'package:hansl/screens/leave/business_trip_request_screen_optimized.dart';
import 'package:hansl/services/feature_flag_service.dart';
import 'package:hansl/widgets/business_trip/trip_calendar_widget.dart';

void main() {
  group('출장 신청 화면 테스트', () {
    setUpAll(() async {
      await FeatureFlagService().initialize();
    });

    testWidgets('화면 빌드 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
          ],
          child: const MaterialApp(
            home: BusinessTripRequestScreenOptimized(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 필수 UI 요소들이 존재하는지 확인
      expect(find.text('출장 신청'), findsOneWidget);
      expect(find.text('출장 날짜 선택'), findsOneWidget);
      expect(find.text('선택된 날짜'), findsOneWidget);
      expect(find.text('교통수단'), findsOneWidget);
      expect(find.text('출장자 (신청자)'), findsOneWidget);
      expect(find.text('추가 인원'), findsOneWidget);
      expect(find.text('출장 신청하기'), findsOneWidget);
    });

    testWidgets('날짜 선택 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
          ],
          child: const MaterialApp(
            home: BusinessTripRequestScreenOptimized(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 캘린더 위젯이 표시되는지 확인
      expect(find.byType(TripCalendarWidget), findsOneWidget);
      
      // 날짜 선택 안내 메시지
      expect(find.text('선택된 날짜가 없습니다'), findsOneWidget);
    });

    testWidgets('입력 필드 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
          ],
          child: const MaterialApp(
            home: BusinessTripRequestScreenOptimized(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 출장 장소 입력 필드
      final placeField = find.widgetWithText(TextField, '출장 장소를 입력하세요');
      expect(placeField, findsOneWidget);
      
      // 출장 목적 입력 필드
      final purposeField = find.widgetWithText(TextField, '출장 목적을 입력하세요');
      expect(purposeField, findsOneWidget);
      
      // 입력 테스트
      await tester.enterText(placeField, '서울시 강남구');
      await tester.enterText(purposeField, '협력사 미팅');
      await tester.pump();
      
      expect(find.text('서울시 강남구'), findsOneWidget);
      expect(find.text('협력사 미팅'), findsOneWidget);
    });

    testWidgets('제출 버튼 활성화 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
          ],
          child: const MaterialApp(
            home: BusinessTripRequestScreenOptimized(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 처음에는 버튼이 비활성화되어 있어야 함
      final submitButton = find.widgetWithText(ElevatedButton, '출장 신청하기');
      expect(submitButton, findsOneWidget);
      
      final buttonWidget = tester.widget<ElevatedButton>(submitButton);
      expect(buttonWidget.onPressed, isNull); // 비활성화 상태
    });

    testWidgets('성능 최적화 테스트', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
          ],
          child: const MaterialApp(
            home: BusinessTripRequestScreenOptimized(),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      stopwatch.stop();
      
      // 화면 로드 시간이 1000ms 이내인지 확인
      // print('📊 출장 신청 화면 로드 시간: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}