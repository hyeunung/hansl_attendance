import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../widgets/optimized_widgets.dart';
import '../../widgets/shared/flat_section.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();

    // 오늘 날짜를 기본 선택으로 설정 (시간 제거)
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);

    // 첫 빌드 후에 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final provider = Provider.of<LeaveProvider>(context, listen: false);
        // 달력용: 승인된 연차/출장만 로드
        await provider.fetchApprovedLeavesForCalendar(forceRefresh: true);
        // 공휴일 데이터 로드
        await provider.fetchHolidays(forceRefresh: true);
      }
    });
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0);
    return List.generate(
      last.day,
      (i) => DateTime(month.year, month.month, i + 1),
    );
  }

  List<Map<String, dynamic>> _getEventsForDay(
    DateTime day,
    List<Map<String, dynamic>> allLeaves,
  ) {
    return allLeaves.where((l) {
      final start = DateTime.parse(l['start_date']);
      final end = DateTime.parse(l['end_date']);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList();
  }

  String _normalizeLeaveType(dynamic rawType) {
    return rawType == null
        ? ''
        : rawType
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll('_', '');
  }

  bool _hasAnnual(List<Map<String, dynamic>> events) {
    return events.any((e) {
      final type = _normalizeLeaveType(e['type']);
      return const [
        'annual',
        'halfam',
        'halfpm',
        'official',
      ].contains(type);
    });
  }

  bool _hasBiztrip(List<Map<String, dynamic>> events) {
    return events.any((e) {
      final type = _normalizeLeaveType(e['type']);
      return type == 'biztrip' || type == 'businesstrip';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    return OptimizedConsumer<LeaveProvider>(
      componentKey: 'calendar_main',
      throttleDuration: const Duration(milliseconds: 200),
      shouldRebuild: (provider) => true, // 항상 리빌드하도록 변경
      builder: (context, provider, _) {
        // 달력에서는 승인된 것만 전용으로 가져온 데이터 사용
        final allLeaves = provider.approvedLeavesForCalendar; // 승인된 것만
        final hasData = allLeaves.isNotEmpty;

        final days = _daysInMonth(_focusedMonth);
        final firstWeekday = days.first.weekday % 7; // 일요일=0
        final totalCells = days.length + firstWeekday;
        final rows = (totalCells / 7).ceil();
        final isLoading = provider.calendarLoading;
        final showLoading = isLoading && !hasData;
        return Scaffold(
          appBar: AppBar(
            title: AppBarTitle('달력'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.backgroundPrimary,
          body: showLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    // 달력 데이터 새로고침
                    await provider.fetchApprovedLeavesForCalendar(
                      forceRefresh: true,
                    );
                    if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
                  },
                  child: ListView(
                    children: [
                      // 달력 (flat - no card wrapper)
                      Container(
                        color: Colors.white,
                        padding: EdgeInsets.all(
                          ResponsiveUtils.spacing(context, 16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.chevron_left,
                                    size: ResponsiveUtils.iconSize(context, 28),
                                    color: AppColors.textPrimary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _focusedMonth = DateTime(
                                        _focusedMonth.year,
                                        _focusedMonth.month - 1,
                                      );
                                    });
                                  },
                                ),
                                SizedBox(
                                  width: ResponsiveUtils.spacing(context, 4),
                                ),
                                Text(
                                  '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                                  style: AppTextStyles.sectionSubtitle(context).copyWith(
                                    fontSize: ResponsiveUtils.fontSize(context, 22),
                                  ),
                                ),
                                SizedBox(
                                  width: ResponsiveUtils.spacing(context, 4),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.chevron_right,
                                    size: ResponsiveUtils.iconSize(context, 28),
                                    color: AppColors.textPrimary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _focusedMonth = DateTime(
                                        _focusedMonth.year,
                                        _focusedMonth.month + 1,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                            SizedBox(
                              height: ResponsiveUtils.spacing(context, 8),
                            ),
                            Row(
                              children: ['일', '월', '화', '수', '목', '금', '토']
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final idx = entry.key;
                                final label = entry.value;
                                final color = idx == 0
                                    ? AppColors.error
                                    : idx == 6
                                        ? AppColors.info
                                        : AppColors.textPrimary;
                                return Expanded(
                                  child: Center(
                                    child: Text(
                                      label,
                                      style: AppTextStyles.tableHeader(context).copyWith(
                                        fontSize: ResponsiveUtils.fontSize(context, 14),
                                        color: color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            SizedBox(
                              height: ResponsiveUtils.spacing(context, 4),
                            ),
                            Column(
                              children: List.generate(rows, (rowIdx) {
                                return Row(
                                  children: List.generate(7, (colIdx) {
                                    final cellIdx = rowIdx * 7 + colIdx;
                                    if (cellIdx < firstWeekday ||
                                        cellIdx - firstWeekday >= days.length) {
                                      return Expanded(
                                        child: Container(
                                          height: ResponsiveUtils.spacing(
                                            context,
                                            54,
                                          ),
                                        ),
                                      );
                                    }
                                    final day = days[cellIdx - firstWeekday];
                                    final events = _getEventsForDay(
                                      day,
                                      allLeaves,
                                    );
                                    final isSelected =
                                        _selectedDay != null &&
                                        day.year == _selectedDay!.year &&
                                        day.month == _selectedDay!.month &&
                                        day.day == _selectedDay!.day;

                                    // 공휴일 체크
                                    final isHoliday = provider.isHoliday(day);
                                    final holidayInfo = isHoliday
                                        ? provider.getHolidayInfo(day)
                                        : null;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedDay = day;
                                          });
                                        },
                                        child: Container(
                                          margin: EdgeInsets.all(
                                            ResponsiveUtils.spacing(context, 2),
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primaryLight.withValues(alpha: 0.1)
                                                : null,
                                            border: isSelected
                                                ? Border.all(
                                                    color: AppColors.primaryLight,
                                                    width: 1.5,
                                                  )
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              ResponsiveUtils.spacing(
                                                context,
                                                8,
                                              ),
                                            ),
                                          ),
                                          height: ResponsiveUtils.spacing(
                                            context,
                                            54,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              // 막대기(연차/출장) - 숫자 위에
                                              if (_hasAnnual(events))
                                                Container(
                                                  width:
                                                      ResponsiveUtils.spacing(
                                                        context,
                                                        18,
                                                      ),
                                                  height:
                                                      ResponsiveUtils.spacing(
                                                        context,
                                                        4,
                                                      ),
                                                  margin: EdgeInsets.only(
                                                    bottom:
                                                        ResponsiveUtils.spacing(
                                                          context,
                                                          2,
                                                        ),
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success.withValues(alpha: 0.8),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          ResponsiveUtils.spacing(
                                                            context,
                                                            2,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              if (_hasBiztrip(events))
                                                Container(
                                                  width:
                                                      ResponsiveUtils.spacing(
                                                        context,
                                                        18,
                                                      ),
                                                  height:
                                                      ResponsiveUtils.spacing(
                                                        context,
                                                        4,
                                                      ),
                                                  margin: EdgeInsets.only(
                                                    bottom:
                                                        ResponsiveUtils.spacing(
                                                          context,
                                                          2,
                                                        ),
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.biztrip.withValues(alpha: 0.8),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          ResponsiveUtils.spacing(
                                                            context,
                                                            2,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              // 날짜 숫자 (공휴일은 빨간색)
                                              Column(
                                                children: [
                                                  Text(
                                                    '${day.day}',
                                                    style: AppTextStyles.tableCell(
                                                      context,
                                                      color:
                                                          isHoliday ||
                                                              day.weekday ==
                                                                  7
                                                          ? AppColors.sunday // 공휴일/일요일: 빨간색
                                                          : day.weekday == 6
                                                          ? AppColors.saturday // 토요일: 파란색
                                                          : AppColors.weekday, // 평일: 검정색
                                                    ).copyWith(
                                                      fontSize: ResponsiveUtils.fontSize(context, 14),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  // 공휴일 이름 표시 (작은 글씨)
                                                  if (isHoliday &&
                                                      holidayInfo != null)
                                                    Text(
                                                      holidayInfo['name']
                                                                  .length >
                                                              4
                                                          ? holidayInfo['name']
                                                                .substring(0, 4)
                                                          : holidayInfo['name'],
                                                      style: AppTextStyles.listSubtitle(context).copyWith(
                                                        fontSize: ResponsiveUtils.fontSize(context, 8),
                                                        color: AppColors.sunday,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              }),
                            ),
                            SizedBox(
                              height: ResponsiveUtils.spacing(context, 8),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _legendDot(AppColors.success, '연차'),
                                SizedBox(
                                  width: ResponsiveUtils.spacing(context, 20),
                                ),
                                _legendDot(AppColors.biztrip, '출장'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 상세내역 - flat section header + content
                      FlatSectionHeader(
                        title: _selectedDay != null
                            ? '${_selectedDay!.year}년 ${_selectedDay!.month}월 ${_selectedDay!.day}일'
                            : '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일',
                        trailing: (_selectedDay != null &&
                                provider.isHoliday(_selectedDay!))
                            ? provider.getHolidayInfo(_selectedDay!)!['name']
                            : null,
                      ),
                      Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            ..._getEventsForDay(
                              _selectedDay ?? DateTime.now(),
                              allLeaves,
                            ).map((e) => _eventTile(e)),
                            if (_getEventsForDay(
                              _selectedDay ?? DateTime.now(),
                              allLeaves,
                            ).isEmpty)
                              FlatEmptyState(
                                message: (_selectedDay != null &&
                                        provider.isHoliday(_selectedDay!))
                                    ? '공휴일입니다.'
                                    : '해당 날짜에 등록된 연차/출장이 없습니다.',
                                icon: Icons.event_busy,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ResponsiveUtils.spacing(context, 12),
          height: ResponsiveUtils.spacing(context, 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.spacing(context, 1.5),
            ),
          ),
        ),
        SizedBox(width: ResponsiveUtils.spacing(context, 6)),
        Text(
          label,
          style: AppTextStyles.listSubtitle(context),
        ),
      ],
    );
  }

  Widget _eventTile(Map<String, dynamic> e) {
    final rawType = e['type']?.toString() ?? '';
    final normalizedType = _normalizeLeaveType(rawType);
    final isBiztrip =
        normalizedType == 'biztrip' || normalizedType == 'businesstrip';
    String chipLabel;
    Color chipTextColor = AppColors.textPrimary;
    // 상태별 색상/라벨
    switch (e['status']) {
      case 'approved':
        chipTextColor = AppColors.success;
        break;
      case 'pending':
        chipTextColor = AppColors.textTertiary;
        break;
      case 'rejected':
        chipTextColor = AppColors.error;
        break;
      default:
        chipTextColor = AppColors.success;
    }
    // 타입별 라벨
    switch (normalizedType) {
      case 'annual':
        chipLabel = '연차';
        break;
      case 'halfam':
        chipLabel = '오전반차';
        break;
      case 'halfpm':
        chipLabel = '오후반차';
        break;
      case 'official':
        chipLabel = '공가';
        break;
      case 'biztrip':
      case 'businesstrip':
        chipLabel = '출장';
        // 출장은 파란색으로 변경
        if (e['status'] == 'approved') {
          chipTextColor = AppColors.biztrip;
        }
        break;
      default:
        chipLabel = rawType.isNotEmpty ? rawType : '기타';
    }
    // 상태 라벨 추가
    if (e['status'] == 'pending') chipLabel += ' (대기)';
    if (e['status'] == 'rejected') chipLabel += ' (반려)';

    // reason 필터링: CSV 데이터 이관 메시지는 표시하지 않음
    String? displayReason;
    if (e['reason'] != null &&
        !e['reason'].contains('CSV 데이터 이관') &&
        !e['reason'].contains('상반기 연차 사용')) {
      displayReason = e['reason'];
    }

    // 출장인 경우 출장자 배열 사용 (전원 이름 표시)
    String displayName = e['name'] ?? e['user_email'] ?? '-';
    if (isBiztrip && e['출장자'] != null) {
      final travelersRaw = e['출장자'] as List<dynamic>?;
      if (travelersRaw != null && travelersRaw.isNotEmpty) {
        // 출장자 전원 이름을 콤마로 구분하여 표시
        final allTravelers = travelersRaw.map((t) => t.toString()).toList();
        displayName = allTravelers.join(', ');
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 12),
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: AppTextStyles.listTitle(context),
                ),
              ),
              StatusChip(label: chipLabel, color: chipTextColor),
            ],
          ),
          if (e['start_date'] != null && e['end_date'] != null) ...[
            () {
              final startDate = DateTime.parse(e['start_date']);
              final endDate = DateTime.parse(e['end_date']);
              final days = endDate.difference(startDate).inDays + 1;
              if (days > 1) {
                return Padding(
                  padding: EdgeInsets.only(
                    top: ResponsiveUtils.spacing(context, 4),
                  ),
                  child: Text(
                    '기간 : ${startDate.month}/${startDate.day} ~ ${endDate.month}/${endDate.day} ($days일간)',
                    style: AppTextStyles.listSubtitle(context),
                  ),
                );
              }
              return const SizedBox.shrink();
            }(),
          ],
          if (e['desc'] != null) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 4)),
            Text(
              e['desc'],
              style: AppTextStyles.tableCellSub(context),
            ),
          ],
          // 출장인 경우: 장소, 업무, 차량 정보를 각 행에 표시
          if (isBiztrip) ...[
            if (e['place'] != null && e['place'].toString().isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.spacing(context, 2)),
              Text(
                '장소 : ${e['place']}',
                style: AppTextStyles.listSubtitle(context),
              ),
            ],
            if (displayReason != null && displayReason.isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.spacing(context, 2)),
              Text(
                '업무 : $displayReason',
                style: AppTextStyles.listSubtitle(context),
              ),
            ],
            if (e['transport'] != null && e['transport'].toString().isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.spacing(context, 2)),
              Text(
                '차량 : ${e['transport']}',
                style: AppTextStyles.listSubtitle(context),
              ),
            ],
          ],
          // 연차/반차인 경우: reason만 표시
          if (displayReason != null && !isBiztrip) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 2)),
            Text(
              displayReason,
              style: AppTextStyles.listSubtitle(context),
            ),
          ],
        ],
      ),
    );
  }
}
