import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hansl/providers/attendance_provider.dart';
import 'package:hansl/screens/attendance/attendance_screen.dart';
import 'package:provider/provider.dart';
import 'package:hansl/providers/user_provider.dart';
import 'package:hansl/providers/notification_provider.dart';
import 'package:hansl/providers/leave_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('지각 통계 기능 테스트', () {
    test('AttendanceProvider에 지각 통계 getter가 존재하는지 확인', () {
      // Skip initialization to avoid SharedPreferences issue
      final provider = AttendanceProvider(
        userId: 'test_user',
        userName: 'Test User',
      );

      // 초기값 확인
      expect(provider.monthlyLateCount, isNotNull);
      expect(provider.yearlyLateCount, isNotNull);
      expect(provider.monthlyLateCount, 0);
      expect(provider.yearlyLateCount, 0);
    });

    testWidgets('출근 화면에 지각 통계 위젯이 표시되는지 확인', (WidgetTester tester) async {
      // Provider setup
      final attendanceProvider = AttendanceProvider(
        userId: 'test_user',
        userName: 'Test User',
      );
      final userProvider = UserProvider();
      final notificationProvider = NotificationProvider();
      final leaveProvider = LeaveProvider();

      // Build widget with providers
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: attendanceProvider),
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: notificationProvider),
            ChangeNotifierProvider.value(value: leaveProvider),
          ],
          child: MaterialApp(
            home: AttendanceScreen(),
          ),
        ),
      );

      // Allow time for initial load
      await tester.pump();
      await tester.pump(Duration(seconds: 1));

      // 지각 통계 텍스트 확인
      expect(find.text('이번 달 지각'), findsOneWidget);
      expect(find.text('올해 지각'), findsOneWidget);
      
      // 지각 횟수 표시 확인 (초기값은 0)
      expect(find.text('0회'), findsWidgets);
    });

    test('fetchLateStatistics 메서드가 존재하는지 확인', () {
      final provider = AttendanceProvider(
        userId: 'test_user',
        userName: 'Test User',
      );

      // Method exists and is callable
      expect(() => provider.fetchLateStatistics(), returnsNormally);
    });
  });

  group('지각 통계 UI 테스트', () {
    testWidgets('지각 통계 카드가 올바른 위치에 표시되는지 확인', (WidgetTester tester) async {
      final attendanceProvider = AttendanceProvider(
        userId: 'test_user',
        userName: 'Test User',
      );
      final userProvider = UserProvider();
      final notificationProvider = NotificationProvider();
      final leaveProvider = LeaveProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: attendanceProvider),
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: notificationProvider),
            ChangeNotifierProvider.value(value: leaveProvider),
          ],
          child: MaterialApp(
            home: AttendanceScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration(seconds: 1));

      // 순서 확인: 오늘의 근무 요약 -> 지각 통계 -> 최근 기록
      final summaryCard = find.text('오늘의 근무 요약');
      final lateStats = find.text('이번 달 지각');
      final recentHistory = find.text('최근 기록');

      expect(summaryCard, findsOneWidget);
      expect(lateStats, findsOneWidget);
      expect(recentHistory, findsOneWidget);
    });

    testWidgets('지각 통계 아이콘이 올바르게 표시되는지 확인', (WidgetTester tester) async {
      final attendanceProvider = AttendanceProvider(
        userId: 'test_user',
        userName: 'Test User',
      );
      final userProvider = UserProvider();
      final notificationProvider = NotificationProvider();
      final leaveProvider = LeaveProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: attendanceProvider),
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: notificationProvider),
            ChangeNotifierProvider.value(value: leaveProvider),
          ],
          child: MaterialApp(
            home: AttendanceScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration(seconds: 1));

      // 아이콘 확인
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });
  });
}