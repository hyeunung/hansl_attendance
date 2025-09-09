import 'package:flutter_test/flutter_test.dart';
import 'package:hansl/providers/attendance_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../helpers/test_helper.dart';

// Mock 클래스
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('AttendanceProvider Tests', () {
    late AttendanceProvider provider;
    // late MockSupabaseClient mockSupabase;
    // late MockFunctionsClient mockFunctions;

    setUpAll(() async {
      // SharedPreferences Mock 초기화
      await TestHelper.setUp();
    });

    setUp(() {
      // mockSupabase = MockSupabaseClient();
      // mockFunctions = MockFunctionsClient();
      
      // Provider 초기화
      provider = AttendanceProvider(
        userId: 'test_user_id',
        userName: 'Test User',
      );
    });

    test('초기 상태 확인', () {
      expect(provider.status, AttendanceStatus.beforeWork);
      expect(provider.clockInTime, isNull);
      expect(provider.clockOutTime, isNull);
      expect(provider.isLate, isFalse);
      expect(provider.canClockIn, isTrue);
      expect(provider.canClockOut, isFalse);
    });

    test('상태 텍스트 확인', () {
      expect(provider.statusText, '출근 전');
      
      provider.status = AttendanceStatus.working;
      expect(provider.statusText, '정상 출근');
      
      provider.status = AttendanceStatus.late;
      expect(provider.statusText, '지각');
      
      provider.status = AttendanceStatus.offWork;
      expect(provider.statusText, '퇴근');
    });

    test('근무 시간 계산', () {
      final now = DateTime.now();
      provider.clockInTime = now.subtract(const Duration(hours: 2, minutes: 30));
      
      final duration = provider.todayWorkDuration;
      expect(duration.contains('2시간'), isTrue);
    });

    test('출근 시간 포맷팅', () {
      final testTime = DateTime(2024, 1, 1, 9, 30, 45);
      provider.clockInTime = testTime;
      
      expect(provider.clockInStr, '09:30:45');
    });

    test('에러 메시지 처리', () {
      provider.errorMessage = 'Test error';
      expect(provider.errorMessage, 'Test error');
      
      provider.clearError();
      expect(provider.errorMessage, isNull);
    });

    // Edge Functions 검증은 통합 테스트에서 수행
    // group('Edge Functions 검증', () {
    //   test('위치 검증 Edge Function 호출', () async {
    //     // Edge Function 호출이 정상적으로 이루어지는지 확인
    //     // 실제 테스트는 통합 테스트에서 수행
    //   });
    //
    //   test('시간 검증 Edge Function 호출', () async {
    //     // Edge Function 호출이 정상적으로 이루어지는지 확인
    //     // 실제 테스트는 통합 테스트에서 수행
    //   });
    // });
  });
}

