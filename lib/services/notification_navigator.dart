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
  static Future<bool> open(NavigatorState navigator, String type) async {
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
    switch (destination) {
      case NotificationDestination.leaveApproval:
        tabIndex = _approvalTab;
        approvalSubTab = _leaveApprovalSubTab;
        break;
      case NotificationDestination.purchaseApproval:
        tabIndex = _approvalTab;
        approvalSubTab = UserRoleHelper.hasPurchaseApprovalAuth(roles)
            ? _purchaseApprovalSubTab
            : _receivingSubTab;
        break;
      case NotificationDestination.purchaseStatus:
        tabIndex = _approvalTab;
        approvalSubTab = _receivingSubTab;
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
