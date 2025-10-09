import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_service.dart';

class CacheRecoveryService {
  
  static final _client = Supabase.instance.client;
  static final _cache = CacheService.instance;

  /// 캐시에 있는 연차/출장 신청 데이터를 DB로 복원
  static Future<void> recoverLeaveDataFromCache() async {
    if (!kDebugMode) {
      // Debug print removed
return;
    }

    try {
      // Debug print removed
// 1. 캐시에서 모든 leave 데이터 가져오기
      // final cacheStats = _cache.getStats();
      // Debug print removed
// 2. all_leaves 캐시 확인
      final allLeavesCache = await _cache
          .getOrFetch<List<Map<String, dynamic>>>(
            key: 'all_leaves',
            fallback: () async => <Map<String, dynamic>>[],
          );

      if (allLeavesCache != null && allLeavesCache.isNotEmpty) {
        // Debug code removed

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
          // Debug code removed

          for (final leave in myLeavesCache) {
            if (leave['status'] == 'pending') {
              await _recoverSingleLeave(leave);
            }
          }
        }
      }

      // Debug print removed
} catch (e) {
      // Debug print removed
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
        // Debug print removed
return;
      }

      // DB에 없으면 복원
      final leaveToInsert = Map<String, dynamic>.from(leaveData);

      // DB 스키마에 맞게 데이터 정리
      leaveToInsert.remove('employees'); // JOIN된 데이터 제거
      leaveToInsert.remove('id'); // auto-increment이므로 제거

      await _client
          .from('leave')
          .insert(leaveToInsert)
          .select()
          .single();

      // Debug code removed
    } catch (e) {
      // Debug print removed
}
  }

  /// 캐시 내용 출력 (디버깅용)
  static Future<void> printCacheContents() async {
    if (!kDebugMode) return;

    // Debug print removed
try {
      // final stats = _cache.getStats();
      // Debug print removed
// all_leaves 캐시 확인
      final allLeaves = await _cache.getOrFetch<List<Map<String, dynamic>>>(
        key: 'all_leaves',
        fallback: () async => <Map<String, dynamic>>[],
      );

      if (allLeaves != null && allLeaves.isNotEmpty) {
        // Debug print removed
for (int i = 0; i < allLeaves.length && i < 5; i++) {
          // final leave = allLeaves[i];
          // Debug code removed
        }
      } else {
        // Debug print removed
}
    } catch (e) {
      // Debug print removed
}
  }
}
