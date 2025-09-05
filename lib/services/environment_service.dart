import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';
import 'package:flutter/foundation.dart';

/// 환경 변수 안전 로딩 서비스
/// .env 파일 대신 빌드 시 환경 변수나 보안 저장소 사용
class EnvironmentService {
  static bool _initialized = false;

  // 환경 변수 키들
  static const String supabaseUrl = 'SUPABASE_URL';
  static const String supabaseAnonKey = 'SUPABASE_ANON_KEY';
  static const String supabaseServiceKey = 'SUPABASE_SERVICE_KEY';
  static const String slackWebhookUrl = 'SLACK_WEBHOOK_URL';

  /// 환경 서비스 초기화
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. 시스템 환경 변수 우선 확인 (가장 안전)
      if (_hasSystemEnvVars()) {
        if (kDebugMode) print('✅ Using system environment variables (most secure)');
        _initialized = true;
        return;
      }

      // 2. 보안 저장소에서 확인
      if (await _hasSecureStorageVars()) {
        if (kDebugMode) print('✅ Using secure storage variables');
        _initialized = true;
        return;
      }

      // 3. .env 파일 로드 (개발 환경에서만, 경고 표시)
      if (await _loadDotEnvFile()) {
        if (kDebugMode) print('⚠️ WARNING: Using .env file - not secure for production!');

        // .env에서 로드한 값들을 보안 저장소로 마이그레이션
        await _migrateToSecureStorage();
        _initialized = true;
        return;
      }

      // 4. 모든 방법 실패
      throw Exception(
        'No environment configuration found! Please set up environment variables or secure storage.',
      );
    } catch (e) {
      if (kDebugMode) print('❌ EnvironmentService initialization failed: $e');
      rethrow;
    }
  }

  /// 환경 변수 값 가져오기
  static Future<String?> get(String key, {String? fallback}) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // 1. 시스템 환경 변수 우선
      final systemValue = Platform.environment[key];
      if (systemValue != null && systemValue.isNotEmpty) {
        return systemValue;
      }

      // 2. 보안 저장소
      final secureValue = await SecureStorageService.read(key: key);
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }

      // 3. .env 파일 (fallback)
      if (dotenv.isInitialized) {
        final dotenvValue = dotenv.env[key];
        if (dotenvValue != null && dotenvValue.isNotEmpty) {
          return dotenvValue;
        }
      }

      // 4. fallback 값
      return fallback;
    } catch (e) {
      if (kDebugMode) print('❌ Error getting environment variable "$key": $e');
      return fallback;
    }
  }

  /// 필수 환경 변수들이 모두 설정되었는지 확인
  static Future<bool> validateRequiredVars() async {
    final requiredVars = [supabaseUrl, supabaseAnonKey];

    for (final varName in requiredVars) {
      final value = await get(varName);
      if (value == null || value.isEmpty) {
        if (kDebugMode) print('❌ Required environment variable missing: $varName');
        return false;
      }
    }

    return true;
  }

  /// 시스템 환경 변수가 설정되어 있는지 확인
  static bool _hasSystemEnvVars() {
    final requiredVars = [supabaseUrl, supabaseAnonKey];
    return requiredVars.every((key) {
      final value = Platform.environment[key];
      return value != null && value.isNotEmpty;
    });
  }

  /// 보안 저장소에 환경 변수가 있는지 확인
  static Future<bool> _hasSecureStorageVars() async {
    try {
      final url = await SecureStorageService.read(key: supabaseUrl);
      final key = await SecureStorageService.read(key: supabaseAnonKey);

      return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// .env 파일 로드 시도
  static Future<bool> _loadDotEnvFile() async {
    try {
      // assets에서 제거했으므로 파일 시스템에서 직접 로드
      final envFile = File('.env');
      if (!await envFile.exists()) {
        return false;
      }

      await dotenv.load(fileName: '.env');
      return dotenv.isInitialized;
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load .env file: $e');
      return false;
    }
  }

  /// .env 파일의 값들을 보안 저장소로 마이그레이션
  static Future<void> _migrateToSecureStorage() async {
    try {
      if (!dotenv.isInitialized) return;

      final envVars = [supabaseUrl, supabaseAnonKey, supabaseServiceKey, slackWebhookUrl];

      for (final varName in envVars) {
        final value = dotenv.env[varName];
        if (value != null && value.isNotEmpty && value != 'YOUR_KEY_HERE') {
          await SecureStorageService.write(key: varName, value: value);
          if (kDebugMode) print('✅ Migrated $varName to secure storage');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Migration to secure storage failed: $e');
    }
  }

  /// 환경 변수 설정 (보안 저장소에 저장)
  static Future<void> set(String key, String value) async {
    try {
      await SecureStorageService.write(key: key, value: value);
      if (kDebugMode) print('✅ Environment variable "$key" set in secure storage');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to set environment variable "$key": $e');
      rethrow;
    }
  }

  /// 진단 정보 (개발용)
  static Future<Map<String, dynamic>> diagnostics() async {
    try {
      final systemVars = Platform.environment.keys
          .where((key) => key.startsWith('SUPABASE_') || key.startsWith('SLACK_'))
          .toList();

      return {
        'initialized': _initialized,
        'system_env_vars': systemVars,
        'dotenv_initialized': dotenv.isInitialized,
        'secure_storage_available': await SecureStorageService.isSecureStorageAvailable(),
        'validation_passed': await validateRequiredVars(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

/// 환경 변수 확장 메서드
extension EnvironmentExtension on String {
  /// 환경 변수 값 가져오기 (편의 메서드)
  Future<String?> env({String? fallback}) async {
    return await EnvironmentService.get(this, fallback: fallback);
  }
}
