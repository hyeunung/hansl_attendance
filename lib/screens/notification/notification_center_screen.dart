import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../widgets/shared/flat_section.dart';
import '../../services/notification_navigator.dart';
import '../../widgets/adaptive/detail_pane.dart';

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

  // DB/FCM에서 "\\n" 형태로 들어오는 경우가 있어 실제 줄바꿈으로 복원
  String _normalizeNewlines(String text) {
    return text
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n');
  }

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

      if (!mounted) return;
      AppBanner.show(context, '모든 알림을 읽음으로 표시했습니다', type: BannerType.info);
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

      if (!mounted) return;
      AppBanner.show(context, '알림을 삭제했습니다', type: BannerType.info);
    } catch (e) {
      // Debug print removed
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'leave_request':
      case 'annual':
      case 'leave_cancelled':
        return Icons.beach_access_outlined;
      case 'business_trip':
      case 'biztrip':
      case 'vehicle_requested':
        return Icons.directions_car_outlined;
      case 'leave_result':
      case 'leave_status_change':
      case 'leave_update':
      case 'business_trip_approved':
      case 'card_usage_approved':
      case 'vehicle_approved':
        return Icons.check_circle_outline;
      case 'card_usage_requested':
        return Icons.credit_card;
      case 'transaction_statement_extracted':
      case 'transaction_statement_quantities_matched':
        return Icons.description_outlined;
      case 'inquiry_resolved':
      case 'inquiry_message':
      case 'new_vendor_inquiry':
      case 'new_vendor_registered':
        return Icons.forum_outlined;
      case 'attendance_late':
        return Icons.schedule;
      case 'purchase_requests':
      case 'purchase_approval':
      case 'final_approval_request':
        return Icons.inventory_2_outlined;
      case 'purchase_approved':
      case 'purchase_result':
        return Icons.receipt_long_outlined;
      case 'notification_summary':
      case 'grouped_notification':
      case 'multiple_notifications':
        return Icons.notifications_none;
      default:
        return Icons.campaign_outlined;
    }
  }

  /// 제목 앞에 붙은 이모지 제거 (좌측 아이콘과 의미 중복)
  String _stripLeadingEmoji(String title) {
    final cleaned = title.replaceFirst(
      RegExp(r'^[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\s]+', unicode: true),
      '',
    );
    return cleaned.isEmpty ? title : cleaned;
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'leave_request':
      case 'annual':
      case 'leave_cancelled':
      case 'inquiry_resolved':
      case 'inquiry_message':
      case 'new_vendor_inquiry':
      case 'new_vendor_registered':
        return AppColors.info;
      case 'business_trip':
      case 'biztrip':
      case 'vehicle_requested':
      case 'card_usage_requested':
      case 'attendance_late':
        return AppColors.warning;
      case 'leave_result':
      case 'leave_status_change':
      case 'leave_update':
      case 'business_trip_approved':
      case 'card_usage_approved':
      case 'vehicle_approved':
      case 'transaction_statement_extracted':
      case 'transaction_statement_quantities_matched':
        return AppColors.success;
      case 'purchase_requests':
      case 'purchase_approval':
      case 'final_approval_request':
        return AppColors.purple;
      case 'purchase_approved':
      case 'purchase_result':
        return AppColors.success;
      case 'notification_summary':
      case 'grouped_notification':
      case 'multiple_notifications':
        return AppColors.primary;
      default:
        return AppColors.gray500;
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
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: AppBarTitle('알림'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                '모두 읽음',
                style: AppTextStyles.tableCell(context, color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? FlatEmptyState(
                message: '알림이 없습니다',
                icon: Icons.notifications_none,
              )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadNotifications();
                if (context.mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
              },
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.spacing(context, 12),
                ),
                itemCount: _notifications.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildCardEdge(
                      isFirst: true,
                      isLast: false,
                      child: FlatCardHeader(
                        title: '알림',
                        icon: Icons.notifications_none,
                        iconColor: AppColors.primary,
                        trailing: Text(
                          unreadCount > 0
                              ? '미확인 $unreadCount · 전체 ${_notifications.length}'
                              : '전체 ${_notifications.length}',
                          style: AppTextStyles.listSubtitle(context),
                        ),
                      ),
                    );
                  }
                  final notification = _notifications[index - 1];
                  final isRead = notification['is_read'] ?? false;
                  // 좌측 아이콘과 중복되므로 제목 앞 이모지 제거
                  final title = _stripLeadingEmoji(
                      _normalizeNewlines((notification['title'] ?? '').toString()));
                  final body =
                      _normalizeNewlines((notification['body'] ?? '').toString());
                  final notifType = NotificationNavigator.resolveType(notification);
                  final notifColor = _getNotificationColor(notifType);

                  return _buildCardEdge(
                    isFirst: false,
                    isLast: index == _notifications.length,
                    child: Dismissible(
                      key: Key(notification['id'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: AppColors.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 20),
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
                          color: isRead
                              ? Colors.white
                              : AppColors.primary.withValues(alpha: 0.04),
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacing(context, 14),
                            vertical: ResponsiveUtils.spacing(context, 8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: notifColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getNotificationIcon(notifType),
                                  size: 16,
                                  color: notifColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: AppTextStyles.tableCell(
                                              context,
                                              color: isRead
                                                  ? AppColors.textSecondary
                                                  : AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDate(notification['created_at']),
                                          style: AppTextStyles.listSubtitle(context),
                                        ),
                                        if (!isRead) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      body,
                                      style: AppTextStyles.listSubtitle(context),
                                      softWrap: true,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  /// 리스트 항목을 카드처럼 보이게 감싸는 테두리 조각 (지연 렌더링 유지)
  Widget _buildCardEdge({
    required bool isFirst,
    required bool isLast,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: isFirst
                ? const BorderSide(color: AppColors.border)
                : BorderSide.none,
            left: const BorderSide(color: AppColors.border),
            right: const BorderSide(color: AppColors.border),
            // 둥근 모서리는 테두리 색이 모두 같아야 그려진다 (변마다 다르면 페인트 오류)
            bottom: const BorderSide(color: AppColors.border),
          ),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isFirst ? 10 : 0),
            bottom: Radius.circular(isLast ? 10 : 0),
          ),
        ),
        child: child,
      ),
    );
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    // 알림 종류(data.type)에 맞는 화면으로 이동, 대상 화면이 없으면 알림 센터 유지
    if (!mounted) return;
    final type = NotificationNavigator.resolveType(notification);
    final data = notification['data'];
    await NotificationNavigator.open(
      // 펼친 폴더블 오른쪽 패널 안에서 열렸다면 패널이 아닌 앱 전체 Navigator로 이동
      Navigator.of(context, rootNavigator: DetailPane.isInside(context)),
      type,
      data: data is Map ? Map<String, dynamic>.from(data) : null,
      body: notification['body']?.toString(),
    );
  }
}
