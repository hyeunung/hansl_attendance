import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';

/// 출장 달력 위젯
/// 출장 날짜 선택을 위한 캘린더 컴포넌트
class TripCalendarWidget extends StatelessWidget {
  final Set<DateTime> selectedDates;
  final Function(DateTime) onDaySelected;
  final DateTime focusedDay;
  final Function(DateTime) onPageChanged;

  const TripCalendarWidget({
    super.key,
    required this.selectedDates,
    required this.onDaySelected,
    required this.focusedDay,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: TableCalendar(
        locale: 'ko_KR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2040, 12, 31),
        focusedDay: focusedDay,
        calendarFormat: CalendarFormat.month,
        availableGestures: AvailableGestures.horizontalSwipe, // 좌우 스와이프만 허용
        pageJumpingEnabled: true,
        sixWeekMonthsEnforced: false, // 6주 강제 표시 해제
        rowHeight: 48, // 행 높이 설정
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: ResponsiveUtils.getTextStyle(context, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: ResponsiveUtils.getTextStyle(
            context,
            color: Colors.black87,
            fontSize: 15,
          ),
          weekendTextStyle: ResponsiveUtils.getTextStyle(context, color: Colors.red.shade400, fontSize: 15),
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          todayTextStyle: ResponsiveUtils.getTextStyle(
            context,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 15,
          ),
          selectedTextStyle: ResponsiveUtils.getTextStyle(
            context,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: ResponsiveUtils.getTextStyle(
            context,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          weekendStyle: ResponsiveUtils.getTextStyle(
            context,
            color: Colors.red.shade400,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          decoration: const BoxDecoration(),
        ),
        daysOfWeekHeight: 40,
        onDaySelected: (selectedDay, focusedDay) {
          onDaySelected(selectedDay);
        },
        onPageChanged: onPageChanged,
        selectedDayPredicate: (day) {
          return selectedDates.any((date) => isSameDay(date, day));
        },
        calendarBuilders: CalendarBuilders(
          selectedBuilder: (context, day, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(4.0),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            );
          },
          dowBuilder: (context, day) {
            // 요일을 한글로 표시
            final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
            final text = weekdays[day.weekday % 7];

            return Center(
              child: Text(
                text,
                style: ResponsiveUtils.getTextStyle(
                  context,
                  color: day.weekday == DateTime.sunday
                      ? Colors.red
                      : day.weekday == DateTime.saturday
                      ? Colors.blue
                      : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
