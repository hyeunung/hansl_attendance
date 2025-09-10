import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

/// 앱 아이콘 배지 카운트 관리 서비스
class BadgeCountService {
  static final _supabase = Supabase.instance.client;
  
  /// 배지 카운트 업데이트
  static Future<void> updateBadgeCount() async {
    try {
      // 플랫폼 체크 - iOS와 일부 Android만 지원
      if (!await FlutterAppBadger.isAppBadgeSupported()) {
        return;
      }

      final user = _supabase.auth.currentUser;
      if (user == null) {
        await FlutterAppBadger.removeBadge();
        return;
      }

      // 사용자 정보 가져오기
      final employee = await _supabase
          .from('employees')
          .select('*, attendance_role, purchase_role')
          .eq('email', user.email!)
          .single();

      if (employee == null) {
        await FlutterAppBadger.removeBadge();
        return;
      }

      int totalCount = 0;
      
      // 역할 파싱
      final attendanceRoles = (employee['attendance_role'] as List<dynamic>?) ?? [];
      final purchaseRoles = _parsePurchaseRoles(employee['purchase_role']);
      final isSuperAdmin = attendanceRoles.contains('superadmin');
      final isAppAdmin = purchaseRoles.contains('app_admin');
      final isPurchaseApprover = purchaseRoles.contains('purchase_approver');
      final isFinalApprover = purchaseRoles.contains('final_approver');

      // 1. 연차/출장 미승인 건수 (매니저 또는 superadmin)
      if (attendanceRoles.any((role) => role.toString().contains('_manager')) || isSuperAdmin) {
        final leaveCount = await _getPendingLeaveCount(
          employee['name'], 
          attendanceRoles,
          isSuperAdmin
        );
        totalCount += leaveCount;
      }

      // 2. 발주 관련 카운트
      if (isPurchaseApprover || isSuperAdmin || isFinalApprover) {
        final purchaseCount = await _getPendingPurchaseCount(
          employee['name'],
          isPurchaseApprover,
          isSuperAdmin,
          isFinalApprover
        );
        totalCount += purchaseCount;
      }

      // 3. 문의 미처리 건수 (app_admin만)
      if (isAppAdmin) {
        final inquiryCount = await _getUnprocessedInquiryCount();
        totalCount += inquiryCount;
      }

      // 배지 업데이트
      if (totalCount > 0) {
        await FlutterAppBadger.updateBadgeCount(totalCount);
      } else {
        await FlutterAppBadger.removeBadge();
      }

      if (kDebugMode) {
        print('📛 Badge count updated: $totalCount');
        print('   - Roles: $attendanceRoles');
        print('   - Purchase roles: $purchaseRoles');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Badge count update failed: $e');
      }
      // 에러 시 배지 제거
      try {
        await FlutterAppBadger.removeBadge();
      } catch (_) {}
    }
  }

  /// 연차/출장 미승인 건수 조회
  static Future<int> _getPendingLeaveCount(
    String userName,
    List<dynamic> roles,
    bool isSuperAdmin,
  ) async {
    try {
      var query = _supabase
          .from('leave_requests')
          .select('id', const FetchOptions(count: CountOption.exact));

      if (isSuperAdmin) {
        // superadmin: 모든 pending 건수
        query = query.eq('status', 'pending');
      } else {
        // 팀 매니저: 자기 팀만
        String? teamName;
        for (var role in roles) {
          final roleStr = role.toString();
          if (roleStr.contains('_manager')) {
            teamName = roleStr.replaceAll('_manager', '');
            break;
          }
        }
        
        if (teamName == null) return 0;
        
        query = query
            .eq('status', 'pending')
            .eq('team', teamName);
      }

      final response = await query.count();
      return response.count ?? 0;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get leave count: $e');
      }
      return 0;
    }
  }

  /// 발주 미승인 건수 조회
  static Future<int> _getPendingPurchaseCount(
    String userName,
    bool isPurchaseApprover,
    bool isSuperAdmin,
    bool isFinalApprover,
  ) async {
    try {
      // final_approver: 최종 승인 대기 건만
      if (isFinalApprover && !isSuperAdmin) {
        final response = await _supabase
            .from('purchase_requests')
            .select('id', const FetchOptions(count: CountOption.exact))
            .eq('status', 'approved')  // 1차 승인은 완료됨
            .eq('final_approval_status', 'pending')  // 최종 승인 대기
            .count();
        
        return response.count ?? 0;
      }

      // superadmin: 1차 승인 대기 건만 (최종승인 제외)
      if (isSuperAdmin) {
        final response = await _supabase
            .from('purchase_requests')
            .select('id', const FetchOptions(count: CountOption.exact))
            .or('status.eq.pending,status.eq.대기,status.is.null')
            .count();
        
        return response.count ?? 0;
      }

      // purchase_approver: 자신이 요청한 건 중 미승인
      if (isPurchaseApprover) {
        final response = await _supabase
            .from('purchase_requests')
            .select('id', const FetchOptions(count: CountOption.exact))
            .eq('requester_name', userName)
            .or('status.eq.pending,status.eq.대기,status.is.null')
            .count();
        
        return response.count ?? 0;
      }

      return 0;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get purchase count: $e');
      }
      return 0;
    }
  }

  /// 문의 미처리 건수 조회 (app_admin용)
  static Future<int> _getUnprocessedInquiryCount() async {
    try {
      final response = await _supabase
          .from('support_inquiries')
          .select('id', const FetchOptions(count: CountOption.exact))
          .or('status.eq.open,status.eq.in_progress')
          .count();
      
      return response.count ?? 0;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get inquiry count: $e');
      }
      return 0;
    }
  }

  /// purchase_role 파싱 헬퍼
  static List<String> _parsePurchaseRoles(dynamic purchaseRole) {
    if (purchaseRole == null) return [];
    
    if (purchaseRole is List) {
      return purchaseRole.map((e) => e.toString()).toList();
    } else if (purchaseRole is String) {
      return purchaseRole.split(',').map((e) => e.trim()).toList();
    }
    
    return [];
  }

  /// 실시간 구독 설정 (배지 자동 업데이트)
  static void setupRealtimeSubscription() {
    // 연차/출장 변경 감지
    _supabase
        .channel('leave_requests_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leave_requests',
          callback: (_) => updateBadgeCount(),
        )
        .subscribe();

    // 발주 변경 감지
    _supabase
        .channel('purchase_requests_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchase_requests',
          callback: (_) => updateBadgeCount(),
        )
        .subscribe();

    // 문의 변경 감지
    _supabase
        .channel('support_inquiries_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_inquiries',
          callback: (_) => updateBadgeCount(),
        )
        .subscribe();
  }

  /// 구독 해제
  static void removeSubscriptions() {
    _supabase.removeChannel(_supabase.channel('leave_requests_badge'));
    _supabase.removeChannel(_supabase.channel('purchase_requests_badge'));
    _supabase.removeChannel(_supabase.channel('support_inquiries_badge'));
  }
}