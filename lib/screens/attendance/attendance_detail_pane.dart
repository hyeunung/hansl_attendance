import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/attendance.dart';
import '../../providers/attendance_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/shared/flat_section.dart';

/// 펼친 폴더블에서 근무 탭 오른쪽에 표시되는 "내 근태" 패널.
/// 오늘 출퇴근 상태, 지각 통계, 최근 출퇴근 기록을 한눈에 보여준다.
class AttendanceDetailPane extends StatefulWidget {
  const AttendanceDetailPane({super.key});

  @override
  State<AttendanceDetailPane> createState() => _AttendanceDetailPaneState();
}

class _AttendanceDetailPaneState extends State<AttendanceDetailPane> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AttendanceProvider>();
      provider.fetchRecentHistory();
      provider.fetchLateStatistics();
    });
  }

  static String _time(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  static String _date(DateTime d) =>
      '${d.month}/${d.day} (${_weekdays[d.weekday - 1]})';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        shape: const Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
        title: AppBarTitle('내 근태'),
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, provider, _) {
          final history = provider.recentHistory;
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                provider.fetchRecentHistory(),
                provider.fetchLateStatistics(),
              ]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: ResponsiveUtils.spacing(context, 10),
                bottom: ResponsiveUtils.spacing(context, 20),
              ),
              children: [
                FlatCard(
                  child: Column(
                    children: [
                      FlatCardHeader(
                        title: '오늘',
                        icon: Icons.today,
                        iconColor: AppColors.primary,
                        trailing: StatusChip(
                          label: provider.statusText,
                          color: provider.statusColor,
                        ),
                      ),
                      FlatStatGrid(
                        items: [
                          FlatStatItem(
                            label: '출근',
                            value: _time(provider.clockInTime),
                          ),
                          FlatStatItem(
                            label: '퇴근',
                            value: _time(provider.clockOutTime),
                          ),
                          FlatStatItem(
                            label: '근무 시간',
                            value: provider.todayWorkDuration,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FlatCard(
                  child: Column(
                    children: [
                      const FlatCardHeader(
                        title: '지각 현황',
                        icon: Icons.warning_amber_rounded,
                        iconColor: AppColors.error,
                      ),
                      FlatStatGrid(
                        items: [
                          FlatStatItem(
                            label: '이번 달',
                            value: '${provider.monthlyLateCount}회',
                            color: provider.monthlyLateCount > 0
                                ? AppColors.error
                                : null,
                          ),
                          FlatStatItem(
                            label: '올해',
                            value: '${provider.yearlyLateCount}회',
                            color: provider.yearlyLateCount > 0
                                ? AppColors.error
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FlatCard(
                  child: Column(
                    children: [
                      FlatCardHeader(
                        title: '최근 출퇴근 기록',
                        icon: Icons.history,
                        iconColor: AppColors.primary,
                        trailing: Text(
                          '${history.length}건',
                          style: AppTextStyles.listSubtitle(context),
                        ),
                      ),
                      if (history.isEmpty)
                        const FlatEmptyState(
                          message: '최근 출퇴근 기록이 없습니다.',
                          icon: Icons.event_busy,
                        )
                      else
                        ...history.map((r) => _recordRow(context, r)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _recordRow(BuildContext context, AttendanceRecord r) {
    return FlatInfoRow(
      label: _date(r.date),
      value: '${_time(r.clockIn)} – ${_time(r.clockOut)}',
      trailing: r.isLate
          ? const StatusChip(label: '지각', color: AppColors.error, fontSize: 11)
          : null,
    );
  }
}
