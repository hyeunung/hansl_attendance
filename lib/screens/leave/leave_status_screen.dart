import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import 'leave_screen_router.dart';
import 'card_receipt_upload_screen.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../services/ui_optimization_service.dart';
import '../../widgets/shared/flat_section.dart';
import '../../widgets/common/notification_banner_widget.dart';

class LeaveStatusScreen extends StatefulWidget {
  const LeaveStatusScreen({super.key});

  @override
  State<LeaveStatusScreen> createState() => _LeaveStatusScreenState();
}

class _LeaveStatusScreenState extends State<LeaveStatusScreen>
    with UIOptimizationMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (!_isFirstLoad) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final provider = Provider.of<LeaveProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (provider.myLeaves.isNotEmpty && provider.annualLeaveLoaded) {
        if (!mounted) return;
        setState(() {
          _isFirstLoad = false;
        });
        return;
      }

      if (userProvider.email != null && userProvider.email!.isNotEmpty) {
        await provider.fetchMyLeaves(email: userProvider.email!, forceRefresh: true);
      }
      provider.fetchTodayLeaves(DateTime.now());
      provider.fetchAllLeaves(forceRefresh: false);

      if (!mounted) return;
      setState(() {
        _isFirstLoad = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: AppBarTitle('연차/출장 대시보드'),
      ),
      body: Consumer<LeaveProvider>(
        builder: (context, provider, _) {
          if (provider.error != null && !provider.isLoading && provider.myLeaves.isEmpty) {
            return Center(child: Text('에러: ${provider.error}'));
          }

          final hasAnyData = provider.myLeaves.isNotEmpty ||
              provider.todayLeaves.isNotEmpty ||
              provider.allLeaves.isNotEmpty;
          final showLoading = provider.isLoading && !hasAnyData;

          if (showLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              if (userProvider.email != null &&
                  userProvider.email!.isNotEmpty) {
                await provider.fetchMyLeaves(
                  email: userProvider.email!,
                  forceRefresh: true,
                );
              }
              await provider.fetchTodayLeaves(DateTime.now());
              await provider.fetchAllLeaves(forceRefresh: true);
              if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 연차 신청 / 영수증 업로드 버튼 (출퇴근 버튼과 동일 디자인)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 16),
                        vertical: ResponsiveUtils.spacing(context, 14),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: Material(
                                  color: AppColors.primary,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(9),
                                    bottomLeft: Radius.circular(9),
                                  ),
                                  child: InkWell(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(9),
                                      bottomLeft: Radius.circular(9),
                                    ),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const LeaveScreenRouter()),
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: ResponsiveUtils.spacing(context, 20),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '연차 신청',
                                        style: AppTextStyles.buttonPrimary(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(width: 0.5, color: AppColors.border),
                              Expanded(
                                child: Material(
                                  color: AppColors.primary,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(9),
                                    bottomRight: Radius.circular(9),
                                  ),
                                  child: InkWell(
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(9),
                                      bottomRight: Radius.circular(9),
                                    ),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CardReceiptUploadScreen()),
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: ResponsiveUtils.spacing(context, 20),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '영수증 업로드',
                                        style: AppTextStyles.buttonPrimary(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. 내 연차 현황
                    FlatSectionHeader(
                      title: '내 연차 현황',
                      icon: Icons.calendar_today_rounded,
                      iconColor: AppColors.info,
                    ),
                    FlatStatGrid(
                      items: [
                        FlatStatItem(
                          label: '잔여연차',
                          value: provider.remainAnnual > 0
                              ? provider.remainAnnual.toString()
                              : '없음',
                          color: provider.remainAnnual > 0
                              ? AppColors.info
                              : AppColors.textTertiary,
                        ),
                        FlatStatItem(
                          label: '내 대기중',
                          value: provider.myPendingCount.toString(),
                          color: AppColors.success,
                        ),
                        FlatStatItem(
                          label: '출장일수',
                          value: provider.biztripDays.toString(),
                          color: AppColors.biztrip,
                        ),
                      ],
                    ),

                    // 3. 최근 신청
                    FlatSectionHeader(title: '최근 신청'),
                    if (provider.recentLeaves.isEmpty)
                      FlatEmptyState(
                        message: '최근 신청 내역이 없습니다.',
                        icon: Icons.event_busy,
                      ),
                    ..._recentLeaveRows(provider.recentLeaves),

                    // bottom spacing
                    SizedBox(height: ResponsiveUtils.spacing(context, 40)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _recentLeaveTile(Map<String, dynamic> l) {
    String status = l['status'] ?? '';
    DateTime start = DateTime.parse(l['start_date']);
    DateTime end = DateTime.parse(l['end_date']);
    int days = end.difference(start).inDays + 1;
    double displayDays = 1.0 * days;
    if (l['type'] == 'halfAm' ||
        l['type'] == 'half_am' ||
        l['type'] == 'halfPm' ||
        l['type'] == 'half_pm') {
      displayDays = 0.5;
    }

    final int groupedCount = l['grouped_count'] ?? 1;
    String period = '';
    if (groupedCount > 1) {
      if (start.month == end.month) {
        period =
            '${start.month}월 ${start.day}일 - ${end.day}일 (연속 $groupedCount건, ${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
      } else {
        period =
            '${start.month}월 ${start.day}일 - ${end.month}월 ${end.day}일 (연속 $groupedCount건, ${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
      }
    } else {
      if (start.month == end.month) {
        period =
            '${start.month}월 ${start.day}일 - ${end.day}일 (${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
      } else {
        period =
            '${start.month}월 ${start.day}일 - ${end.month}월 ${end.day}일 (${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
      }
    }

    final String mainName = l['name'] ?? l['user_email'] ?? '-';
    List<String> companionNames = [];
    if (l['type'] == 'biztrip' && l['출장자'] != null) {
      final travelers = (l['출장자'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];

      final seen = <String>{};
      final uniqueTravelers = <String>[];
      for (final t in travelers) {
        if (seen.add(t)) uniqueTravelers.add(t);
      }

      companionNames = uniqueTravelers.where((t) => t != mainName).toList();
    }

    String statusLabel = status == 'approved'
        ? '승인됨'
        : status == 'pending'
        ? '대기중'
        : '반려';
    Color statusColor = status == 'approved'
        ? AppColors.success
        : status == 'pending'
        ? AppColors.warning
        : AppColors.late_;

    return FlatTableRow(
      cells: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  l['type'] == 'biztrip'
                      ? Icons.flight_takeoff
                      : Icons.calendar_today,
                  size: 16,
                  color: l['type'] == 'biztrip'
                      ? AppColors.biztrip
                      : AppColors.success,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l['name'] ?? l['user_email'] ?? '-',
                    style: AppTextStyles.tableCell(context),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                _leaveTypeChip(l['type']),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(period, style: AppTextStyles.tableCellSub(context)),
                if (companionNames.isNotEmpty)
                  Text(
                    '(동행: ${companionNames.join(', ')})',
                    style: AppTextStyles.tableCellSub(context),
                  ),
              ],
            ),
          ],
        ),
      ],
      flexValues: [1],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'pending' && l['type'] != 'biztrip' && l['is_business_trip'] != true)
            IconButton(
              onPressed: () => _deleteLeaveRequest(l),
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.error,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '삭제',
            ),
          const SizedBox(width: 6),
          StatusChip(label: statusLabel, color: statusColor, fontSize: 12),
        ],
      ),
      trailingWidth: 110,
    );
  }

  List<Widget> _recentLeaveRows(List<Map<String, dynamic>> leaves) {
    return leaves.map((l) => _recentLeaveTile(l)).toList();
  }

  Widget _leaveTypeChip(String type) {
    String label;
    Color chipColor;
    final normalizedType = type.toLowerCase().replaceAll('_', '');
    switch (normalizedType) {
      case 'annual':
        label = '연차';
        chipColor = AppColors.success;
        break;
      case 'halfam':
        label = '오전반차';
        chipColor = AppColors.success;
        break;
      case 'halfpm':
        label = '오후반차';
        chipColor = AppColors.success;
        break;
      case 'official':
        label = '공가';
        chipColor = AppColors.gray600;
        break;
      case 'biztrip':
        label = '출장';
        chipColor = AppColors.biztrip;
        break;
      default:
        if (type == 'annual_leave' || type == 'annual leave') {
          label = '연차';
          chipColor = AppColors.success;
        } else if (type == 'business_trip' || type == 'business trip') {
          label = '출장';
          chipColor = AppColors.biztrip;
        } else {
          label = '기타';
          chipColor = AppColors.biztrip;
        }
    }
    return StatusChip(label: label, color: chipColor, fontSize: 11);
  }

  Future<void> _deleteLeaveRequest(Map<String, dynamic> leave) async {
    if (leave['type'] == 'biztrip' || leave['is_business_trip'] == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('취소 불가'),
          content: const Text('출장 건은 웹에서만 취소할 수 있습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신청 취소'),
        content: const Text(
          '연차 신청을 취소하시겠습니까?\n취소 후에는 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('예, 취소합니다'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      if (!context.mounted) return;
      final provider = Provider.of<LeaveProvider>(context, listen: false);
      if (!context.mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      await provider.deleteLeaveRequest(
        leaveId: leave['id'],
        userEmail: userProvider.email!,
        userName: userProvider.name ?? '',
        leaveType: leave['type'],
        startDate: leave['start_date'],
        endDate: leave['end_date'],
      );

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        AppBanner.show(context, '신청이 취소되었습니다.', type: BannerType.success);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        AppBanner.show(context, '취소 중 오류가 발생했습니다: $e', type: BannerType.error);
      }
    }
  }
}
