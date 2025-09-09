import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../services/timer_manager.dart';
import '../../services/ui_optimization_service.dart';
import '../../widgets/attendance/attendance_status_card.dart';
import '../../widgets/attendance/attendance_action_buttons.dart';
import '../../widgets/attendance/attendance_summary_card.dart';
import '../../widgets/attendance/attendance_history_card.dart';
import '../notification/notification_center_screen.dart';

class AttendanceScreenOptimized extends StatefulWidget {
  final bool autoShowCheckIn;
  final bool autoShowCheckOut;

  const AttendanceScreenOptimized({
    super.key,
    this.autoShowCheckIn = false,
    this.autoShowCheckOut = false,
  });

  @override
  State<AttendanceScreenOptimized> createState() =>
      _AttendanceScreenOptimizedState();
}

class _AttendanceScreenOptimizedState extends State<AttendanceScreenOptimized>
    with
        AutomaticKeepAliveClientMixin,
        TimerManagementMixin,
        UIOptimizationMixin {
  String? _bannerMessage;
  Color _bannerColor = const Color(0xFF357AE8);

  // UI update frequency optimization
  static const Duration _uiUpdateInterval = Duration(seconds: 5);
  bool _shouldUpdateUI = true;

  @override
  bool get wantKeepAlive => true; // 화면 상태 유지

  @override
  void initState() {
    super.initState();
    _startOptimizedUITimer();
  }

  void _startOptimizedUITimer() {
    // Use optimized timer with reduced frequency
    createScopedPeriodicTimer(
      key: 'ui_update',
      interval: _uiUpdateInterval,
      callback: (timer) {
        if (mounted && _shouldUpdateUI) {
          setState(() {
            // Only update if there are active working states that need time updates
            final provider = Provider.of<AttendanceProvider>(
              context,
              listen: false,
            );
            _shouldUpdateUI =
                provider.status == AttendanceStatus.working ||
                provider.status == AttendanceStatus.late;
          });
        }
      },
    );

    // Add a fast timer for critical UI updates (only when actively working)
    _scheduleSmartUIUpdates();
  }

  void _scheduleSmartUIUpdates() {
    // Smart UI updates that adjust frequency based on user activity
    createScopedPeriodicTimer(
      key: 'smart_ui_update',
      interval: const Duration(minutes: 1),
      callback: (timer) {
        if (!mounted) return;

        final provider = Provider.of<AttendanceProvider>(
          context,
          listen: false,
        );

        // Increase frequency when actively working, decrease when idle
        if (provider.status == AttendanceStatus.working ||
            provider.status == AttendanceStatus.late) {
          _shouldUpdateUI = true;
          // Trigger immediate update for work duration display
          if (mounted) setState(() {});
        } else {
          _shouldUpdateUI = false;
        }
      },
    );
  }

  @override
  void dispose() {
    // Dispose all scoped timers
    disposeScopedTimers();
    super.dispose();
  }

  void _showBanner(String msg, {bool error = false}) {
    // Use optimized setState with throttling
    optimizedSetState(() {
      _bannerMessage = msg;
      _bannerColor = error ? Colors.red : const Color(0xFF357AE8);
    });

    // Use scoped timer for banner auto-hide
    createScopedTimer(
      key: 'banner_hide',
      delay: const Duration(seconds: 3),
      callback: () {
        if (mounted) {
          optimizedSetState(() => _bannerMessage = null);
        }
      },
      forceRestart: true, // Always restart timer for new banners
    );
  }

  Widget _buildBanner() {
    if (_bannerMessage == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: _bannerColor,
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.spacing(context, 12),
      ),
      child: Center(
        child: Text(
          _bannerMessage!,
          style: ResponsiveUtils.getTextStyle(
            context,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수

    return OptimizedConsumer<AttendanceProvider>(
      componentKey: 'attendance_main',
      throttleDuration: const Duration(milliseconds: 100),
      shouldRebuild: (provider) => !provider.isLoading,
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
            ),
            title: Text('근무 기록', style: AppTextStyles.appBarTitle(context)),
            actions: [
              // 알림 아이콘과 배지
              Consumer<NotificationProvider>(
                builder: (context, notificationProvider, _) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: ResponsiveUtils.spacing(context, 16),
                    ),
                    child: Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationCenterScreen(),
                              ),
                            ).then((_) {
                              // 알림 센터에서 돌아오면 알림 개수 새로고침
                              notificationProvider.loadNotifications();
                            });
                          },
                        ),
                        if (notificationProvider.unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Center(
                                child: Text(
                                  notificationProvider.unreadCount > 99
                                      ? '99+'
                                      : notificationProvider.unreadCount
                                            .toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _buildBanner(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await provider.forceRefreshAll();
                    _showBanner('새로고침 완료');
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 20),
                      vertical: ResponsiveUtils.spacing(context, 20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 현재 상태 카드
                        const AttendanceStatusCard(),
                        SizedBox(height: ResponsiveUtils.spacing(context, 25)),

                        // 출근/퇴근 버튼
                        AttendanceActionButtons(onShowBanner: _showBanner),
                        SizedBox(height: ResponsiveUtils.spacing(context, 25)),

                        // 오늘의 근무 요약 카드
                        const AttendanceSummaryCard(),
                        SizedBox(height: ResponsiveUtils.spacing(context, 25)),

                        // 최근 기록 카드
                        const AttendanceHistoryCard(),
                      ],
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
