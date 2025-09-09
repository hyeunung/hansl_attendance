import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 보안 데이터 저장소 서비스
/// 민감한 데이터는 암호화하여 저장, 일반 데이터는 SharedPreferences 사용
class SecureStorageService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // 민감한 데이터 키들 (암호화 저장)
  static const Set<String> _sensitiveKeys = {
    'user_token',
    'refresh_token',
    'user_password',
    'biometric_data',
    'user_email', // 이메일도 민감 정보로 처리
    'supabase_session',
    'firebase_token',
  };

  /// 데이터 저장 (자동으로 민감도에 따라 저장소 결정)
  static Future<void> write({
    required String key,
    required String value,
  }) async {
    try {
      if (_sensitiveKeys.contains(key)) {
        // 민감한 데이터 → 보안 저장소
        await _secureStorage.write(key: key, value: value);
      } else {
        // 일반 데이터 → SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ SecureStorageService write error for key "$key": $e');
      }
      rethrow;
    }
  }

  /// 데이터 읽기 (자동으로 민감도에 따라 저장소 결정)
  static Future<String?> read({required String key}) async {
    try {
      if (_sensitiveKeys.contains(key)) {
        // 민감한 데이터 → 보안 저장소에서 읽기
        return await _secureStorage.read(key: key);
      } else {
        // 일반 데이터 → SharedPreferences에서 읽기
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ SecureStorageService read error for key "$key": $e');
      }
      return null;
    }
  }

  /// 데이터 삭제
  static Future<void> delete({required String key}) async {
    try {
      if (_sensitiveKeys.contains(key)) {
        // 민감한 데이터 → 보안 저장소에서 삭제
        await _secureStorage.delete(key: key);
      } else {
        // 일반 데이터 → SharedPreferences에서 삭제
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ SecureStorageService delete error for key "$key": $e');
      }
    }
  }

  /// 모든 데이터 삭제 (로그아웃 시 사용)
  static Future<void> deleteAll() async {
    try {
      // 보안 저장소 전체 삭제
      await _secureStorage.deleteAll();

      // SharedPreferences에서 앱 관련 데이터만 삭제
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // 앱에서 사용하는 키들만 삭제 (시스템 키는 보존)
      final appKeys = keys.where(
        (key) =>
            key.startsWith('hansl_') ||
            key.startsWith('attendance_') ||
            key.startsWith('leave_') ||
            key.startsWith('user_') ||
            key.contains('setting'),
      );

      for (final key in appKeys) {
        await prefs.remove(key);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ SecureStorageService deleteAll error: $e');
    }
  }

  /// 보안 저장소 사용 가능 여부 확인
  static Future<bool> isSecureStorageAvailable() async {
    try {
      await _secureStorage.read(key: 'test_key');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ SecureStorage not available: $e');
      return false;
    }
  }

  /// 민감한 데이터 키인지 확인
  static bool isSensitiveKey(String key) {
    return _sensitiveKeys.contains(key);
  }

  /// 기존 SharedPreferences 데이터를 보안 저장소로 마이그레이션
  static Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 민감한 키들을 보안 저장소로 이동
      for (final key in _sensitiveKeys) {
        final value = prefs.getString(key);
        if (value != null) {
          // 보안 저장소에 저장
          await _secureStorage.write(key: key, value: value);
          // SharedPreferences에서 삭제
          await prefs.remove(key);
          if (kDebugMode) debugPrint('✅ Migrated "$key" to secure storage');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Migration error: $e');
    }
  }

  /// 저장된 데이터 진단 (개발용)
  static Future<Map<String, dynamic>> diagnostics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sharedPrefsKeys = prefs.getKeys();

      // 보안 저장소의 키 개수는 보안상 정확한 키명은 노출하지 않음
      final secureStorageKeys = await _secureStorage.readAll();

      return {
        'secure_storage_count': secureStorageKeys.length,
        'shared_preferences_keys': sharedPrefsKeys.toList(),
        'sensitive_keys_configured': _sensitiveKeys.toList(),
        'secure_storage_available': await isSecureStorageAvailable(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
