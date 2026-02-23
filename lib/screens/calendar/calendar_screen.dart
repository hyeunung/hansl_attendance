import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/optimized_widgets.dart';

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

        // 디버그 로그
        // Debug code removed
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

        // 디버그 로그 추가
        // Debug code removed
        final days = _daysInMonth(_focusedMonth);
        final firstWeekday = days.first.weekday % 7; // 일요일=0
        final totalCells = days.length + firstWeekday;
        final rows = (totalCells / 7).ceil();
        // final today = DateTime.now(); // 미사용 변수 주석 처리
        final isLoading = provider.calendarLoading;
        final showLoading = isLoading && !hasData;
        if (kDebugMode) {
          debugPrint(
              '[CalendarScreen] build hasData=$hasData calendarLoading=$isLoading showLoading=$showLoading');
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('달력', style: AppTextStyles.appBarTitle(context)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFF8F9FA),
          body: showLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    // 달력 데이터 새로고침
                    await provider.fetchApprovedLeavesForCalendar(
                      forceRefresh: true,
                    );
                  },
                  child: ListView(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.spacing(context, 20),
                    ),
                    children: [
                      // 달력
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: ResponsiveUtils.spacing(context, 3),
                              offset: Offset(
                                0,
                                ResponsiveUtils.spacing(context, 1),
                              ),
                            ),
                          ],
                        ),
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
                                    color: const Color(0xFF1C1C1E),
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
                                  '📅  ${_focusedMonth.year}년 ${_focusedMonth.month}월',
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
                                    color: const Color(0xFF1C1C1E),
                                  ),
                                ),
                                SizedBox(
                                  width: ResponsiveUtils.spacing(context, 4),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.chevron_right,
                                    size: ResponsiveUtils.iconSize(context, 28),
                                    color: const Color(0xFF1C1C1E),
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
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '일',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        color: const Color(0xFFFF3B30),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '월',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        color: const Color(0xFF1C1C1E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '화',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        color: const Color(0xFF1C1C1E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '수',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        color: const Color(0xFF1C1C1E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '목',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        color: const Color(0xFF1C1C1E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '금',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        color: const Color(0xFF1C1C1E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '토',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        color: const Color(0xFF007AFF),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                                                ? const Color(
                                                    0xFF1E90FF,
                                                  ).withValues(alpha: 0.1)
                                                : null,
                                            border: isSelected
                                                ? Border.all(
                                                    color: const Color(
                                                      0xFF1E90FF,
                                                    ),
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
                                                    color: const Color(
                                                      0xFF34C759,
                                                    ).withValues(alpha: 0.8),
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
                                                    color: const Color(
                                                      0xFF1976D2,
                                                    ).withValues(alpha: 0.8),
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
                                                    style:
                                                        ResponsiveUtils.getTextStyle(
                                                          context,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              isHoliday ||
                                                                  day.weekday ==
                                                                      7
                                                              ? const Color(
                                                                  0xFFFF3B30,
                                                                ) // 공휴일/일요일: 빨간색
                                                              : day.weekday == 6
                                                              ? const Color(
                                                                  0xFF007AFF,
                                                                ) // 토요일: 파란색
                                                              : const Color(
                                                                  0xFF1C1C1E,
                                                                ), // 평일: 검정색
                                                          fontSize: 14,
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
                                                      style:
                                                          ResponsiveUtils.getTextStyle(
                                                            context,
                                                            fontSize: 8,
                                                            color: const Color(
                                                              0xFFFF3B30,
                                                            ),
                                                            fontWeight:
                                                                FontWeight.w400,
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
                                _legendDot(const Color(0xFF34C759), '연차'),
                                SizedBox(
                                  width: ResponsiveUtils.spacing(context, 20),
                                ),
                                _legendDot(const Color(0xFF1976D2), '출장'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                      // 상세내역 (항상 표시 - 오늘 날짜가 기본값)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: ResponsiveUtils.spacing(context, 3),
                              offset: Offset(
                                0,
                                ResponsiveUtils.spacing(context, 1),
                              ),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(
                          ResponsiveUtils.spacing(context, 20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDay != null
                                      ? '${_selectedDay!.year}년 ${_selectedDay!.month}월 ${_selectedDay!.day}일'
                                      : '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일',
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: const Color(0xFF1C1C1E),
                                  ),
                                ),
                                // 공휴일 표시
                                if (_selectedDay != null &&
                                    provider.isHoliday(_selectedDay!))
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: ResponsiveUtils.spacing(
                                        context,
                                        8,
                                      ),
                                      vertical: ResponsiveUtils.spacing(
                                        context,
                                        3,
                                      ),
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE5E5),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveUtils.spacing(context, 6),
                                      ),
                                    ),
                                    child: Text(
                                      provider.getHolidayInfo(
                                        _selectedDay!,
                                      )!['name'],
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFFF3B30),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(
                              height: ResponsiveUtils.spacing(context, 16),
                            ),
                            ..._getEventsForDay(
                              _selectedDay ?? DateTime.now(),
                              allLeaves,
                            ).map((e) => _eventTile(e)),
                            if (_getEventsForDay(
                              _selectedDay ?? DateTime.now(),
                              allLeaves,
                            ).isEmpty)
                              Center(
                                child: Text(
                                  (_selectedDay != null &&
                                          provider.isHoliday(_selectedDay!))
                                      ? '공휴일입니다.'
                                      : '해당 날짜에 등록된 연차/출장이 없습니다.',
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    color: const Color(0xFF8E8E93),
                                    fontSize: 14,
                                  ),
                                ),
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
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 12,
            color: const Color(0xFF6C757D),
          ),
        ),
      ],
    );
  }

  Widget _eventTile(Map<String, dynamic> e) {
    final rawType = e['type']?.toString() ?? '';
    final normalizedType = _normalizeLeaveType(rawType);
    final isBiztrip =
        normalizedType == 'biztrip' || normalizedType == 'businesstrip';
    Color chipColor;
    String chipLabel;
    Color chipTextColor = Colors.black87;
    // 상태별 색상/라벨
    switch (e['status']) {
      case 'approved':
        chipColor = const Color(0xFFE8F5E8);
        chipTextColor = const Color(0xFF34C759);
        break;
      case 'pending':
        chipColor = const Color(0xFFF2F2F7);
        chipTextColor = const Color(0xFF8E8E93);
        break;
      case 'rejected':
        chipColor = const Color(0xFFFFE5E5);
        chipTextColor = const Color(0xFFFF3B30);
        break;
      default:
        chipColor = const Color(0xFFE8F5E8);
        chipTextColor = const Color(0xFF34C759);
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
          chipColor = const Color(0xFFE3F2FD);
          chipTextColor = const Color(0xFF1976D2);
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
        vertical: ResponsiveUtils.spacing(context, 12),
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF2F2F7), width: 1)),
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
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 8),
                  vertical: ResponsiveUtils.spacing(context, 3),
                ),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 6),
                  ),
                ),
                child: Text(
                  chipLabel,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontWeight: FontWeight.w500,
                    color: chipTextColor,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (e['desc'] != null) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 4)),
            Text(
              e['desc'],
              style: ResponsiveUtils.getTextStyle(
                context,
                color: const Color(0xFF6C757D),
                fontSize: 13,
              ),
            ),
          ],
          // 출장인 경우: 장소, 업무, 차량 정보를 각 행에 표시
          if (isBiztrip) ...[
            if (e['place'] != null && e['place'].toString().isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.spacing(context, 2)),
              Text(
                '장소 : ${e['place']}',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  color: const Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
            ],
            if (displayReason != null && displayReason.isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.spacing(context, 2)),
              Text(
                '업무 : $displayReason',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  color: const Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
            ],
            if (e['transport'] != null && e['transport'].toString().isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.spacing(context, 2)),
              Text(
                '차량 : ${e['transport']}',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  color: const Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
            ],
          ],
          // 연차/반차인 경우: reason만 표시
          if (displayReason != null && !isBiztrip) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 2)),
            Text(
              displayReason,
              style: ResponsiveUtils.getTextStyle(
                context,
                color: const Color(0xFF8E8E93),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
