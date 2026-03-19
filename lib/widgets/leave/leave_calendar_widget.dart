import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/leave_request.dart';
import '../../providers/leave_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';

/// 연차 신청 화면의 캘린더 위젯
/// 날짜 선택 및 표시를 담당하는 재사용 가능한 컴포넌트
class LeaveCalendarWidget extends StatelessWidget {
  final Map<LeaveType, Set<DateTime>> selectedDatesMap;
  final LeaveType? selectedType;
  final List<Map<String, dynamic>> myLeaves;
  final Function(DateTime) onDayTapped;

  const LeaveCalendarWidget({
    super.key,
    required this.selectedDatesMap,
    required this.selectedType,
    required this.myLeaves,
    required this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final Set<DateTime> disabledDates = _getDisabledDates();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 8),
          _buildCalendar(context, now, disabledDates),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    double usedDaysSum = 0;
    for (final type in LeaveType.values) {
      if (selectedDatesMap.containsKey(type)) {
        usedDaysSum += selectedDatesMap[type]!.length * type.days;
      }
    }

    return Row(
      children: [
        Text(
          '날짜',
          style: AppTextStyles.sectionSubtitle(context),
        ),
        Text(
          '  *',
          style: AppTextStyles.sectionSubtitle(context).copyWith(color: AppColors.error),
        ),
        const SizedBox(width: 12),
        Text(
          '선택된 일수: ${usedDaysSum % 1 == 0 ? usedDaysSum.toInt() : usedDaysSum}일',
          style: AppTextStyles.inputLabel(context).copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    DateTime now,
    Set<DateTime> disabledDates,
  ) {
    return TableCalendar(
      locale: 'ko_KR',
      firstDay: DateTime(now.year, 1, 1),
      lastDay: DateTime(now.year + 1, 12, 31),
      focusedDay: DateTime.now(),
      selectedDayPredicate: (day) => _isSelectedDay(day),
      onDaySelected: (selectedDay, _) => onDayTapped(selectedDay),
      calendarStyle: _getCalendarStyle(context),
      enabledDayPredicate: (day) => _isEnabledDay(context, day, disabledDates),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: AppTextStyles.tableHeader(context).copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: ResponsiveUtils.fontSize(context, 13),
        ),
        weekendStyle: AppTextStyles.tableHeader(context).copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: ResponsiveUtils.fontSize(context, 13),
        ),
      ),
      daysOfWeekHeight: 28,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextFormatter: (date, locale) {
          const months = [
            '1월', '2월', '3월', '4월', '5월', '6월',
            '7월', '8월', '9월', '10월', '11월', '12월',
          ];
          return '${date.year}년 ${months[date.month - 1]}';
        },
      ),
      calendarFormat: CalendarFormat.month,
      pageJumpingEnabled: false,
      availableGestures: AvailableGestures.none,
      calendarBuilders: _getCalendarBuilders(context),
    );
  }

  CalendarStyle _getCalendarStyle(BuildContext context) {
    return CalendarStyle(
      isTodayHighlighted: true,
      selectedDecoration: const BoxDecoration(),
      todayDecoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      disabledTextStyle: AppTextStyles.tableCellSub(context).copyWith(
        color: AppColors.textDisabled,
        fontSize: ResponsiveUtils.fontSize(context, 14),
      ),
      weekendTextStyle: AppTextStyles.tableCellSub(context).copyWith(
        color: AppColors.textPrimary,
        fontSize: ResponsiveUtils.fontSize(context, 14),
      ),
      defaultTextStyle: AppTextStyles.tableCellSub(context).copyWith(
        color: AppColors.textPrimary,
        fontSize: ResponsiveUtils.fontSize(context, 14),
      ),
    );
  }

  CalendarBuilders _getCalendarBuilders(BuildContext context) {
    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);

    return CalendarBuilders(
      defaultBuilder: (context, day, focusedDay) {
        final selectedWidget = _buildDayWidget(context, day);
        if (selectedWidget != null) return selectedWidget;

        if (leaveProvider.isHoliday(day)) {
          return Container(
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: AppTextStyles.tableCell(context, color: AppColors.holiday).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: ResponsiveUtils.fontSize(context, 15),
              ),
            ),
          );
        }

        if (day.weekday == DateTime.sunday) {
          return Container(
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: AppTextStyles.tableCell(context, color: AppColors.sunday).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: ResponsiveUtils.fontSize(context, 14),
              ),
            ),
          );
        }

        if (day.weekday == DateTime.saturday) {
          return Container(
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: AppTextStyles.tableCell(context, color: AppColors.saturday).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: ResponsiveUtils.fontSize(context, 14),
              ),
            ),
          );
        }

        return null;
      },
      selectedBuilder: (context, day, focusedDay) => _buildDayWidget(context, day),
      todayBuilder: (context, day, focusedDay) => _buildTodayWidget(context, day),
      disabledBuilder: (context, day, focusedDay) {
        if (leaveProvider.isHoliday(day)) {
          return Container(
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: AppTextStyles.listSubtitle(context).copyWith(
                color: AppColors.holiday.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        } else if (day.weekday == DateTime.sunday) {
          return Container(
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: AppTextStyles.listSubtitle(context).copyWith(
                color: AppColors.sunday.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
                fontSize: ResponsiveUtils.fontSize(context, 12),
              ),
            ),
          );
        } else if (day.weekday == DateTime.saturday) {
          return Container(
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: AppTextStyles.listSubtitle(context).copyWith(
                color: AppColors.saturday.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
                fontSize: ResponsiveUtils.fontSize(context, 12),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(4),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: AppTextStyles.listSubtitle(context).copyWith(
              color: AppColors.textDisabled,
              fontWeight: FontWeight.w400,
              fontSize: ResponsiveUtils.fontSize(context, 12),
            ),
          ),
        );
      },
      dowBuilder: (context, day) {
        final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
        final text = weekdays[day.weekday % 7];

        return Center(
          child: Text(
            text,
            style: AppTextStyles.tableHeader(context).copyWith(
              color: day.weekday == DateTime.sunday
                  ? AppColors.sunday
                  : day.weekday == DateTime.saturday
                  ? AppColors.saturday
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: ResponsiveUtils.fontSize(context, 13),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildDayWidget(BuildContext context, DateTime day) {
    LeaveType? type = _getLeaveTypeForDay(day);
    return type != null ? _buildDayMarker(context, day, type) : null;
  }

  Widget _buildTodayWidget(BuildContext context, DateTime day) {
    LeaveType? type = _getLeaveTypeForDay(day);
    if (type != null) {
      return _buildDayMarker(context, day, type);
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
        style: AppTextStyles.tableCell(context, color: AppColors.primary).copyWith(
          fontWeight: FontWeight.bold,
          fontSize: ResponsiveUtils.fontSize(context, 14),
        ),
      ),
    );
  }

  Widget _buildDayMarker(BuildContext context, DateTime day, LeaveType type) {
    if (type == LeaveType.annual || type == LeaveType.official) {
      return _buildCircleMarker(context, day, type);
    } else if (type == LeaveType.halfAm) {
      return _buildHalfCircleMarker(context, day, type, true);
    } else if (type == LeaveType.halfPm) {
      return _buildHalfCircleMarker(context, day, type, false);
    }
    return const SizedBox.shrink();
  }

  Widget _buildCircleMarker(BuildContext context, DateTime day, LeaveType type) {
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
            style: AppTextStyles.tableCell(context).copyWith(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveUtils.fontSize(context, 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHalfCircleMarker(BuildContext context, DateTime day, LeaveType type, bool isTop) {
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
              style: AppTextStyles.tableCell(context).copyWith(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.fontSize(context, 14),
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
        return const Color(0xFFB3D8FF);
      case LeaveType.halfAm:
        return const Color(0xFFFFE0B2);
      case LeaveType.halfPm:
        return const Color(0xFFC8E6C9);
      case LeaveType.official:
        return AppColors.gray200;
      default:
        return AppColors.textPrimary;
    }
  }

  Set<String> _getLeaveTypesForDate(DateTime day) {
    final types = <String>{};
    for (final leave in myLeaves) {
      if (leave['status'] == 'rejected') continue;
      final start = DateTime.parse(leave['start_date']);
      final end = DateTime.parse(leave['end_date']);
      final dates = List.generate(
        end.difference(start).inDays + 1,
        (i) => DateTime(start.year, start.month, start.day + i),
      );
      if (dates.any((d) => isSameDay(d, day))) {
        types.add(leave['type'] ?? '');
      }
    }
    return types;
  }

  bool _canSelectDateForType(DateTime day) {
    final existingTypes = _getLeaveTypesForDate(day);
    if (existingTypes.isEmpty) return true;
    if (existingTypes.contains('annual') || existingTypes.contains('official')) {
      return false;
    }
    switch (selectedType) {
      case LeaveType.annual:
      case LeaveType.official:
        return existingTypes.isEmpty;
      case LeaveType.halfAm:
        return !existingTypes.contains('half_am') && !existingTypes.contains('halfAm');
      case LeaveType.halfPm:
        return !existingTypes.contains('half_pm') && !existingTypes.contains('halfPm');
      default:
        return existingTypes.isEmpty;
    }
  }

  Set<DateTime> _getDisabledDates() {
    return myLeaves
        .where((l) => l['status'] != 'rejected')
        .where((l) => l['type'] == 'annual' || l['type'] == 'official')
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

  bool _isEnabledDay(
    BuildContext context,
    DateTime day,
    Set<DateTime> disabledDates,
  ) {
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return false;
    }
    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
    if (leaveProvider.isHoliday(day)) {
      return false;
    }
    if (disabledDates.any((d) => isSameDay(d, day))) return false;
    if (!_canSelectDateForType(day)) return false;
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
