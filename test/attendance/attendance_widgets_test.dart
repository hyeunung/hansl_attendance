import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hansl/providers/attendance_provider.dart';
import 'package:hansl/widgets/attendance/attendance_action_buttons.dart';
import 'package:hansl/widgets/attendance/attendance_summary_card.dart';
import 'package:hansl/widgets/attendance/attendance_history_card.dart';

void main() {
  group('Attendance Widget Tests', () {
    late AttendanceProvider provider;

    setUp(() {
      provider = AttendanceProvider(
        userId: 'test_user',
        userName: 'Test User',
      );
    });

    Widget createTestWidget(Widget child) {
      return MaterialApp(
        home: ChangeNotifierProvider<AttendanceProvider>.value(
          value: provider,
          child: Scaffold(body: child),
        ),
      );
    }

    testWidgets('AttendanceActionButtons 출근 버튼 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        AttendanceActionButtons(
          onShowBanner: (msg, {error = false}) {},
        ),
      ));

      // 출근하기 버튼 확인
      expect(find.text('출근하기'), findsOneWidget);
      expect(find.text('퇴근하기'), findsOneWidget);

      // 출근 전 상태에서 출근 버튼만 활성화
      final clockInButton = find.text('출근하기').evaluate().first.widget as Text;
      expect(clockInButton.style?.color, isNot(equals(const Color(0xFFB0B0B0))));
    });

    testWidgets('AttendanceSummaryCard 표시 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const AttendanceSummaryCard()));

      // 요약 카드 제목 확인
      expect(find.text('오늘의 근무 요약'), findsOneWidget);
      expect(find.text('출근 시간'), findsOneWidget);
      expect(find.text('근무 시간'), findsOneWidget);
    });

    testWidgets('AttendanceHistoryCard 빈 상태 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const AttendanceHistoryCard()));

      // 최근 기록 제목 확인
      expect(find.text('최근 기록'), findsOneWidget);
      
      // 기록이 없을 때 메시지 확인
      expect(find.text('아직 기록이 없습니다'), findsOneWidget);
    });

    testWidgets('AttendanceActionButtons 로딩 상태 테스트', (WidgetTester tester) async {
      provider.isLoading = true;
      
      await tester.pumpWidget(createTestWidget(
        AttendanceActionButtons(
          onShowBanner: (msg, {error = false}) {},
        ),
      ));

      // 로딩 인디케이터 확인
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

  });
}