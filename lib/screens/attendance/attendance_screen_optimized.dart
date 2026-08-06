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
import '../../widgets/attendance/personal_late_statistics.dart';
import '../../widgets/attendance/today_absence_widget.dart';
import '../../widgets/attendance/tomorrow_absence_widget.dart';
import '../../widgets/attendance/today_vehicle_widget.dart';
import '../../widgets/attendance/absent_late_widget.dart';
import '../notification/notification_center_screen.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../providers/leave_provider.dart';

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
  bool _isNonWorkingDay = false;
  final _vehicleKey = GlobalKey<TodayVehicleWidgetState>();
  final _absentLateKey = GlobalKey<AbsentLateWidgetState>();
  final _myLateKey = GlobalKey<PersonalLateStatisticsState>();

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
    if (!mounted) return;
    AppBanner.show(
      context,
      msg,
      type: error ? BannerType.error : BannerType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수

    // FontProvider와 AttendanceProvider 모두 감지하도록 Consumer2 사용
    return Consumer2<AttendanceProvider, FontProvider>(
      builder: (context, attendanceProvider, fontProvider, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            shape: const Border(
              bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
            ),
            title: AppBarTitle('근무 기록'),
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
                            color: AppColors.textPrimary,
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
                                color: AppColors.error,
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
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
                    await Future.wait([
                      attendanceProvider.forceRefreshAll(),
                      _vehicleKey.currentState?.refresh() ?? Future.value(),
                      _absentLateKey.currentState?.refresh() ?? Future.value(),
                      _myLateKey.currentState?.refresh() ?? Future.value(),
                      leaveProvider.fetchTodayLeaves(DateTime.now()),
                      leaveProvider.fetchTomorrowLeaves(),
                    ]);
                    _showBanner('새로고침 완료');
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      // 출근/퇴근 버튼 - 휴일/공휴일에 숨김
                      if (!_isNonWorkingDay)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacing(context, 16),
                            vertical: ResponsiveUtils.spacing(context, 12),
                          ),
                          child: AttendanceActionButtons(onShowBanner: _showBanner),
                        ),

                      // 나의 지각 현황 (이번 달/올해) — 지각이 있을 때만 표시
                      PersonalLateStatistics(key: _myLateKey),

                      // 미출근/지각자 (드롭다운)
                      AbsentLateWidget(key: _absentLateKey),

                      // 금일 차량 현황
                      TodayVehicleWidget(
                        key: _vehicleKey,
                        onWorkingDayStatusChanged: (isNonWorkingDay) {
                          setState(() {
                            _isNonWorkingDay = isNonWorkingDay;
                          });
                        },
                      ),

                      // 오늘의 근태현황 (연차/출장/공가)
                      const TodayAbsenceWidget(),

                      // 내일의 근태현황 (연차/출장/공가)
                      const TomorrowAbsenceWidget(),

                      // 하단 여백
                      SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                    ],
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
