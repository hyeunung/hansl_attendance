import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BadgeCacheService {
  static const String _badgeCountsKey = 'badge_counts';
  
  // 배지 카운트를 로컬에 저장
  static Future<void> saveBadgeCounts({
    required int leaveCount,
    required int purchaseWaitingCount,
    required int receivingWaitingCount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final badgeCounts = {
        'leave_count': leaveCount,
        'purchase_waiting_count': purchaseWaitingCount,
        'receiving_waiting_count': receivingWaitingCount,
        'last_updated': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_badgeCountsKey, json.encode(badgeCounts));
    } catch (e) {
      // 실패해도 앱 동작에 영향 없음
    }
  }
  
  // 로컬에서 배지 카운트 즉시 읽기 (동기)
  static Map<String, int> getCachedBadgeCounts() {
    try {
      // SharedPreferences의 동기 접근은 불가능하므로
      // Provider에서 메모리 캐시를 사용하도록 변경
      return {
        'leave_count': 0,
        'purchase_waiting_count': 0,
        'receiving_waiting_count': 0,
      };
    } catch (e) {
      return {
        'leave_count': 0,
        'purchase_waiting_count': 0,
        'receiving_waiting_count': 0,
      };
    }
  }
  
  // 비동기로 캐시된 배지 카운트 읽기
  static Future<Map<String, int>> loadCachedBadgeCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_badgeCountsKey);
      
      if (cachedData != null) {
        final badgeCounts = json.decode(cachedData) as Map<String, dynamic>;
        
        // 캐시가 너무 오래되었으면 무시 (1시간)
        final lastUpdated = DateTime.parse(badgeCounts['last_updated']);
        if (DateTime.now().difference(lastUpdated).inHours > 1) {
          return {
            'leave_count': 0,
            'purchase_waiting_count': 0,
            'receiving_waiting_count': 0,
          };
        }
        
        return {
          'leave_count': badgeCounts['leave_count'] ?? 0,
          'purchase_waiting_count': badgeCounts['purchase_waiting_count'] ?? 0,
          'receiving_waiting_count': badgeCounts['receiving_waiting_count'] ?? 0,
        };
      }
    } catch (e) {
      // 실패시 기본값 반환
    }
    
    return {
      'leave_count': 0,
      'purchase_waiting_count': 0,
      'receiving_waiting_count': 0,
    };
  }
  
  // 캐시 클리어
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_badgeCountsKey);
    } catch (e) {
      // 실패해도 무시
    }
  }
}