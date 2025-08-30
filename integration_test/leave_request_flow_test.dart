import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:hansl/providers/leave_provider.dart';
import 'package:hansl/providers/user_provider.dart';
import 'package:hansl/screens/leave/annual_leave_request_screen_optimized.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('연차 신청 플로우 통합 테스트', () {
    testWidgets('전체 연차 신청 프로세스 테스트', (WidgetTester tester) async {
      // Mock Providers 설정
      final userProvider = UserProvider();
      final leaveProvider = LeaveProvider();
      
      // 테스트용 사용자 정보 설정
      userProvider.setUserForTesting(
        email: 'test@company.com',
        name: '테스트사용자',
      );
      
      // 테스트용 연차 정보 설정
      leaveProvider.setLeaveDataForTesting(
        remainAnnual: 10.0,
        usedAnnual: 5.0,
        grantedAnnual: 15.0,
      );

      // 앱 실행
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: leaveProvider),
          ],
          child: const MaterialApp(
            home: AnnualLeaveRequestScreenOptimized(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. 연차 유형 선택 테스트
      expect(find.text('연차'), findsOneWidget);
      
      // 드롭다운 열기
      await tester.tap(find.text('연차'));
      await tester.pumpAndSettle();
      
      // 반차 선택
      await tester.tap(find.text('오전반차'));
      await tester.pumpAndSettle();
      
      expect(find.text('오전반차'), findsOneWidget);

      // 2. 날짜 선택 테스트
      // 캘린더에서 내일 날짜 선택
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dayFinder = find.text('${tomorrow.day}');
      
      if (dayFinder.evaluate().isNotEmpty) {
        await tester.tap(dayFinder.first);
        await tester.pumpAndSettle();
      }

      // 3. 메모 입력 테스트
      final memoField = find.byType(TextField).last;
      await tester.enterText(memoField, '개인 사유로 오전 반차 신청합니다.');
      await tester.pumpAndSettle();

      // 4. 신청 버튼 활성화 확인
      final submitButton = find.text('신청하기');
      expect(submitButton, findsOneWidget);
      
      // 버튼이 활성화되었는지 확인 (색상으로 판단)
      final buttonWidget = tester.widget<GestureDetector>(
        find.ancestor(
          of: submitButton,
          matching: find.byType(GestureDetector),
        ).first,
      );
      expect(buttonWidget.onTap, isNotNull);
    });

    testWidgets('입력 검증 테스트', (WidgetTester tester) async {
      final userProvider = UserProvider();
      final leaveProvider = LeaveProvider();
      
      userProvider.setUserForTesting(
        email: 'test@company.com',
        name: '테스트사용자',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: leaveProvider),
          ],
          child: const MaterialApp(
            home: AnnualLeaveRequestScreenOptimized(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 날짜 선택 없이 신청 시도
      final submitButton = find.text('신청하기');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // 버튼이 비활성화 상태인지 확인
      final buttonWidget = tester.widget<GestureDetector>(
        find.ancestor(
          of: submitButton,
          matching: find.byType(GestureDetector),
        ).first,
      );
      
      // onTap이 null이거나 실행되지 않아야 함
      if (buttonWidget.onTap != null) {
        buttonWidget.onTap!();
        await tester.pump();
        
        // 에러 메시지나 배너가 표시되어야 함
        expect(
          find.textContaining('선택'),
          findsOneWidget,
        );
      }
    });

    testWidgets('잔여 연차 부족 시나리오 테스트', (WidgetTester tester) async {
      final userProvider = UserProvider();
      final leaveProvider = LeaveProvider();
      
      userProvider.setUserForTesting(
        email: 'test@company.com',
        name: '테스트사용자',
      );
      
      // 잔여 연차를 0으로 설정
      leaveProvider.setLeaveDataForTesting(
        remainAnnual: 0.0,
        usedAnnual: 15.0,
        grantedAnnual: 15.0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: leaveProvider),
          ],
          child: const MaterialApp(
            home: AnnualLeaveRequestScreenOptimized(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 잔여 연차 0일 표시 확인
      expect(find.text('0일'), findsOneWidget);
      
      // 날짜 선택 시도
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dayFinder = find.text('${tomorrow.day}');
      
      if (dayFinder.evaluate().isNotEmpty) {
        await tester.tap(dayFinder.first);
        await tester.pumpAndSettle();
        
        // 메모 입력
        final memoField = find.byType(TextField).last;
        await tester.enterText(memoField, '테스트 메모');
        await tester.pumpAndSettle();
        
        // 신청 시도
        final submitButton = find.text('신청하기');
        await tester.tap(submitButton);
        await tester.pumpAndSettle();
        
        // 잔여 연차 부족 메시지 확인
        expect(
          find.textContaining('부족'),
          findsOneWidget,
        );
      }
    });
  });
}

// 테스트를 위한 Provider 확장
extension UserProviderTest on UserProvider {
  void setUserForTesting({required String email, required String name}) {
    // 테스트용 setter 구현
    // 실제 구현은 UserProvider 클래스에 추가 필요
  }
}

extension LeaveProviderTest on LeaveProvider {
  void setLeaveDataForTesting({
    required double remainAnnual,
    required double usedAnnual,
    required double grantedAnnual,
  }) {
    // 테스트용 setter 구현
    // 실제 구현은 LeaveProvider 클래스에 추가 필요
  }
}