import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<LeaveProvider>(context, listen: false).fetchAllLeaves());
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    return List.generate(last.day, (i) => DateTime(month.year, month.month, i + 1));
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day, List<Map<String, dynamic>> allLeaves) {
    return allLeaves.where((l) {
      final start = DateTime.parse(l['start_date']);
      final end = DateTime.parse(l['end_date']);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList();
  }

  bool _hasAnnual(List<Map<String, dynamic>> events) {
    return events.any((e) => [
      'annual', 'halfAm', 'half_am', 'halfPm', 'half_pm'
    ].contains(e['type']));
  }

  bool _hasBiztrip(List<Map<String, dynamic>> events) {
    return events.any((e) => e['type'] == 'biztrip');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveProvider>(
      builder: (context, provider, _) {
        final allLeaves = provider.allLeaves;
        final days = _daysInMonth(_focusedMonth);
        final firstWeekday = days.first.weekday % 7; // 일요일=0
        final totalCells = days.length + firstWeekday;
        final rows = (totalCells / 7).ceil();
        final today = DateTime.now();
        return Scaffold(
          appBar: AppBar(
            title: const Text('달력', style: AppTextStyles.appBarTitle),
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
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 달력
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 28, color: Color(0xFF1C1C1E)),
                          onPressed: () {
                            setState(() {
                              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '📅  ${_focusedMonth.year}년 ${_focusedMonth.month}월',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22, color: Color(0xFF1C1C1E)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 28, color: Color(0xFF1C1C1E)),
                          onPressed: () {
                            setState(() {
                              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Expanded(child: Center(child: Text('일', style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w500)))),
                        Expanded(child: Center(child: Text('월', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.w500)))),
                        Expanded(child: Center(child: Text('화', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.w500)))),
                        Expanded(child: Center(child: Text('수', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.w500)))),
                        Expanded(child: Center(child: Text('목', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.w500)))),
                        Expanded(child: Center(child: Text('금', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.w500)))),
                        Expanded(child: Center(child: Text('토', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w500)))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Column(
                      children: List.generate(rows, (rowIdx) {
                        return Row(
                          children: List.generate(7, (colIdx) {
                            final cellIdx = rowIdx * 7 + colIdx;
                            if (cellIdx < firstWeekday || cellIdx - firstWeekday >= days.length) {
                              return Expanded(child: Container(height: 54));
                            }
                            final day = days[cellIdx - firstWeekday];
                            final events = _getEventsForDay(day, allLeaves);
                            final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                            final isSelected = _selectedDay != null && day.year == _selectedDay!.year && day.month == _selectedDay!.month && day.day == _selectedDay!.day;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDay = day;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  height: 54,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 막대기(연차/출장) - 숫자 위에
                                      if (_hasAnnual(events))
                                        Container(
                                          width: 18,
                                          height: 4,
                                          margin: const EdgeInsets.only(bottom: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF34C759).withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      if (_hasBiztrip(events))
                                        Container(
                                          width: 18,
                                          height: 4,
                                          margin: const EdgeInsets.only(bottom: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF9500).withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      // 날짜 숫자 (배경 없음)
                                      Text(
                                        '${day.day}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1C1C1E),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // 하단 점 인디케이터
                                      const SizedBox(height: 4),
                                      if (isSelected)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF1E90FF),
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      else if (isToday)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFF3B30),
                                            shape: BoxShape.circle,
                                          ),
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot(const Color(0xFF34C759), '연차'),
                        const SizedBox(width: 20),
                        _legendDot(const Color(0xFFFF9500), '출장'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 상세내역
              if (_selectedDay != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedDay!.year}년 ${_selectedDay!.month}월 ${_selectedDay!.day}일',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF1C1C1E)),
                      ),
                      const SizedBox(height: 16),
                      ..._getEventsForDay(_selectedDay!, allLeaves).map((e) => _eventTile(e)),
                      if (_getEventsForDay(_selectedDay!, allLeaves).isEmpty)
                        const Center(
                          child: Text(
                            '해당 날짜에 등록된 연차/출장이 없습니다.',
                            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
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
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6C757D),
          ),
        ),
      ],
    );
  }

  Widget _eventTile(Map<String, dynamic> e) {
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
    switch (e['type']) {
      case 'annual':
        chipLabel = '연차';
        break;
      case 'halfAm':
      case 'half_am':
        chipLabel = '오전반차';
        break;
      case 'halfPm':
      case 'half_pm':
        chipLabel = '오후반차';
        break;
      case 'biztrip':
        chipLabel = '출장';
        break;
      default:
        chipLabel = e['type'];
    }
    // 상태 라벨 추가
    if (e['status'] == 'pending') chipLabel += ' (대기)';
    if (e['status'] == 'rejected') chipLabel += ' (반려)';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF2F2F7),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                e['name'] ?? e['user_email'] ?? '-',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: chipTextColor,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (e['desc'] != null) ...[
            const SizedBox(height: 4),
            Text(
              e['desc'],
              style: const TextStyle(
                color: Color(0xFF6C757D),
                fontSize: 13,
              ),
            ),
          ],
          if (e['reason'] != null) ...[
            const SizedBox(height: 2),
            Text(
              e['reason'],
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}