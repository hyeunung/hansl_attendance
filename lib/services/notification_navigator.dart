import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';
import '../screens/main_tab.dart';
import '../screens/inquiry/inquiry_screen.dart';
import '../screens/notification/notification_center_screen.dart';
import '../utils/user_role_helper.dart';

/// 알림 종류별 이동 대상
enum NotificationDestination {
  leaveApproval, // 승인관리 > 연차/출장 (연차·출장·차량·카드 요청)
  purchaseApproval, // 승인관리 > 발주승인
  purchaseStatus, // 승인관리 > 입고대기 (발주 진행 결과)
  myLeave, // 연차/출장 탭 (내 요청 결과)
  transactionStatement, // 거래명세서 탭
  inquiry, // 문의 화면
  attendance, // 근무기록 탭
  notificationCenter, // 알림 센터 (묶음 알림)
  none, // 앱 내 대상 화면 없음 (웹 전용 알림 등)
}

/// 알림 탭 시 화면 이동을 담당 (알림 센터 / 푸시 탭 공용)
class NotificationNavigator {
  NotificationNavigator._();

  // MainTab 탭 인덱스 (모든 사용자 레이아웃에서 0~3은 동일)
  static const int _attendanceTab = 0;
  static const int _leaveTab = 1;
  static const int _approvalTab = 2;
  static const int _transactionStatementTab = 3;

  // ApprovalScreen 메인 탭 인덱스
  static const int _leaveApprovalSubTab = 0;
  static const int _purchaseApprovalSubTab = 1;
  static const int _purchaseWaitingSubTab = 2;
  static const int _receivingSubTab = 3;

  /// 실제 알림 종류 추출
  /// notifications.type 칼럼은 'admin', 'user', 'purchase_status_change' 같은 묶음 값이므로
  /// data.type(세부 종류)을 우선 사용
  static String resolveType(Map<String, dynamic> notification) {
    final data = notification['data'];
    if (data is Map && data['type'] is String && (data['type'] as String).isNotEmpty) {
      return data['type'] as String;
    }
    return (notification['type'] as String?) ?? '';
  }

  static NotificationDestination destinationOf(String type) {
    switch (type) {
      case 'leave_request':
      case 'business_trip':
      case 'leave_cancelled':
      case 'card_usage_requested':
      case 'vehicle_requested':
        return NotificationDestination.leaveApproval;
      case 'purchase_requests':
      case 'purchase_approval':
      case 'final_approval_request':
        return NotificationDestination.purchaseApproval;
      case 'purchase_approved':
      case 'purchase_result':
      case 'purchase_status_change':
        return NotificationDestination.purchaseStatus;
      case 'leave_result':
      case 'leave_status_change':
      case 'leave_update':
      case 'business_trip_approved':
      case 'card_usage_approved':
      case 'vehicle_approved':
        return NotificationDestination.myLeave;
      case 'transaction_statement_extracted':
      case 'transaction_statement_quantities_matched':
        return NotificationDestination.transactionStatement;
      case 'inquiry_resolved':
      case 'inquiry_message':
      case 'new_vendor_inquiry':
      case 'new_vendor_registered':
        return NotificationDestination.inquiry;
      case 'attendance_late':
        return NotificationDestination.attendance;
      case 'notification_summary':
      case 'grouped_notification':
      case 'multiple_notifications':
        return NotificationDestination.notificationCenter;
      default:
        return NotificationDestination.none;
    }
  }

  /// 알림 종류에 맞는 화면으로 이동
  /// 이동할 화면이 없으면 false 반환 (호출 측에서 현재 화면 유지)
  static Future<bool> open(
    NavigatorState navigator,
    String type, {
    Map<String, dynamic>? data,
    String? body,
  }) async {
    final destination = destinationOf(type);
    if (destination == NotificationDestination.none) return false;

    if (destination == NotificationDestination.notificationCenter) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
      );
      return true;
    }

    final employee = await _loadEmployee(navigator.context);
    final roles = UserRoleHelper.getRoles(employee);

    int tabIndex;
    int? approvalSubTab;
    String? approvalSearchQuery;
    switch (destination) {
      case NotificationDestination.leaveApproval:
        tabIndex = _approvalTab;
        approvalSubTab = _leaveApprovalSubTab;
        break;
      case NotificationDestination.purchaseApproval:
        // 승인 요청 알림은 처리 여부와 무관하게 발주승인 탭으로 이동
        tabIndex = _approvalTab;
        final orderNumber = _purchaseOrderNumberOf(data, body);
        if (UserRoleHelper.hasPurchaseApprovalAuth(roles)) {
          approvalSubTab = _purchaseApprovalSubTab;
        } else {
          approvalSubTab = await _purchaseSubTabFor(orderNumber, canApprove: false);
          approvalSearchQuery = orderNumber;
        }
        break;
      case NotificationDestination.purchaseStatus:
        // 최종 승인 후 진행 요청: 구매 요청 → 구매대기, 발주 → 입고대기
        tabIndex = _approvalTab;
        approvalSearchQuery = _purchaseOrderNumberOf(data, body);
        final category = data?['payment_category']?.toString();
        if (type == 'purchase_approved' && category == '구매 요청') {
          approvalSubTab = _purchaseWaitingSubTab;
        } else if (type == 'purchase_approved' && category == '발주') {
          approvalSubTab = _receivingSubTab;
        } else {
          approvalSubTab = await _purchaseSubTabFor(
            approvalSearchQuery,
            canApprove: UserRoleHelper.hasPurchaseApprovalAuth(roles),
          );
        }
        break;
      case NotificationDestination.myLeave:
        tabIndex = _leaveTab;
        break;
      case NotificationDestination.transactionStatement:
        tabIndex = _transactionStatementTab;
        break;
      default:
        tabIndex = _attendanceTab;
    }

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainTab(
          initialIndex: tabIndex,
          approvalSubTab: approvalSubTab,
          approvalSearchQuery: approvalSearchQuery,
          initialEmployee: employee,
        ),
      ),
      (route) => false,
    );

    if (destination == NotificationDestination.inquiry) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const InquiryScreen()),
      );
    }
    return true;
  }

  /// 발주번호 추출 - data에 없는 이전 알림은 본문 괄호 안의 번호 사용
  /// 예: "홍길동님이 구매 요청 요청(F20260923_026)을 등록했습니다."
  static String? _purchaseOrderNumberOf(Map<String, dynamic>? data, String? body) {
    final fromData = data?['purchase_order_number']?.toString();
    if (fromData != null && fromData.isNotEmpty) return fromData;
    if (body == null) return null;
    return RegExp(r'\(([A-Za-z0-9_\-]+)\)').firstMatch(body)?.group(1);
  }

  /// 발주 건의 현재 진행 단계에 맞는 승인관리 서브탭
  /// (알림 발송 이후 단계가 바뀌었을 수 있으므로 알림 종류가 아닌 현재 상태 기준)
  static Future<int> _purchaseSubTabFor(
    String? purchaseOrderNumber, {
    required bool canApprove,
  }) async {
    final fallback = canApprove ? _purchaseApprovalSubTab : _receivingSubTab;
    if (purchaseOrderNumber == null || purchaseOrderNumber.isEmpty) {
      return fallback;
    }

    try {
      final purchase = await Supabase.instance.client
          .from('purchase_requests')
          .select(
            'middle_manager_status, final_manager_status, payment_category, is_payment_completed, is_received',
          )
          .eq('purchase_order_number', purchaseOrderNumber)
          .limit(1)
          .maybeSingle();
      if (purchase == null) return fallback;

      final middle = purchase['middle_manager_status'];
      final finalStatus = purchase['final_manager_status'];
      final isRejected = middle == 'rejected' || finalStatus == 'rejected';
      final isApprovalPending =
          !isRejected && (middle == 'pending' || finalStatus == 'pending');

      if (isApprovalPending && canApprove) return _purchaseApprovalSubTab;
      if (purchase['payment_category'] == '구매 요청' &&
          purchase['is_payment_completed'] != true) {
        return _purchaseWaitingSubTab;
      }
      if (purchase['is_received'] != true) return _receivingSubTab;
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<Map<String, dynamic>?> _loadEmployee(BuildContext context) async {
    final cached = Provider.of<UserProvider>(context, listen: false).employee;
    if (cached != null) return cached;

    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return null;
    try {
      return await Supabase.instance.client
          .from('employees')
          .select()
          .eq('email', email)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
}
