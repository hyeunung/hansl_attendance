import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/leave_request.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';

/// 연차 신청 화면의 캘린더 위젯
/// 날짜 선택 및 표시를 담당하는 재사용 가능한 컴포넌트
class LeaveCalendarWidget extends StatelessWidget {
  final Map<LeaveType, Set<DateTime>> selectedDatesMap;
  final LeaveType selectedType;
  final List<Map<String, dynamic>> myLeaves;
  final Function(DateTime) onDayTapped;

  const LeaveCalendarWidget({
    Key? key,
    required this.selectedDatesMap,
    required this.selectedType,
    required this.myLeaves,
    required this.onDayTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // 이미 신청된 날짜들을 계산
    final Set<DateTime> disabledDates = _getDisabledDates();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppShadows.card],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildCalendar(now, disabledDates),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // 사용연차 계산
    double usedDaysSum = 0;
    for (final type in LeaveType.values) {
      if (selectedDatesMap.containsKey(type)) {
        usedDaysSum += selectedDatesMap[type]!.length * type.days;
      }
    }

    return Row(
      children: [
        const Text(
          '날짜',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
        const SizedBox(width: 12),
        Text(
          '선택된 일수: ${usedDaysSum % 1 == 0 ? usedDaysSum.toInt() : usedDaysSum}일',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(DateTime now, Set<DateTime> disabledDates) {
    return TableCalendar(
      firstDay: DateTime(now.year, 1, 1),
      lastDay: DateTime(now.year + 1, 12, 31),
      focusedDay: DateTime.now(),
      selectedDayPredicate: (day) => _isSelectedDay(day),
      onDaySelected: (selectedDay, _) => onDayTapped(selectedDay),
      calendarStyle: _getCalendarStyle(),
      enabledDayPredicate: (day) => _isEnabledDay(day, disabledDates),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarFormat: CalendarFormat.month,
      pageJumpingEnabled: false,
      availableGestures: AvailableGestures.none,
      calendarBuilders: _getCalendarBuilders(),
    );
  }

  CalendarStyle _getCalendarStyle() {
    return CalendarStyle(
      isTodayHighlighted: true,
      selectedDecoration: const BoxDecoration(),
      todayDecoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      disabledTextStyle: TextStyle(color: Colors.grey.shade400),
    );
  }

  CalendarBuilders _getCalendarBuilders() {
    return CalendarBuilders(
      defaultBuilder: (context, day, focusedDay) => _buildDayWidget(day),
      selectedBuilder: (context, day, focusedDay) => _buildDayWidget(day),
      todayBuilder: (context, day, focusedDay) => _buildTodayWidget(day),
    );
  }

  Widget? _buildDayWidget(DateTime day) {
    LeaveType? type = _getLeaveTypeForDay(day);
    return type != null ? _buildDayMarker(day, type) : null;
  }

  Widget _buildTodayWidget(DateTime day) {
    LeaveType? type = _getLeaveTypeForDay(day);
    if (type != null) {
      return _buildDayMarker(day, type);
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDayMarker(DateTime day, LeaveType type) {
    if (type == LeaveType.annual || type == LeaveType.official) {
      return _buildCircleMarker(day, type);
    } else if (type == LeaveType.halfAm) {
      return _buildHalfCircleMarker(day, type, true);
    } else if (type == LeaveType.halfPm) {
      return _buildHalfCircleMarker(day, type, false);
    }
    return const SizedBox.shrink();
  }

  Widget _buildCircleMarker(DateTime day, LeaveType type) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _getTypeColor(type),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHalfCircleMarker(DateTime day, LeaveType type, bool isTop) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: CustomPaint(
          size: const Size(36, 36),
          painter: HalfCirclePainter(_getTypeColor(type), isTop),
          child: Center(
            child: Text(
              '${day.day}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return const Color(0xFFB3D8FF); // 연파랑
      case LeaveType.halfAm:
        return const Color(0xFFFFE0B2); // 연주황
      case LeaveType.halfPm:
        return const Color(0xFFC8E6C9); // 연초록
      case LeaveType.official:
        return const Color(0xFFE0E0E0); // 연회색
      default:
        return Colors.black;
    }
  }

  Set<DateTime> _getDisabledDates() {
    // pending이나 approved 상태인 연차만 비활성화 (rejected는 다시 신청 가능)
    return myLeaves
        .where((l) => l['status'] != 'rejected') // 반려된 연차는 제외
        .map((l) {
          final start = DateTime.parse(l['start_date']);
          final end = DateTime.parse(l['end_date']);
          return List.generate(
            end.difference(start).inDays + 1,
            (i) => DateTime(start.year, start.month, start.day + i),
          );
        })
        .expand((x) => x)
        .toSet();
  }

  bool _isSelectedDay(DateTime day) {
    for (final type in LeaveType.values) {
      if (selectedDatesMap.containsKey(type) &&
          selectedDatesMap[type]!.any((d) => isSameDay(d, day))) {
        return true;
      }
    }
    return false;
  }

  bool _isEnabledDay(DateTime day, Set<DateTime> disabledDates) {
    // 이미 신청된 날짜는 비활성화
    if (disabledDates.any((d) => isSameDay(d, day))) return false;

    // 다른 휴가 유형으로 이미 선택된 날짜는 비활성화
    for (final type in LeaveType.values) {
      if (type != selectedType &&
          selectedDatesMap.containsKey(type) &&
          selectedDatesMap[type]!.any((d) => isSameDay(d, day))) {
        return false;
      }
    }
    return true;
  }

  LeaveType? _getLeaveTypeForDay(DateTime day) {
    for (final type in LeaveType.values) {
      if (selectedDatesMap.containsKey(type) &&
          selectedDatesMap[type]!.any((d) => isSameDay(d, day))) {
        return type;
      }
    }
    return null;
  }
}

/// 반달 모양을 그리는 CustomPainter
class HalfCirclePainter extends CustomPainter {
  final Color color;
  final bool isTop;

  HalfCirclePainter(this.color, this.isTop);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path();

    if (isTop) {
      path.moveTo(center.dx - radius, center.dy);
      path.arcTo(rect, -3.14, 3.14, false);
      path.close();
    } else {
      path.moveTo(center.dx - radius, center.dy);
      path.arcTo(rect, 0, 3.14, false);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
