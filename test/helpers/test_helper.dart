import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 테스트 환경 초기화 헬퍼
class TestHelper {
  /// SharedPreferences Mock 초기화
  static Future<void> initializeSharedPreferences() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  }

  /// 테스트 환경 전체 초기화
  static Future<void> setUp() async {
    await initializeSharedPreferences();
  }
}