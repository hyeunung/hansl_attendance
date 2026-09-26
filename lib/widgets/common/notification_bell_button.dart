import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../screens/notification/notification_center_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';

/// AppBar 우측 알림 아이콘 + 미확인 배지 (모든 메인 탭 공용)
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final unreadCount = notificationProvider.unreadCount;
        return Padding(
          padding: EdgeInsets.only(
            right: ResponsiveUtils.spacing(context, 16),
          ),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textPrimary,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationCenterScreen(),
                    ),
                  ).then((_) {
                    // 알림 센터에서 돌아오면 알림 개수 새로고침
                    notificationProvider.loadNotifications();
                  });
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: AppTextStyles.compactLabel(context).copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
