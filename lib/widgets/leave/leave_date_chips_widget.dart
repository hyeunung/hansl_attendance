import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_request.dart';

/// 선택된 날짜를 칩 형태로 표시하는 위젯
/// 날짜별로 다른 색상과 삭제 기능을 제공
class LeaveDateChipsWidget extends StatelessWidget {
  final Map<LeaveType, Set<DateTime>> selectedDatesMap;
  final Function(LeaveType, DateTime)? onDateRemoved;

  const LeaveDateChipsWidget({
    super.key,
    required this.selectedDatesMap,
    this.onDateRemoved,
  });

  @override
  Widget build(BuildContext context) {
    // 날짜가 없으면 빈 위젯 반환
    if (!_hasSelectedDates()) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(spacing: 8, runSpacing: 8, children: _buildDateChips()),
    );
  }

  bool _hasSelectedDates() {
    return selectedDatesMap.values.any((dates) => dates.isNotEmpty);
  }

  List<Widget> _buildDateChips() {
    List<Widget> chips = [];

    selectedDatesMap.forEach((type, dates) {
      final sortedDates = dates.toList()..sort((a, b) => a.compareTo(b));

      for (final date in sortedDates) {
        chips.add(_buildSingleChip(date, type));
      }
    });

    return chips;
  }

  Widget _buildSingleChip(DateTime date, LeaveType type) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: _getTypeColor(type),
              shape: BoxShape.circle,
            ),
          ),
          Text(
            DateFormat('yyyy.MM.dd').format(date),
            style: TextStyle(
              color: _getTypeColor(type),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if (type.days > 0 && type.days < 1)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _getTypeColor(type).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                type == LeaveType.halfAm ? '오전' : '오후',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _getTypeColor(type),
                ),
              ),
            ),
        ],
      ),
      backgroundColor: _getTypeColor(type).withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _getTypeColor(type).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      deleteIcon: Icon(Icons.close, size: 18, color: _getTypeColor(type)),
      onDeleted: onDateRemoved != null
          ? () => onDateRemoved!(type, date)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Color _getTypeColor(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return const Color(0xFF4A90E2); // 파랑
      case LeaveType.halfAm:
        return const Color(0xFFF5A623); // 주황
      case LeaveType.halfPm:
        return const Color(0xFF7ED321); // 초록
      case LeaveType.official:
        return const Color(0xFF9B9B9B); // 회색
      default:
        return Colors.grey;
    }
  }
}
