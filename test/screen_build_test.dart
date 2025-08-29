import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hansl/providers/leave_provider.dart';
import 'package:hansl/providers/user_provider.dart';
import 'package:hansl/screens/leave/leave_screen_router.dart';
import 'package:hansl/screens/leave/annual_leave_request_screen_optimized.dart';
import 'package:hansl/services/feature_flag_service.dart';

void main() {
  group('화면 빌드 테스트', () {
    setUpAll(() async {
      // Feature Flag 서비스 초기화
      await FeatureFlagService().initialize();
    });

    testWidgets('LeaveScreenRouter 빌드 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
          ],
          child: const MaterialApp(
            home: LeaveScreenRouter(),
          ),
        ),
      );

      // 화면이 정상적으로 빌드되었는지 확인
      expect(find.byType(LeaveScreenRouter), findsOneWidget);
      
      // Feature Flag가 true이면 Optimized 화면이 표시되어야 함
      if (FeatureFlags.useRefactoredLeaveScreen) {
        expect(find.byType(AnnualLeaveRequestScreenOptimized), findsOneWidget);
        
        // 디버그 정보가 표시되는지 확인
        if (FeatureFlags.showDebugInfo) {
          expect(find.text('Version: optimized'), findsOneWidget);
        }
      }
    });

    testWidgets('AnnualLeaveRequestScreenOptimized 직접 빌드 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
          ],
          child: const MaterialApp(
            home: AnnualLeaveRequestScreenOptimized(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 필수 UI 요소들이 존재하는지 확인
      expect(find.text('연차 신청'), findsOneWidget);
      expect(find.text('연차'), findsWidgets); // 드롭다운에도 있을 수 있음
      expect(find.text('신청하기'), findsOneWidget);
    });

    testWidgets('성능 모니터링 테스트', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
          ],
          child: const MaterialApp(
            home: LeaveScreenRouter(),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      stopwatch.stop();
      
      // 화면 로드 시간이 1000ms 이내인지 확인
      // print('📊 화면 로드 시간: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}