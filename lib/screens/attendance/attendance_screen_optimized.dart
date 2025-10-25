import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/font_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../services/timer_manager.dart';
import '../../services/ui_optimization_service.dart';
import '../../widgets/attendance/attendance_action_buttons.dart';
import '../../widgets/attendance/attendance_summary_card.dart';
import '../../widgets/attendance/attendance_history_card.dart';
import '../../widgets/attendance/attendance_statistics_widget.dart';
import '../../widgets/attendance/personal_late_statistics.dart';
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
  // Android needs longer intervals to prevent flickering
  static Duration get _uiUpdateInterval => 
      !kIsWeb && Platform.isAndroid 
          ? const Duration(seconds: 10) 
          : const Duration(seconds: 5);
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
        if (mounted) {
          final provider = Provider.of<AttendanceProvider>(
            context,
            listen: false,
          );
          final shouldUpdate =
              provider.status == AttendanceStatus.working ||
              provider.status == AttendanceStatus.late;
          
          // 상태가 변경되었을 때만 setState 호출
          if (shouldUpdate != _shouldUpdateUI) {
            setState(() {
              _shouldUpdateUI = shouldUpdate;
            });
          }
        }
      },
    );

    _scheduleSmartUIUpdates();
  }

  void _scheduleSmartUIUpdates() {
    // Smart UI updates that adjust frequency based on user activity
    // Android: Use longer interval to prevent flickering
    final smartUpdateInterval = !kIsWeb && Platform.isAndroid 
        ? const Duration(minutes: 2)
        : const Duration(minutes: 1);
        
    createScopedPeriodicTimer(
      key: 'smart_ui_update',
      interval: smartUpdateInterval,
      callback: (timer) {
        if (!mounted) return;

        final provider = Provider.of<AttendanceProvider>(
          context,
          listen: false,
        );

        // Increase frequency when actively working, decrease when idle
        final shouldBeActive = provider.status == AttendanceStatus.working ||
            provider.status == AttendanceStatus.late;
        
        // 상태가 변경되었을 때만 setState 호출
        if (shouldBeActive != _shouldUpdateUI) {
          if (mounted) {
            setState(() {
              _shouldUpdateUI = shouldBeActive;
            });
          }
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

    // FontProvider와 AttendanceProvider 모두 감지하도록 Consumer2 사용
    return Consumer2<AttendanceProvider, FontProvider>(
      builder: (context, attendanceProvider, fontProvider, _) {
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
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
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
                    await attendanceProvider.forceRefreshAll();
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
                        // 출근 현황 통계 - 모든 직원에게 표시
                        const AttendanceStatisticsWidget(),

                        const PersonalLateStatistics(),

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
