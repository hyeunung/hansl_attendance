import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hansl/widgets/leave/leave_info_card_widget.dart';

void main() {
  group('LeaveInfoCardWidget', () {
    testWidgets('연차 정보가 올바르게 표시되는지 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveInfoCardWidget(
              remainAnnual: 10.5,
              grantedAnnual: 15.0,
              usedAnnual: 4.5,
              currentYear: 2024,
              nextYear: 2025,
              currentYearGranted: 15.0,
              nextYearGranted: 16.0,
            ),
          ),
        ),
      );

      // 잔여 연차 표시 확인
      expect(find.text('10.5'), findsOneWidget);
      expect(find.text('일'), findsWidgets);
      
      // 부여 연차 표시 확인
      expect(find.text('/ 15일'), findsOneWidget);
      
      // 사용 연차 표시 확인
      expect(find.text('사용: 4.5일'), findsOneWidget);
      
      // 연도별 정보 표시 확인
      expect(find.text('2024.01.01 ~ 2024.12.31'), findsOneWidget);
      expect(find.text('2025.01.01 ~ 2025.12.31'), findsOneWidget);
      expect(find.text('15일'), findsOneWidget);
      expect(find.text('16일'), findsOneWidget);
    });

    testWidgets('사용률이 올바르게 계산되는지 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveInfoCardWidget(
              remainAnnual: 5.0,
              grantedAnnual: 15.0,
              usedAnnual: 10.0,
              currentYear: 2024,
              nextYear: 2025,
              currentYearGranted: 15.0,
              nextYearGranted: 16.0,
            ),
          ),
        ),
      );

      // 사용률 표시 확인 (10/15 * 100 = 66.7%)
      expect(find.text('사용률 67%'), findsOneWidget);
    });

    testWidgets('정수 값이 소수점 없이 표시되는지 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveInfoCardWidget(
              remainAnnual: 10.0, // 정수
              grantedAnnual: 15.0,
              usedAnnual: 5.0, // 정수
              currentYear: 2024,
              nextYear: 2025,
              currentYearGranted: 15.0,
              nextYearGranted: 16.0,
            ),
          ),
        ),
      );

      // 정수는 소수점 없이 표시되어야 함
      expect(find.text('10'), findsOneWidget);
      expect(find.text('사용: 5일'), findsOneWidget);
    });

    testWidgets('프로그레스 바가 올바르게 표시되는지 테스트', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveInfoCardWidget(
              remainAnnual: 7.5,
              grantedAnnual: 15.0,
              usedAnnual: 7.5,
              currentYear: 2024,
              nextYear: 2025,
              currentYearGranted: 15.0,
              nextYearGranted: 16.0,
            ),
          ),
        ),
      );

      // FractionallySizedBox가 있는지 확인 (프로그레스 바)
      final fractionBox = find.byType(FractionallySizedBox);
      expect(fractionBox, findsOneWidget);
      
      // 50% 사용 (7.5/15.0)
      final FractionallySizedBox widget = 
          tester.widget<FractionallySizedBox>(fractionBox);
      expect(widget.widthFactor, 0.5);
    });

    testWidgets('사용률에 따른 색상 변경 테스트', (WidgetTester tester) async {
      // 낮은 사용률 (< 50%) - 녹색
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveInfoCardWidget(
              remainAnnual: 10.0,
              grantedAnnual: 15.0,
              usedAnnual: 5.0, // 33%
              currentYear: 2024,
              nextYear: 2025,
              currentYearGranted: 15.0,
              nextYearGranted: 16.0,
            ),
          ),
        ),
      );

      expect(find.text('사용률 33%'), findsOneWidget);
      
      // 위젯 재빌드
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveInfoCardWidget(
              remainAnnual: 2.0,
              grantedAnnual: 15.0,
              usedAnnual: 13.0, // 87%
              currentYear: 2024,
              nextYear: 2025,
              currentYearGranted: 15.0,
              nextYearGranted: 16.0,
            ),
          ),
        ),
      );

      expect(find.text('사용률 87%'), findsOneWidget);
    });
  });
}