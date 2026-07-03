import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import '../utils/user_role_helper.dart';

/// 앱 아이콘 배지 카운트 관리 서비스
class BadgeCountService {
  
  static final _supabase = Supabase.instance.client;
  static RealtimeChannel? _leaveChannel;
  static RealtimeChannel? _businessTripChannel;
  static RealtimeChannel? _purchaseChannel;
  static RealtimeChannel? _purchaseItemsChannel;
  static RealtimeChannel? _inquiryChannel;
  
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
          .select('*')
          .eq('email', user.email!)
          .single();

      int totalCount = 0;
      
      // 통합 역할 추출
      final roles = UserRoleHelper.getRoles(employee);

      // ========== 권한 판별 ==========
      // 연차/출장 승인 권한(부서장 + admin/superadmin)
      final canApproveLeave = UserRoleHelper.isAnyManager(roles) ||
          UserRoleHelper.isAdminOrSuper(roles);

      // 발주 승인 권한(요구사항: middle_manager/raw_material_manager/consumable_manager만)
      final isMiddleManager = UserRoleHelper.isMiddleManager(roles);
      // 최종 승인 권한(카테고리)은 final_approver 포함 여부까지 함께 봐야 함
      final canManageRawMaterial = UserRoleHelper.canManageRawMaterial(roles);
      final canManageConsumable = UserRoleHelper.canManageConsumable(roles);

      // 구매대기 배지(요구사항: lead_buyer만)
      final isPureLeadBuyer = UserRoleHelper.isPureLeadBuyer(roles);

      // 문의 배지(요구사항: superadmin만)
      final isAppAdmin = UserRoleHelper.isAppAdmin(roles);
      

      // 1) 연차/출장 승인대기
      if (canApproveLeave) {
        final leaveCount = await _getPendingLeaveCount();
        totalCount += leaveCount;
      }

      // 2) 발주 승인대기(역할별로)
      if (isMiddleManager || canManageRawMaterial || canManageConsumable) {
        final purchaseCount = await _getPendingPurchaseCount(
          isMiddleManager: isMiddleManager,
          canManageRawMaterial: canManageRawMaterial,
          canManageConsumable: canManageConsumable,
        );
        totalCount += purchaseCount;
      }

      // 3) 구매대기(lead_buyer)
      if (isPureLeadBuyer) {
        final purchaseWaitingCount = await _getPurchaseWaitingCountForLeadBuyer();
        totalCount += purchaseWaitingCount;
      }

      // 4) 문의 미처리(superadmin)
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

  /// 연차/출장 미승인 건수 조회 (SuperAdmin, superadmin용)
  static Future<int> _getPendingLeaveCount() async {
    try {
      // leave 테이블 pending 건수
      final leaveResponse = await _supabase
          .from('leave')
          .select()
          .eq('status', 'pending')
          .not('type', 'eq', 'biztrip_migrated')
          .count();

      // business_trips 테이블 pending 건수 (최초 pending + 연장 extension_pending)
      final btResponse = await _supabase
          .from('business_trips')
          .select()
          .or('approval_status.eq.pending,modification_status.eq.extension_pending')
          .count();

      return leaveResponse.count + btResponse.count;

    } catch (e) {
      // Debug code removed
      return 0;
    }
  }

  /// 발주 미승인 건수 조회
  static Future<int> _getPendingPurchaseCount({
    required bool isMiddleManager,
    required bool canManageRawMaterial,
    required bool canManageConsumable,
  }) async {
    try {
      // 승인 화면(PurchaseProvider.fetchPendingPurchases)과 동일한 조건 + 발주번호 단위 중복제거
      List<Map<String, dynamic>> rows = [];

      // 요구사항: middle_manager는 superadmin 여부와 관계없이 1차 승인 대기만 카운트
      if (isMiddleManager) {
        final response = await _supabase
            .from('purchase_requests')
            .select('purchase_order_number')
            .eq('middle_manager_status', 'pending');
        rows = List<Map<String, dynamic>>.from(response);
      } else if (canManageRawMaterial) {
        final response = await _supabase
            .from('purchase_requests')
            .select('purchase_order_number')
            .eq('middle_manager_status', 'approved')
            .eq('final_manager_status', 'pending')
            .eq('payment_category', '발주');
        rows = List<Map<String, dynamic>>.from(response);
      } else if (canManageConsumable) {
        final response = await _supabase
            .from('purchase_requests')
            .select('purchase_order_number')
            .eq('middle_manager_status', 'approved')
            .eq('final_manager_status', 'pending')
            .eq('payment_category', '구매 요청');
        rows = List<Map<String, dynamic>>.from(response);
      } else {
        return 0;
      }

      // 중복 제거: 발주번호 단위로 1건만 카운트 (승인 화면과 동일)
      final uniqueOrderNumbers = <String>{};
      for (final r in rows) {
        final n = r['purchase_order_number'];
        if (n != null) uniqueOrderNumbers.add(n.toString());
      }

      return uniqueOrderNumbers.length;
      
    } catch (e) {
      // Debug code removed
      return 0;
    }
  }

  /// 구매대기 건수 (lead_buyer 전용)
  /// - purchase_waiting_widget.dart와 동일한 조건:
  ///   - purchase_requests.payment_category == '구매 요청'
  ///   - purchase_requests.is_payment_completed == false
  ///   - progress_type: '선진행'은 무조건, '일반'은 final_manager_status == 'approved'만
  ///   - 실제 미구매 품목(purchase_request_items.is_payment_completed != true)이 1개 이상 있는 것만
  /// - 카운트 단위: 구매대기 화면에 뜨는 "발주번호(헤더)" 개수
  static Future<int> _getPurchaseWaitingCountForLeadBuyer() async {
    try {
      final response = await _supabase
          .from('purchase_requests')
          .select('purchase_order_number, progress_type, final_manager_status, purchase_request_items(is_payment_completed)')
          .eq('payment_category', '구매 요청')
          .eq('is_payment_completed', false);

      final allPurchases = List<Map<String, dynamic>>.from(response);

      final validOrderNumbers = <String>{};
      for (final purchase in allPurchases) {
        final progressType = (purchase['progress_type'] ?? '').toString();
        final finalStatus = (purchase['final_manager_status'] ?? '').toString();

        // progress_type 필터
        final isPreProgress = progressType.contains('선진행');
        final isNormalApproved = progressType.contains('일반') && finalStatus == 'approved';
        if (!isPreProgress && !isNormalApproved) continue;

        final items = (purchase['purchase_request_items'] as List<dynamic>?) ?? const [];
        final hasPendingItem = items.any((it) {
          final m = Map<String, dynamic>.from(it as Map);
          return m['is_payment_completed'] != true;
        });
        if (!hasPendingItem) continue;

        final orderNumber = purchase['purchase_order_number'];
        if (orderNumber != null) validOrderNumbers.add(orderNumber.toString());
      }

      return validOrderNumbers.length;
    } catch (e) {
      return 0;
    }
  }

  /// 문의 미처리 건수 조회 (관리자용)
  static Future<int> _getUnprocessedInquiryCount() async {
    try {
      final response = await _supabase
          .from('support_inquires')
          .select()
          .or('status.eq.open,status.eq.in_progress')
          .count();

      return response.count;
    } catch (e) {
      return 0;
    }
  }

  /// 실시간 구독 설정 (배지 자동 업데이트)
  static void setupRealtimeSubscription() {
    // 중복 구독 방지
    removeSubscriptions();

    // 연차/출장(leave 테이블) 변경 감지
    _leaveChannel = _supabase
        .channel('leave_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leave',
          callback: (_) => updateBadgeCount(),
        )
        .subscribe();

    // business_trips 변경 감지
    _businessTripChannel = _supabase
        .channel('business_trips_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'business_trips',
          callback: (_) => updateBadgeCount(),
        )
        .subscribe();

    // 발주 변경 감지
    _purchaseChannel = _supabase
        .channel('purchase_requests_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchase_requests',
          callback: (_) => updateBadgeCount(),
        )
        .subscribe();

    // 구매대기에서 품목 완료 처리 시 배지 즉시 반영을 위해 품목 테이블도 감지
    _purchaseItemsChannel = _supabase
        .channel('purchase_request_items_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchase_request_items',
          callback: (_) => updateBadgeCount(),
        )
        .subscribe();

    // 문의 변경 감지
    _inquiryChannel = _supabase
        .channel('support_inquires_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_inquires',
          callback: (_) => updateBadgeCount(),
        )
        .subscribe();
  }

  /// 구독 해제
  static void removeSubscriptions() {
    if (_leaveChannel != null) {
      _supabase.removeChannel(_leaveChannel!);
      _leaveChannel = null;
    }
    if (_businessTripChannel != null) {
      _supabase.removeChannel(_businessTripChannel!);
      _businessTripChannel = null;
    }
    if (_purchaseChannel != null) {
      _supabase.removeChannel(_purchaseChannel!);
      _purchaseChannel = null;
    }
    if (_purchaseItemsChannel != null) {
      _supabase.removeChannel(_purchaseItemsChannel!);
      _purchaseItemsChannel = null;
    }
    if (_inquiryChannel != null) {
      _supabase.removeChannel(_inquiryChannel!);
      _inquiryChannel = null;
    }
  }
}