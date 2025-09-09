import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_service.dart';
import '../utils/logger.dart';

class CacheRecoveryService {
  static final _client = Supabase.instance.client;
  static final _cache = CacheService.instance;

  /// 캐시에 있는 연차/출장 신청 데이터를 DB로 복원
  static Future<void> recoverLeaveDataFromCache() async {
    if (!kDebugMode) {
      if (kDebugMode) print('❌ 이 기능은 디버그 모드에서만 사용 가능합니다.');
      return;
    }

    try {
      if (kDebugMode) print('🔍 캐시에서 연차/출장 신청 데이터 복원 시작...');

      // 1. 캐시에서 모든 leave 데이터 가져오기
      final cacheStats = _cache.getStats();
      if (kDebugMode) print('📊 캐시 상태: ${cacheStats.toString()}');

      // 2. all_leaves 캐시 확인
      final allLeavesCache = await _cache
          .getOrFetch<List<Map<String, dynamic>>>(
            key: 'all_leaves',
            fallback: () async => <Map<String, dynamic>>[],
          );

      if (allLeavesCache != null && allLeavesCache.isNotEmpty) {
        AppLogger.debug(
          '캐시 복구',
          'all_leaves 캐시에서 ${allLeavesCache.length}개 발견',
        );

        for (final leave in allLeavesCache) {
          if (leave['status'] == 'pending') {
            await _recoverSingleLeave(leave);
          }
        }
      }

      // 3. my_leaves 캐시들도 확인
      final currentUser = _client.auth.currentUser;
      if (currentUser?.email != null) {
        final myLeavesKey = 'my_leaves_${currentUser!.email}';
        final myLeavesCache = await _cache
            .getOrFetch<List<Map<String, dynamic>>>(
              key: myLeavesKey,
              fallback: () async => <Map<String, dynamic>>[],
            );

        if (myLeavesCache != null && myLeavesCache.isNotEmpty) {
          AppLogger.debug(
            '캐시 복구',
            '$myLeavesKey 캐시에서 ${myLeavesCache.length}개 발견',
          );

          for (final leave in myLeavesCache) {
            if (leave['status'] == 'pending') {
              await _recoverSingleLeave(leave);
            }
          }
        }
      }

      if (kDebugMode) print('✅ 캐시 데이터 복원 완료');
    } catch (e) {
      if (kDebugMode) print('❌ 캐시 데이터 복원 실패: $e');
    }
  }

  static Future<void> _recoverSingleLeave(
    Map<String, dynamic> leaveData,
  ) async {
    try {
      // DB에 해당 ID가 있는지 확인
      final existingLeave = await _client
          .from('leave')
          .select('id')
          .eq('id', leaveData['id'])
          .maybeSingle();

      if (existingLeave != null) {
        if (kDebugMode) print('⚠️ ID ${leaveData['id']} 이미 DB에 존재함, 건너뜀');
        return;
      }

      // DB에 없으면 복원
      final leaveToInsert = Map<String, dynamic>.from(leaveData);

      // DB 스키마에 맞게 데이터 정리
      leaveToInsert.remove('employees'); // JOIN된 데이터 제거
      leaveToInsert.remove('id'); // auto-increment이므로 제거

      final result = await _client
          .from('leave')
          .insert(leaveToInsert)
          .select()
          .single();

      if (kDebugMode) {
        print(
          '✅ 복원됨: ${leaveData['type']} (${leaveData['user_email']}) -> DB ID: ${result['id']}',
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ 개별 데이터 복원 실패: ${leaveData['id']} - $e');
    }
  }

  /// 캐시 내용 출력 (디버깅용)
  static Future<void> printCacheContents() async {
    if (!kDebugMode) return;

    if (kDebugMode) print('🔍 캐시 내용 출력 시작...');

    try {
      final stats = _cache.getStats();
      if (kDebugMode) print('📊 캐시 통계: $stats');

      // all_leaves 캐시 확인
      final allLeaves = await _cache.getOrFetch<List<Map<String, dynamic>>>(
        key: 'all_leaves',
        fallback: () async => <Map<String, dynamic>>[],
      );

      if (allLeaves != null && allLeaves.isNotEmpty) {
        if (kDebugMode) print('📋 all_leaves: ${allLeaves.length}개');
        for (int i = 0; i < allLeaves.length && i < 5; i++) {
          final leave = allLeaves[i];
          if (kDebugMode) {
            print(
              '  - ID: ${leave['id']}, Type: ${leave['type']}, Status: ${leave['status']}, User: ${leave['user_email']}',
            );
          }
        }
      } else {
        if (kDebugMode) print('📋 all_leaves: 캐시에 데이터 없음');
      }
    } catch (e) {
      if (kDebugMode) print('❌ 캐시 내용 출력 실패: $e');
    }
  }
}
