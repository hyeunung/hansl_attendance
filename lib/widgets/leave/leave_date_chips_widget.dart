import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_request.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';

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
    if (!_hasSelectedDates()) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(spacing: 8, runSpacing: 8, children: _buildDateChips(context)),
    );
  }

  bool _hasSelectedDates() {
    return selectedDatesMap.values.any((dates) => dates.isNotEmpty);
  }

  List<Widget> _buildDateChips(BuildContext context) {
    List<Widget> chips = [];

    selectedDatesMap.forEach((type, dates) {
      final sortedDates = dates.toList()..sort((a, b) => a.compareTo(b));

      for (final date in sortedDates) {
        chips.add(_buildSingleChip(context, date, type));
      }
    });

    return chips;
  }

  Widget _buildSingleChip(BuildContext context, DateTime date, LeaveType type) {
    final typeColor = _getTypeColor(type);

    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: typeColor,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            DateFormat('yyyy.MM.dd').format(date),
            style: AppTextStyles.chipLabel(context, color: typeColor).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (type.days > 0 && type.days < 1)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                type == LeaveType.halfAm ? '오전' : '오후',
                style: AppTextStyles.statLabel(context).copyWith(
                  fontSize: ResponsiveUtils.fontSize(context, 11),
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ),
        ],
      ),
      backgroundColor: typeColor.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: typeColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      deleteIcon: Icon(Icons.close, size: 18, color: typeColor),
      onDeleted: onDateRemoved != null
          ? () => onDateRemoved!(type, date)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Color _getTypeColor(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return AppColors.info;
      case LeaveType.halfAm:
        return AppColors.warning;
      case LeaveType.halfPm:
        return AppColors.success;
      case LeaveType.official:
        return AppColors.textTertiary;
      default:
        return AppColors.gray400;
    }
  }
}
