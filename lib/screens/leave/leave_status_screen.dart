import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import 'leave_screen_router.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../services/ui_optimization_service.dart';

class LeaveStatusScreen extends StatefulWidget {
  const LeaveStatusScreen({super.key});

  @override
  State<LeaveStatusScreen> createState() => _LeaveStatusScreenState();
}

class _LeaveStatusScreenState extends State<LeaveStatusScreen>
    with UIOptimizationMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final double rValue = 14;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (!_isFirstLoad) return; // 이미 로드했으면 다시 로드하지 않음

    // build 완료 후에 비동기적으로 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final provider = Provider.of<LeaveProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 이미 데이터가 있으면 다시 로드하지 않음 (연차가 0일 수도 있으므로 > 0 체크 제거)
      if (provider.myLeaves.isNotEmpty && provider.annualLeaveLoaded) {
        if (!mounted) return;
        setState(() {
          _isFirstLoad = false;
        });
        return;
      }

      if (userProvider.email != null && userProvider.email!.isNotEmpty) {
        // 연차 데이터와 함께 가져오기 (캐시 문제 해결을 위해 forceRefresh: true)
        await provider.fetchMyLeaves(email: userProvider.email!, forceRefresh: true);
      }
      provider.fetchTodayLeaves(DateTime.now());
      // 관리자의 경우 전체 leave 데이터도 가져옴 (승인 대기 카운트를 위해)
      provider.fetchAllLeaves(forceRefresh: false);

      if (!mounted) return;
      setState(() {
        _isFirstLoad = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    // final userEmail = Provider.of<UserProvider>(context, listen: false).email;
    // Debug print removed
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        centerTitle: true,
        title: Text('연차/출장 대시보드', style: AppTextStyles.appBarTitle(context)),
      ),
      body: OptimizedConsumer<LeaveProvider>(
        componentKey: 'leave_status_main',
        throttleDuration: const Duration(
          milliseconds: 200,
        ), // Moderate throttling for leave data
        shouldRebuild: (provider) =>
            !provider.isLoading && provider.error == null,
        builder: (context, provider, _) {
          // 사용자 권한 확인
          // final userProvider = Provider.of<UserProvider>(
          //   context,
          //   listen: false,
          // );
          // final employee = userProvider.employee;  // 미사용
          // final attendanceRole = employee?['attendance_role'];  // 미사용
          // final name = employee?['name'] ?? '';  // 미사용

          // 승인 권한이 있는 경우 (Admin 또는 Manager)
          // final bool hasApprovalAuth = isAdmin || isManager; // 미사용 변수 주석 처리

          // 에러 처리
          if (provider.error != null) {
            return Center(child: Text('에러: ${provider.error}'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              // 백엔드에서 최신 데이터 가져오기
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
            },
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 20),
                vertical: ResponsiveUtils.spacing(context, 20),
              ),
              children: [
                // 1. 내 연차 현황 - 애플 스타일
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 28)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, 20),
                    ),
                    boxShadow: [AppShadows.card],
                    border: Border.all(color: const Color(0xFFE9ECEF)),
                  ),
                  child: Column(
                    children: [
                      // 제목 - 아이콘과 함께
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              ResponsiveUtils.spacing(context, 6),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF007AFF,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 8),
                              ),
                            ),
                            child: Icon(
                              Icons.calendar_today_rounded,
                              color: const Color(0xFF007AFF),
                              size: ResponsiveUtils.iconSize(context, 16),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                          Text(
                            '내 연차 현황',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: const Color(0xFF1D1D1F),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 24)),

                      // 메인 잔여 연차
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.spacing(context, 20),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 12),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              provider.remainAnnual > 0 ? provider.remainAnnual.toString() : '없음',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontWeight: FontWeight.w700,
                                fontSize: 36,
                                color: provider.remainAnnual > 0 ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
                                height: 1.0,
                                letterSpacing: -1.0,
                              ),
                            ),
                            SizedBox(
                              height: ResponsiveUtils.spacing(context, 4),
                            ),
                            Text(
                              '잔여 연차',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: const Color(0xFF5A6C7D),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: ResponsiveUtils.spacing(context, 16)),

                      // 서브 정보들
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: ResponsiveUtils.spacing(context, 20),
                                horizontal: ResponsiveUtils.spacing(
                                  context,
                                  16,
                                ),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF34C759,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.spacing(context, 10),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    provider.myPendingCount.toString(),
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 22,
                                      color: const Color(0xFF34C759),
                                      height: 1.2,
                                    ),
                                  ),
                                  SizedBox(
                                    height: ResponsiveUtils.spacing(context, 4),
                                  ),
                                  Text(
                                    '내 대기중',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: const Color(
                                        0xFF34C759,
                                      ).withValues(alpha: 0.7),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(width: ResponsiveUtils.spacing(context, 12)),

                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: ResponsiveUtils.spacing(context, 20),
                                horizontal: ResponsiveUtils.spacing(
                                  context,
                                  16,
                                ),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1976D2,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.spacing(context, 10),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    provider.biztripDays.toString(),
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 22,
                                      color: const Color(0xFF1976D2),
                                      height: 1.2,
                                    ),
                                  ),
                                  SizedBox(
                                    height: ResponsiveUtils.spacing(context, 4),
                                  ),
                                  Text(
                                    '출장일수',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: const Color(
                                        0xFF1976D2,
                                      ).withValues(alpha: 0.7),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 25)),
                // 2. 연차/출장 신청 버튼 (흰색 박스 안에 좌우로)
                OptimizedConsumer<UserProvider>(
                  componentKey: 'leave_status_user',
                  throttleDuration: const Duration(milliseconds: 300),
                  builder: (context, userProvider, _) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: ResponsiveUtils.spacing(context, 0),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: ResponsiveUtils.spacing(context, 65),
                              child: _mainTabButton(
                                '연차 신청',
                                0,
                                ResponsiveUtils.spacing(context, rValue),
                              ),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 15)),
                          Expanded(
                            child: SizedBox(
                              height: ResponsiveUtils.spacing(context, 65),
                              child: _mainTabButton(
                                '출장 신청',
                                1,
                                ResponsiveUtils.spacing(context, rValue),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 25)),
                // 3. 최근 신청
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, rValue),
                    ),
                    boxShadow: [AppShadows.card],
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveUtils.spacing(context, 18),
                    horizontal: ResponsiveUtils.spacing(context, 18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '최근 신청',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontWeight: FontWeight.w800,
                          fontSize: 25,
                          color: const Color(0xFF222222),
                          letterSpacing: 0.1,
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 10)),
                      if (provider.recentLeaves.isEmpty)
                        Text(
                          '최근 신청 내역이 없습니다.',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: const Color(0xFFAAAAAA),
                            letterSpacing: 0.1,
                            height: 1.2,
                          ),
                        ),
                      Divider(
                        height: ResponsiveUtils.spacing(context, 18),
                        thickness: 2,
                        color: const Color(0xFFE0E3E8),
                      ),
                      ..._recentLeaveWithAllDividers(provider.recentLeaves),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 22)),
                // 4. 오늘자 연차/출장 직원 현황 (흰색 박스 + 내용만 회색 박스)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, rValue),
                    ),
                    boxShadow: [AppShadows.card],
                  ),
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '연차/출장 현황',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontWeight: FontWeight.w700,
                              fontSize: 23,
                              color: const Color(0xFF222222),
                              letterSpacing: 0.1,
                              height: 1.25,
                            ),
                          ),
                          Text(
                            DateTime.now()
                                .toString()
                                .substring(0, 10)
                                .replaceAll('-', '.'),
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              color: const Color(0xFF888888),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F7),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, rValue),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 16),
                          vertical: ResponsiveUtils.spacing(context, 14),
                        ),
                        child: provider.todayLeaves.isEmpty
                            ? Text(
                                '오늘자 연차/출장 직원이 없습니다.',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 17,
                                  color: const Color(0xFFAAAAAA),
                                  letterSpacing: 0.1,
                                  height: 1.2,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...provider.todayLeaves.map(
                                    (l) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            l['type'] == 'biztrip'
                                                ? Icons.flight_takeoff
                                                : Icons.calendar_today,
                                            size: 20,
                                            color: l['type'] == 'biztrip'
                                                ? const Color(0xFF1976D2)
                                                : const Color(0xFF34C759),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            l['name'] ?? l['user_email'] ?? '-',
                                            style: ResponsiveUtils.getTextStyle(
                                              context,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 19,
                                              color: const Color(0xFF222222),
                                              letterSpacing: 0.1,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _leaveTypeChip(l['type']),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
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

  Widget _mainTabButton(String label, int idx, double r) {
    final isAnnual = idx == 0;
    return SizedBox(
      height: ResponsiveUtils.spacing(context, 54),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(r),
          onTap: () {
            if (idx == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaveScreenRouter(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BusinessTripScreenRouter(),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: isAnnual ? AppColors.primaryGradient : null,
              color: isAnnual ? null : Colors.white,
              borderRadius: BorderRadius.circular(r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: ResponsiveUtils.spacing(context, 6),
                  offset: Offset(0, ResponsiveUtils.spacing(context, 2)),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontWeight: FontWeight.w700,
                fontSize: 21,
                letterSpacing: 0.1,
                height: 1.2,
                color: isAnnual ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recentLeaveTile(Map<String, dynamic> l) {
    // String typeLabel = l['type'] == 'biztrip' ? '출장 신청' : '연차 신청'; // 미사용
    // String typeDetail = ''; // 미사용
    // switch (l['type']) {
    //   case 'annual':
    //     typeDetail = '연차';
    //     break;
    //   case 'half_am':
    //     typeDetail = '오전반차';
    //     break;
    //   case 'half_pm':
    //     typeDetail = '오후반차';
    //     break;
    //   case 'official':
    //     typeDetail = '공가';
    //     break;
    //   default:
    //     typeDetail = '';
    // }
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

    // 그룹화된 항목 처리
    final int groupedCount = l['grouped_count'] ?? 1;
    String period = '';
    if (groupedCount > 1) {
      // 그룹화된 항목: "12월 20일 - 25일 (연속 3건, 6일)"
      if (start.month == end.month) {
        period =
            '${start.month}월 ${start.day}일 - ${end.day}일 (연속 $groupedCount건, ${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
      } else {
        period =
            '${start.month}월 ${start.day}일 - ${end.month}월 ${end.day}일 (연속 $groupedCount건, ${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
      }
    } else {
      // 단일 항목: 기존 형식
      if (start.month == end.month) {
        period =
            '${start.month}월 ${start.day}일 - ${end.day}일 (${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
      } else {
        period =
            '${start.month}월 ${start.day}일 - ${end.month}월 ${end.day}일 (${displayDays % 1 == 0 ? displayDays.toInt() : displayDays}일)';
      }
    }

    // 출장인 경우: DB의 "출장자"(본인+동행자) 배열을 기준으로 동행자 표시
    final String mainName = l['name'] ?? l['user_email'] ?? '-';
    List<String> companionNames = [];
    if (l['type'] == 'biztrip' && l['출장자'] != null) {
      final travelers = (l['출장자'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];

      // 중복 제거(순서 유지)
      final seen = <String>{};
      final uniqueTravelers = <String>[];
      for (final t in travelers) {
        if (seen.add(t)) uniqueTravelers.add(t);
      }

      // 본인을 제외한 나머지를 동행자로 간주
      companionNames = uniqueTravelers.where((t) => t != mainName).toList();
    }
    // String? reason = l['reason']; // 미사용
    String statusLabel = status == 'approved'
        ? '승인됨'
        : status == 'pending'
        ? '대기중'
        : '반려';
    Color statusColor = status == 'approved'
        ? const Color(0xFF34C759)
        : status == 'pending'
        ? const Color(0xFFFF9500)
        : const Color(0xFFE57373);
    // final String name = l['type'] == 'biztrip' ? (l['name'] ?? '-') : ''; // 미사용
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                l['type'] == 'biztrip'
                    ? Icons.flight_takeoff
                    : Icons.calendar_today,
                size: 20,
                color: l['type'] == 'biztrip'
                    ? const Color(0xFF1976D2)
                    : const Color(0xFF34C759),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        l['name'] ?? l['user_email'] ?? '-',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: const Color(0xFF222222),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _leaveTypeChip(l['type']),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (status == 'pending')
                IconButton(
                  onPressed: () => _deleteLeaveRequest(l),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Color(0xFFFF3B30),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '삭제',
                ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 10),
                  vertical: ResponsiveUtils.spacing(context, 4),
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 6),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(
              period,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 15,
                color: const Color(0xFF666666),
              ),
            ),
            if (companionNames.isNotEmpty)
              Text(
                '(동행: ${companionNames.join(', ')})',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 15,
                  color: const Color(0xFF666666),
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _recentLeaveWithAllDividers(List<Map<String, dynamic>> leaves) {
    final List<Widget> widgets = [];
    for (int i = 0; i < leaves.length; i++) {
      widgets.add(_recentLeaveTile(leaves[i]));
      widgets.add(
        const Divider(height: 18, thickness: 2, color: Color(0xFFE0E3E8)),
      );
    }
    return widgets;
  }

  Widget _leaveTypeChip(String type) {
    String label;
    Color bgColor;
    Color textColor;
    final normalizedType = type.toLowerCase().replaceAll('_', '');
    switch (normalizedType) {
      case 'annual':
        label = '연차';
        bgColor = const Color(0xFF34C759).withValues(alpha: 0.15);
        textColor = const Color(0xFF34C759);
        break;
      case 'halfam':
        label = '오전반차';
        bgColor = const Color(0xFF34C759).withValues(alpha: 0.15);
        textColor = const Color(0xFF34C759);
        break;
      case 'halfpm':
        label = '오후반차';
        bgColor = const Color(0xFF34C759).withValues(alpha: 0.15);
        textColor = const Color(0xFF34C759);
        break;
      case 'official':
        label = '공가';
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF757575);
        break;
      case 'biztrip':
        label = '출장';
        bgColor = const Color(0xFF1976D2).withValues(alpha: 0.15); // 파란색 배경
        textColor = const Color(0xFF1976D2); // 파란색 글자
        break;
      default:
        // 혹시 영어로 들어온 경우를 대비한 처리
        if (type == 'annual_leave' || type == 'annual leave') {
          label = '연차';
          bgColor = const Color(0xFF34C759).withValues(alpha: 0.15);
          textColor = const Color(0xFF34C759);
        } else if (type == 'business_trip' || type == 'business trip') {
          label = '출장';
          bgColor = const Color(0xFF1976D2).withValues(alpha: 0.15);
          textColor = const Color(0xFF1976D2);
        } else {
          // 알 수 없는 타입인 경우 한글로 기본값 표시
          label = '기타';
          bgColor = const Color(0xFFE3F2FD);
          textColor = const Color(0xFF1976D2);
        }
    }
    return Container(
      margin: EdgeInsets.only(left: ResponsiveUtils.spacing(context, 8)),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 10),
        vertical: ResponsiveUtils.spacing(context, 4),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 6),
        ),
      ),
      child: Text(
        label,
        style: ResponsiveUtils.getTextStyle(
          context,
          color: textColor.withValues(alpha: 0.8),
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Future<void> _deleteLeaveRequest(Map<String, dynamic> leave) async {
    // 삭제 확인 다이얼로그
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신청 취소'),
        content: Text(
          '${leave['type'] == 'biztrip' ? '출장' : '연차'} 신청을 취소하시겠습니까?\n취소 후에는 복구할 수 없습니다.',
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
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      if (!context.mounted) return;
      final provider = Provider.of<LeaveProvider>(context, listen: false);
      if (!context.mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 신청 삭제
      await provider.deleteLeaveRequest(
        leaveId: leave['id'],
        userEmail: userProvider.email!,
        userName: userProvider.name ?? '',
        leaveType: leave['type'],
        startDate: leave['start_date'],
        endDate: leave['end_date'],
      );

      // 로딩 닫기
      if (mounted) Navigator.of(context).pop();

      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신청이 취소되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 로딩 닫기
      if (mounted) Navigator.of(context).pop();

      // 에러 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('취소 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
