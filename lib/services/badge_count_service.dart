import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import '../utils/user_role_helper.dart';

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

      int totalCount = 0;
      
      // 역할 파싱
      final attendanceRoles = (employee['attendance_role'] as List<dynamic>?) ?? [];
      final purchaseRoles = _parsePurchaseRoles(employee['purchase_role']);
      
      // UserRoleHelper 사용 (app_admin이면 자동으로 다른 권한도 true)
      final isSuperAdmin = UserRoleHelper.isSuperAdmin(attendanceRoles);
      final isAppAdmin = UserRoleHelper.isAppAdmin(purchaseRoles);
      final isMiddleManager = UserRoleHelper.isMiddleManager(purchaseRoles);
      final isRawMaterialManager = UserRoleHelper.isRawMaterialManager(purchaseRoles);
      final isConsumableManager = UserRoleHelper.isConsumableManager(purchaseRoles);
      final isLeadBuyer = UserRoleHelper.isLeadBuyer(purchaseRoles); // app_admin 포함됨
      

      if (isSuperAdmin || isAppAdmin) {
        final leaveCount = await _getPendingLeaveCount();
        totalCount += leaveCount;
      }

      // 2. 발주 관련 카운트
      if (isMiddleManager || isRawMaterialManager || isConsumableManager || isLeadBuyer || isAppAdmin) {
        final purchaseCount = await _getPendingPurchaseCount(
          isMiddleManager || isAppAdmin,
          isRawMaterialManager,
          isConsumableManager,
          isLeadBuyer,
          isAppAdmin,
          purchaseRoles,
          employee
        );
        totalCount += purchaseCount;
      }

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

      // Debug code removed

    } catch (e) {
      // Debug code removed
      // 에러 시 배지 제거
      try {
        await FlutterAppBadger.removeBadge();
      } catch (_) {}
    }
  }

  /// 연차/출장 미승인 건수 조회 (SuperAdmin, app_admin용)
  static Future<int> _getPendingLeaveCount() async {
    try {
      final response = await _supabase
          .from('leave')
          .select()
          .eq('approval_status', 'pending')
          .count();
      
      return response.count;
      
    } catch (e) {
      // Debug code removed
      return 0;
    }
  }

  /// 발주 미승인 건수 조회
  static Future<int> _getPendingPurchaseCount(
    bool isMiddleManager,
    bool isRawMaterialManager,
    bool isConsumableManager,
    bool isLeadBuyer,
    bool isAppAdmin,
    List<dynamic> purchaseRoles,
    Map<String, dynamic> employee,
  ) async {
    try {
      int count = 0;
      
      // middle_manager: 1차 승인 대기
      if (isMiddleManager) {
        final response = await _supabase
            .from('purchase_requests')
            .select()
            .eq('middle_manager_status', 'pending')
            .count();
        count += response.count;
      }
      
      // raw_material_manager: 원자재 최종 승인 대기
      if (isRawMaterialManager) {
        final response = await _supabase
            .from('purchase_requests')
            .select()
            .eq('payment_category', '원자재')
            .eq('middle_manager_status', 'approved')
            .eq('raw_material_manager_status', 'pending')
            .count();
        count += response.count;
      }
      
      // consumable_manager: 소모품 최종 승인 대기
      if (isConsumableManager) {
        final response = await _supabase
            .from('purchase_requests')
            .select()
            .eq('payment_category', '소모품')
            .eq('middle_manager_status', 'approved')
            .eq('consumable_manager_status', 'pending')
            .count();
        count += response.count;
      }
      
      // 구매현황 조회 권한이 있는 경우: 구매대기/입고대기 카운트
      if (UserRoleHelper.canViewPurchaseStatus(purchaseRoles)) {
        // 1. 구매대기: progress_type 조건 추가 (웹앱과 동일)
        // 선진행은 무조건, 일반은 승인완료된 것만
        var purchaseWaitingQuery = _supabase
            .from('purchase_requests')
            .select()
            .eq('payment_category', '구매 요청')
            .eq('is_payment_completed', false);

        // 권한에 따른 필터링: lead buyer, app_admin이 아닌 경우 본인 것만 조회
        if (!isAppAdmin && !isLeadBuyer) {
          final userName = employee['name'] as String? ?? '';
          purchaseWaitingQuery = purchaseWaitingQuery.eq('requester_name', userName);
        }

        final purchaseWaitingQueryResult = await purchaseWaitingQuery;
        
        // progress_type 조건으로 필터링
        final purchaseWaitingFiltered = (purchaseWaitingQueryResult as List).where((item) {
          final progressType = item['progress_type'] ?? '';
          final finalStatus = item['final_manager_status'] ?? '';
          
          // 선진행은 무조건 포함
          if (progressType.toString().contains('선진행')) return true;
          // 일반은 최종승인 완료된 것만
          if (progressType.toString().contains('일반') && finalStatus == 'approved') return true;
          
          return false;
        }).toList();
        
        final purchaseWaitingCount = purchaseWaitingFiltered.length;
        count += purchaseWaitingCount;
        
        // 2. 입고대기: 미입고 AND (선진행 OR 최종승인)
        var receivingWaitingQuery = _supabase
            .from('purchase_requests')
            .select()
            .eq('is_received', false);  // 미입고만 체크

        // 권한에 따른 필터링: 전체 보기 권한이 없는 경우 본인 것만 조회
        final isMiddleManager = UserRoleHelper.isMiddleManager(purchaseRoles);
        final isFinalApprover = UserRoleHelper.isFinalApprover(purchaseRoles);
        final isPurchaseManager = purchaseRoles.contains('purchase_manager');
        final isCeo = purchaseRoles.contains('ceo');
        final hasFullAccess = isAppAdmin || isLeadBuyer || isMiddleManager || isFinalApprover || isCeo;
        
        if (!hasFullAccess) {
          final userName = employee['name'] as String? ?? '';
          receivingWaitingQuery = receivingWaitingQuery.eq('requester_name', userName);
        }

        final receivingWaitingResult = await receivingWaitingQuery;
        
        // progress_type 조건으로 필터링: 선진행 OR 최종승인
        final receivingWaitingFiltered = (receivingWaitingResult as List).where((item) {
          final progressType = item['progress_type'] ?? '';
          final finalStatus = item['final_manager_status'] ?? '';
          
          // 선진행은 무조건 포함
          if (progressType.toString().contains('선진행')) return true;
          // 최종승인 완료된 것 포함
          if (finalStatus == 'approved') return true;
          
          return false;
        }).toList();
        
        final receivingWaitingCount = receivingWaitingFiltered.length;
        count += receivingWaitingCount;
      }
      
      return count;
      
    } catch (e) {
      // Debug code removed
      return 0;
    }
  }

  /// 문의 미처리 건수 조회 (app_admin용)
  static Future<int> _getUnprocessedInquiryCount() async {
    try {
      final response = await _supabase
          .from('support_inquiries')
          .select()
          .or('status.eq.open,status.eq.in_progress')
          .count();
      
      return response.count;
      
    } catch (e) {
      // Debug code removed
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