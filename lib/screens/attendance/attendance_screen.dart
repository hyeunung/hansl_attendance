import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/attendance.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../notification/notification_center_screen.dart';
import '../../services/timer_manager.dart';
import '../../services/ui_optimization_service.dart';
import '../../providers/leave_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 화면 상태 유지

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수

    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, _) {
        return _AttendanceScreenBody();
      },
    );
  }
}

class _AttendanceScreenBody extends StatefulWidget {
  @override
  State<_AttendanceScreenBody> createState() => _AttendanceScreenBodyState();
}

class _AttendanceScreenBodyState extends State<_AttendanceScreenBody>
    with TimerManagementMixin, UIOptimizationMixin {
  String? _bannerMessage;
  Color _bannerColor = const Color(0xFF357AE8);
  bool _isClockInLoading = false;
  bool _isClockOutLoading = false;

  @override
  void initState() {
    super.initState();
    // No unnecessary timers
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
      delay: const Duration(seconds: 2),
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
    return Container(
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

  LinearGradient _getStatusGradient(String statusText) {
    switch (statusText) {
      case '지각':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)], // 빨강 그라데이션
        );
      case '정상 출근':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1777CB), Color(0xFF0D4F8C)], // 파랑 그라데이션
        );
      case '퇴근':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)], // 초록색 그라데이션
        );
      default: // 출근 전
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9E9E9E), Color(0xFF757575)], // 회색 그라데이션
        );
    }
  }

  Color _getStatusShadowColor(String statusText) {
    switch (statusText) {
      case '지각':
        return const Color(0xFFEE5A24).withValues(alpha: 0.3);
      case '정상 출근':
        return const Color(0xFF0D4F8C).withValues(alpha: 0.3);
      case '퇴근':
        return const Color(0xFF45A049).withValues(alpha: 0.3);
      default:
        return const Color(0xFF757575).withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
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
                  return Stack(
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
                  );
                },
              ),
              // 사용자 이름
              Padding(
                padding: EdgeInsets.only(
                  right: ResponsiveUtils.spacing(context, 20),
                ),
                child: OptimizedConsumer<UserProvider>(
                  componentKey: 'user_name_header',
                  throttleDuration: const Duration(
                    seconds: 1,
                  ), // Name rarely changes
                  shouldRebuild: (provider) => provider.name != null,
                  builder: (context, userProvider, _) {
                    final name = userProvider.name ?? '-';
                    return RepaintBoundary(
                      child: Center(
                        child: Text(
                          name,
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              // 모든 탭의 데이터 새로고침
              // 모든 데이터 새로고침
              final attendanceProvider = Provider.of<AttendanceProvider>(
                context,
                listen: false,
              );
              final leaveProvider = Provider.of<LeaveProvider>(
                context,
                listen: false,
              );
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );

              await Future.wait([
                attendanceProvider.forceRefreshAll(),
                attendanceProvider.fetchLateStatistics(), // 지각 통계 새로고침 추가
                if (userProvider.email != null) ...[
                  leaveProvider.fetchAllLeaves(forceRefresh: true),
                  leaveProvider.fetchMyLeaves(
                    email: userProvider.email!,
                    forceRefresh: true,
                  ),
                ],
              ]);
            },
            child: Column(
              children: [
                _buildBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 20),
                      vertical: ResponsiveUtils.spacing(context, 20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 현재 상태 카드
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveUtils.spacing(context, 30),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 20),
                            ),
                            boxShadow: [AppShadows.card],
                            border: Border.all(color: const Color(0xFFE9ECEF)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '현재 상태',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF343A40),
                                ),
                              ),
                              SizedBox(
                                height: ResponsiveUtils.spacing(context, 20),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.spacing(
                                    context,
                                    24,
                                  ),
                                  vertical: ResponsiveUtils.spacing(
                                    context,
                                    12,
                                  ),
                                ),
                                decoration: BoxDecoration(
                                  gradient: _getStatusGradient(
                                    provider.statusText,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveUtils.spacing(context, 25),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getStatusShadowColor(
                                        provider.statusText,
                                      ),
                                      blurRadius: ResponsiveUtils.spacing(
                                        context,
                                        15,
                                      ),
                                      offset: Offset(
                                        0,
                                        ResponsiveUtils.spacing(context, 4),
                                      ),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  provider.statusText,
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: ResponsiveUtils.spacing(context, 15),
                              ),
                              Text(
                                provider.status == AttendanceStatus.offWork
                                    ? '${provider.clockInStr} ~ ${provider.clockOutStr}'
                                    : provider.clockInTime == null
                                    ? '-'
                                    : '${provider.clockInStr} 부터',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: const Color(0xFF6C757D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 25)),
                        // 출근/퇴근 버튼 (흰카드 없이 Row만)
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: ResponsiveUtils.spacing(context, 65),
                                child: GestureDetector(
                                  onTap:
                                      provider.status ==
                                              AttendanceStatus.beforeWork &&
                                          !_isClockInLoading
                                      ? () async {
                                          setState(() {
                                            _isClockInLoading = true;
                                          });
                                          await provider.tryClockIn();
                                          if (mounted) {
                                            setState(() {
                                              _isClockInLoading = false;
                                            });
                                            if (provider.errorMessage != null) {
                                              _showBanner(
                                                provider.errorMessage!,
                                                error: true,
                                              );
                                              provider.clearError();
                                            } else {
                                              // 출근 성공 메시지 표시
                                              final now = DateTime.now();
                                              final hour = now.hour;
                                              final isLate =
                                                  hour >= 9 ||
                                                  (hour == 8 &&
                                                      now.minute > 30);
                                              if (isLate) {
                                                _showBanner(
                                                  '지각 처리되었습니다.',
                                                  error: false,
                                                );
                                              } else {
                                                _showBanner(
                                                  '정상 출근 처리되었습니다.',
                                                  error: false,
                                                );
                                              }
                                            }
                                          }
                                        }
                                      : null,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient:
                                          provider.status ==
                                              AttendanceStatus.beforeWork
                                          ? AppColors.primaryGradient
                                          : null,
                                      color:
                                          provider.status ==
                                              AttendanceStatus.beforeWork
                                          ? null
                                          : const Color(0xFFE9ECEF),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveUtils.spacing(context, 14),
                                      ),
                                      boxShadow: [
                                        if (provider.status ==
                                            AttendanceStatus.beforeWork)
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.32,
                                            ),
                                            blurRadius: ResponsiveUtils.spacing(
                                              context,
                                              7,
                                            ),
                                            offset: Offset(
                                              0,
                                              ResponsiveUtils.spacing(
                                                context,
                                                2,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: _isClockInLoading
                                        ? SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            '출근하기',
                                            style: ResponsiveUtils.getTextStyle(
                                              context,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 21,
                                              color:
                                                  provider.status ==
                                                      AttendanceStatus
                                                          .beforeWork
                                                  ? Colors.white
                                                  : const Color(0xFFB0B0B0),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: ResponsiveUtils.spacing(context, 15),
                            ),
                            Expanded(
                              child: SizedBox(
                                height: ResponsiveUtils.spacing(context, 65),
                                child: GestureDetector(
                                  onTap:
                                      provider.canClockOut &&
                                          !_isClockOutLoading
                                      ? () async {
                                          setState(() {
                                            _isClockOutLoading = true;
                                          });
                                          await provider.tryClockOut();
                                          if (mounted) {
                                            setState(() {
                                              _isClockOutLoading = false;
                                            });
                                            if (provider.errorMessage != null) {
                                              _showBanner(
                                                provider.errorMessage!,
                                                error: true,
                                              );
                                              provider.clearError();
                                            }
                                          }
                                        }
                                      : null,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: provider.canClockOut
                                          ? AppColors.primaryGradient
                                          : null,
                                      color: provider.canClockOut
                                          ? null
                                          : const Color(0xFFE9ECEF),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveUtils.spacing(context, 14),
                                      ),
                                      boxShadow: [
                                        if (provider.canClockOut)
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.32,
                                            ),
                                            blurRadius: ResponsiveUtils.spacing(
                                              context,
                                              7,
                                            ),
                                            offset: Offset(
                                              0,
                                              ResponsiveUtils.spacing(
                                                context,
                                                2,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: _isClockOutLoading
                                        ? SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            '퇴근하기',
                                            style: ResponsiveUtils.getTextStyle(
                                              context,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 21,
                                              color: provider.canClockOut
                                                  ? Colors.white
                                                  : const Color(0xFFB0B0B0),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 25)),
                        // 오늘의 근무 요약 카드
                        Container(
                          padding: EdgeInsets.all(
                            ResponsiveUtils.spacing(context, 25),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 20),
                            ),
                            boxShadow: [AppShadows.card],
                            border: Border.all(color: const Color(0xFFE9ECEF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      ResponsiveUtils.spacing(context, 2),
                                    ),
                                    child: Text(
                                      '💼',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: ResponsiveUtils.spacing(context, 10),
                                  ),
                                  Text(
                                    '오늘의 근무 요약',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 22,
                                      color: const Color(0xFF343A40),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: ResponsiveUtils.spacing(context, 20),
                              ),
                              _buildSummaryItem('출근 시간', provider.clockInStr),
                              if (provider.status == AttendanceStatus.offWork)
                                _buildSummaryItem(
                                  '퇴근 시간',
                                  provider.clockOutStr,
                                ),
                              _buildSummaryItem(
                                '근무 시간',
                                provider.todayWorkDuration,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 25)),
                        // 지각 통계 카드
                        Container(
                          padding: EdgeInsets.all(
                            ResponsiveUtils.spacing(context, 20),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFF8F9FB),
                                Colors.white,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 20),
                            ),
                            boxShadow: [AppShadows.card],
                            border: Border.all(
                              color: const Color(0xFFE9ECEF),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildLateStatItem(
                                  '이번 달 지각',
                                  '${provider.monthlyLateCount}회',
                                  const Color(0xFFFF6B6B),
                                  Icons.calendar_month,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: ResponsiveUtils.spacing(context, 50),
                                color: const Color(0xFFE9ECEF),
                              ),
                              Expanded(
                                child: _buildLateStatItem(
                                  '올해 지각',
                                  '${provider.yearlyLateCount}회',
                                  const Color(0xFF1777CB),
                                  Icons.calendar_today,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 25)),
                        // 최근 기록 카드
                        Container(
                          padding: EdgeInsets.all(
                            ResponsiveUtils.spacing(context, 25),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 20),
                            ),
                            boxShadow: [AppShadows.card],
                            border: Border.all(color: const Color(0xFFE9ECEF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      ResponsiveUtils.spacing(context, 2),
                                    ),
                                    child: Text(
                                      '⏱️',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: ResponsiveUtils.spacing(context, 10),
                                  ),
                                  Text(
                                    '최근 기록',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 22,
                                      color: const Color(0xFF343A40),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: ResponsiveUtils.spacing(context, 15),
                              ),
                              provider.recentHistory.isEmpty
                                  ? Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: ResponsiveUtils.spacing(
                                          context,
                                          20,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '아직 기록이 없습니다',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          color: const Color(0xFF6C757D),
                                          fontSize: 16,
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: provider.recentHistory
                                          .map(
                                            (record) => Padding(
                                              padding: EdgeInsets.only(
                                                bottom: ResponsiveUtils.spacing(
                                                  context,
                                                  8,
                                                ),
                                              ),
                                              child: _buildHistoryRow(record),
                                            ),
                                          )
                                          .toList(),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 17,
                color: const Color(0xFF6C757D),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF343A40),
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
          Container(height: 1, color: const Color(0xFFF1F3F4)),
          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
        ],
      ],
    );
  }

  Widget _buildHistoryRow(AttendanceRecord record) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 12),
        vertical: ResponsiveUtils.spacing(context, 10),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: const Color(0xFF444444),
            ),
          ),
          Text(
            '출근: ${record.clockIn == null ? '-' : _AttendanceScreenBodyState._formatTime(record.clockIn!)}',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: const Color(0xFF444444),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Widget _buildLateStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: ResponsiveUtils.spacing(context, 28),
          color: color.withValues(alpha: 0.8),
        ),
        SizedBox(height: ResponsiveUtils.spacing(context, 8)),
        Text(
          label,
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 14,
            color: const Color(0xFF6C757D),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: ResponsiveUtils.spacing(context, 4)),
        Text(
          value,
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
