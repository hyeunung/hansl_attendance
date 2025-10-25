import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';
import '../main_tab.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() => _isLoading = true);

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_email', user.email!)
          .order('created_at', ascending: false);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      // notifications 테이블이 없는 경우 빈 목록 유지
      setState(() {
        _notifications = [];
      });

      // 테이블이 없는 에러가 아닌 경우에만 로그 출력
      if (!e.toString().contains('42P01')) {
        // Debug print removed
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      // 로컬 상태 업데이트
      setState(() {
        final index = _notifications.indexWhere(
          (n) => n['id'] == notificationId,
        );
        if (index != -1) {
          _notifications[index]['is_read'] = true;
          _notifications[index]['read_at'] = DateTime.now().toIso8601String();
        }
      });
    } catch (e) {
      // Debug print removed
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_email', user.email!)
          .eq('is_read', false);

      // 로컬 상태 업데이트
      setState(() {
        for (var notification in _notifications) {
          if (notification['is_read'] == false) {
            notification['is_read'] = true;
            notification['read_at'] = DateTime.now().toIso8601String();
          }
        }
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 알림을 읽음으로 표시했습니다')));
    } catch (e) {
      // Debug print removed
    }
  }

  Future<void> _deleteNotification(int notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);

      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림을 삭제했습니다')));
    } catch (e) {
      // Debug print removed
    }
  }

  String _getNotificationIcon(String type) {
    switch (type) {
      case 'leave_request':
      case 'annual':
        return '🏖️';
      case 'business_trip':
      case 'biztrip':
        return '🚗';
      case 'leave_result':
        return '✅';
      case 'purchase_requests':
      case 'purchase_approval':
      case 'final_approval_request':
        return '📦';
      case 'purchase_approved':
      case 'purchase_result':
        return '💳';
      case 'notification_summary':
      case 'grouped_notification':
      case 'multiple_notifications':
        return '🔔';
      default:
        return '📢';
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'leave_request':
      case 'annual':
        return Colors.blue;
      case 'business_trip':
      case 'biztrip':
        return Colors.orange;
      case 'leave_result':
        return Colors.green;
      case 'purchase_requests':
      case 'purchase_approval':
      case 'final_approval_request':
        return Colors.purple;
      case 'purchase_approved':
      case 'purchase_result':
        return Colors.teal;
      case 'notification_summary':
      case 'grouped_notification':
      case 'multiple_notifications':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM월 dd일').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((n) => n['is_read'] == false)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          '알림',
          style: ResponsiveUtils.getTextStyle(context, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text('모두 읽음', style: ResponsiveUtils.getTextStyle(context, fontSize: 14)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '알림이 없습니다',
                    style: ResponsiveUtils.getTextStyle(context, fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final isRead = notification['is_read'] ?? false;

                  return Dismissible(
                    key: Key(notification['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      _deleteNotification(notification['id']);
                    },
                    child: InkWell(
                      onTap: () async {
                        if (!isRead) {
                          await _markAsRead(notification['id']);
                        }
                        // 알림 타입에 따라 화면 이동
                        _handleNotificationTap(notification);
                      },
                      child: Container(
                        color: isRead ? Colors.white : const Color(0xFFF0F8FF),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _getNotificationColor(
                                        notification['type'] ?? '',
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getNotificationIcon(
                                          notification['type'] ?? '',
                                        ),
                                        style: ResponsiveUtils.getTextStyle(context, fontSize: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notification['title'] ?? '',
                                                style: ResponsiveUtils.getTextStyle(
                                                  context,
                                                  fontSize: 15,
                                                  fontWeight: isRead
                                                      ? FontWeight.w500
                                                      : FontWeight.w600,
                                                  color: isRead
                                                      ? Colors.grey[700]
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notification['body'] ?? '',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 14,
                                            color: isRead
                                                ? Colors.grey[600]
                                                : Colors.grey[700],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(
                                            notification['created_at'],
                                          ),
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey[300]),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    // 알림 타입에 따라 적절한 화면으로 이동
    final type = notification['type'] ?? '';
    // final data = notification['data'] ?? {}; // 미사용 변수 주석 처리

    // 먼저 현재 사용자 정보와 권한 가져오기
    final user = _supabase.auth.currentUser;
    Map<String, dynamic>? employeeData;

    if (user != null) {
      try {
        employeeData = await _supabase
            .from('employees')
            .select('*') // 모든 필드 가져오기
            .eq('email', user.email!)
            .single();
      } catch (e) {
        // Debug print removed
      }
    }

    switch (type) {
      case 'leave_request':
      case 'business_trip':
        // 연차/출장 승인 권한 확인
        final attendanceRoles =
            (employeeData?['attendance_role'] as List<dynamic>?) ?? [];
        final hasApprovalRole = attendanceRoles.any(
          (role) => [
            'admin',
            'superadmin',
            '개발3팀_manager',
            'CAD_manager',
            '개발팀_manager',
            '경영지원팀_manager',
            '연구소_manager',
          ].contains(role),
        );

        if (hasApprovalRole) {
          // MainTab에 employee 정보 전달
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainTab(
                initialIndex: 2, // 승인 탭
                approvalSubTab: 0, // 연차/출장 서브탭
                initialEmployee: employeeData,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainTab(initialIndex: 0),
            ),
          );
        }
        break;

      case 'purchase_requests':
      case 'purchase_approval':
      case 'final_approval_request':
        // 발주 승인 권한 확인
        final attendanceRoles =
            (employeeData?['attendance_role'] as List<dynamic>?) ?? [];
        final purchaseRoles =
            (employeeData?['purchase_role'] as List<dynamic>?) ?? [];

        final hasAttendanceApproval = attendanceRoles.any(
          (role) => [
            'admin',
            'superadmin',
            '개발3팀_manager',
            'CAD_manager',
            '개발팀_manager',
            '경영지원팀_manager',
            '연구소_manager',
          ].contains(role),
        );

        final hasPurchaseApproval = purchaseRoles.any(
          (role) => [
            'middle_manager',
            'raw_material_manager',
            'consumable_manager',
            'app_admin',
          ].contains(role),
        );

        if (hasAttendanceApproval && hasPurchaseApproval) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainTab(
                initialIndex: 2, // 승인 탭
                approvalSubTab: 1, // 발주 서브탭
                initialEmployee: employeeData,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainTab(initialIndex: 0),
            ),
          );
        }
        break;
      case 'leave_result':
        // 연차 현황 탭으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainTab(initialIndex: 1),
          ),
        );
        break;
      case 'purchase_approved':
      case 'purchase_result':
        // 홈으로 이동 (발주 결과)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainTab(initialIndex: 0),
          ),
        );
        break;
      default:
        // 홈으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainTab(initialIndex: 0),
          ),
        );
    }
  }
}
