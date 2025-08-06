import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/user_provider.dart';
import 'dart:async';
import '../../models/attendance.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../auth/login_screen.dart';
import '../../services/timer_manager.dart';
import '../../services/ui_optimization_service.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final userId = userProvider.id;
        final userName = userProvider.name;
        if (userId == null || userId.isEmpty) {
          // 로그인 정보가 없으면 바로 로그인 화면 반환
          return const LoginScreen();
        }
        return ChangeNotifierProvider(
          create: (_) => AttendanceProvider(
            userId: userId,
            userName: userName ?? '',
          ),
          child: _AttendanceScreenBody(),
        );
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
  
  // UI update frequency optimization
  static const Duration _uiUpdateInterval = Duration(seconds: 5); // Reduced from 1 second
  bool _shouldUpdateUI = true;

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
            final provider = Provider.of<AttendanceProvider>(context, listen: false);
            _shouldUpdateUI = provider.status == AttendanceStatus.working || 
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
        
        final provider = Provider.of<AttendanceProvider>(context, listen: false);
        
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
      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 12)),
      child: Center(
        child: Text(
          _bannerMessage!,
          style: ResponsiveUtils.getTextStyle(context, color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
    return OptimizedConsumer<AttendanceProvider>(
      componentKey: 'attendance_main',
      throttleDuration: const Duration(milliseconds: 100), // Smooth but not excessive
      shouldRebuild: (provider) => !provider.isLoading, // Only rebuild when not loading
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
                          title: Text(
                '근무 기록',
                style: AppTextStyles.appBarTitle(context),
              ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: ResponsiveUtils.spacing(context, 20)),
                child: OptimizedConsumer<UserProvider>(
                  componentKey: 'user_name_header',
                  throttleDuration: const Duration(seconds: 1), // Name rarely changes
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
          body: Column(
            children: [
              _buildBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.spacing(context, 20), 
                    vertical: ResponsiveUtils.spacing(context, 20)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 현재 상태 카드
                      Container(
                        padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 30)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 20)),
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
                            SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.spacing(context, 24), 
                                vertical: ResponsiveUtils.spacing(context, 12)
                              ),
                              decoration: BoxDecoration(
                                gradient: _getStatusGradient(provider.statusText),
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 25)),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getStatusShadowColor(provider.statusText),
                                    blurRadius: ResponsiveUtils.spacing(context, 15),
                                    offset: Offset(0, ResponsiveUtils.spacing(context, 4)),
                                  ),
                                ],
                              ),
                              child: Text(
                                provider.statusText,
                                style:                                 ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveUtils.spacing(context, 15)),
                            Text(
                              provider.clockInTime == null
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
                                onTap: provider.status == AttendanceStatus.beforeWork
                                    ? () async {
                                        await provider.tryClockIn();
                                        if (provider.errorMessage != null) {
                                          _showBanner(provider.errorMessage!, error: true);
                                          provider.clearError();
                                        }
                                      }
                                    : null,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: provider.status == AttendanceStatus.beforeWork ? AppColors.primaryGradient : null,
                                    color: provider.status == AttendanceStatus.beforeWork ? null : const Color(0xFFE9ECEF),
                                                                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 14)),
                                    boxShadow: [
                                      if (provider.status == AttendanceStatus.beforeWork)
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.32),
                                          blurRadius: ResponsiveUtils.spacing(context, 7),
                                          offset: Offset(0, ResponsiveUtils.spacing(context, 2)),
                                        ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '출근하기',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 21,
                                      color: provider.status == AttendanceStatus.beforeWork ? Colors.white : const Color(0xFFB0B0B0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 15)),
                          Expanded(
                            child: SizedBox(
                              height: ResponsiveUtils.spacing(context, 65),
                              child: GestureDetector(
                                onTap: provider.canClockOut
                                    ? () async {
                                        await provider.tryClockOut();
                                      }
                                    : null,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: provider.canClockOut ? AppColors.primaryGradient : null,
                                    color: provider.canClockOut ? null : const Color(0xFFE9ECEF),
                                                                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 14)),
                                    boxShadow: [
                                      if (provider.canClockOut)
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.32),
                                          blurRadius: ResponsiveUtils.spacing(context, 7),
                                          offset: Offset(0, ResponsiveUtils.spacing(context, 2)),
                                        ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '퇴근하기',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 21,
                                      color: provider.canClockOut ? Colors.white : const Color(0xFFB0B0B0),
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
                        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 25)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 20)),
                          boxShadow: [AppShadows.card],
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                                                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 2)),
                              child: Text(
                                '💼',
                                style: ResponsiveUtils.getTextStyle(context, fontSize: 20),
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 10)),
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
                            SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                            _buildSummaryItem('출근 시간', provider.clockInStr),
                            _buildSummaryItem('근무 시간', provider.todayWorkDuration, isLast: true),
                          ],
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 25)),
                      // 최근 기록 카드
                      Container(
                        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 25)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 20)),
                          boxShadow: [AppShadows.card],
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                                                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 2)),
                              child: Text(
                                '⏱️',
                                style: ResponsiveUtils.getTextStyle(context, fontSize: 20),
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 10)),
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
                            SizedBox(height: ResponsiveUtils.spacing(context, 15)),
                            provider.recentHistory.isEmpty
                                ? Container(
                                    padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 20)),
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
                                    children: provider.recentHistory.map((record) => Padding(
                                      padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 8)),
                                      child: _buildHistoryRow(record),
                                    )).toList(),
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
          Container(
            height: 1,
            color: const Color(0xFFF1F3F4),
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
        ],
      ],
    );
  }

  Widget _buildHistoryRow(AttendanceRecord record) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 12), 
        vertical: ResponsiveUtils.spacing(context, 10)
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
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
}